// Citizen profile deletion on Cloudflare Workers.
//
// The Firebase project is on the Spark plan, so the equivalent Cloud Functions
// callable cannot be deployed. This module performs the same trusted lifecycle
// through Google's REST APIs with the worker's Firebase service account:
//
// 1. Confirming deletion deactivates the account for 30 days. Nothing is
//    removed yet, the citizen can still sign in, and the profile carries the
//    schedule so the app can show its deactivation dialog.
// 2. Signing in during that window offers to restore the account, which the
//    /cancel-citizen-deletion endpoint performs.
// 3. When the deadline passes (hourly cron) or the citizen asks for it, the
//    cleanup runs: disable + revoke, anonymize public contributions, remove the
//    Firestore profile tree, delete the Firebase Auth user, then email the
//    confirmation.
//
// D1 keeps the schedule durable so an interrupted purge resumes on the hourly
// cron.

const HOUR_MS = 60 * 60 * 1000;
// A citizen account stays deactivated for the full 30 days. The hourly cron
// performs the final purge once the deadline passes.
const RETENTION_MS = 30 * 24 * HOUR_MS;
const VERIFICATION_WINDOW_MS = 5 * 60 * 1000;
const VERIFIED_PROVIDERS = new Set([
  "password",
  "phone",
  "google.com",
  "facebook.com",
]);
const AUTH_BASE = "https://identitytoolkit.googleapis.com/v1";
const FIRESTORE_BASE = "https://firestore.googleapis.com/v1";
const MAX_TREE_DEPTH = 6;
const PAGE_SIZE = 200;
const ANONYMIZED_AUTHOR = "Deleted citizen";
const ANONYMIZED_FIELDS = [
  "authorId",
  "author",
  "authorName",
  "authorEmail",
  "authorPhone",
  "authorPhotoUrl",
  "authorPhotoURL",
];

function documentPathFromName(name) {
  const marker = "/documents/";
  const index = String(name || "").indexOf(marker);
  return index === -1 ? "" : String(name).slice(index + marker.length);
}

// The ID token is validated by Identity Toolkit before this is read, so its
// payload carries authentic auth_time, sign-in provider and custom claims.
function decodeTokenPayload(idToken) {
  const part = String(idToken || "").split(".")[1];
  if (!part) return null;
  const base64 = part.replaceAll("-", "+").replaceAll("_", "/");
  const padded = base64 + "=".repeat((4 - (base64.length % 4)) % 4);
  try {
    const binary = atob(padded);
    const bytes = new Uint8Array(binary.length);
    for (let index = 0; index < binary.length; index += 1) {
      bytes[index] = binary.charCodeAt(index);
    }
    return JSON.parse(new TextDecoder().decode(bytes));
  } catch {
    return null;
  }
}

export function createD1Jobs(db) {
  // The table is created on first use: the worker may be deployed to a D1
  // database whose schema was applied before deletion existed, and a missing
  // table would otherwise fail the whole request with an empty 500.
  let schemaReady = false;

  async function ensureSchema() {
    if (schemaReady) return;
    const statements = [
      db.prepare(
        `CREATE TABLE IF NOT EXISTS citizen_deletions (
          uid TEXT PRIMARY KEY,
          email TEXT,
          status TEXT NOT NULL,
          email_status TEXT NOT NULL,
          requested_at INTEGER NOT NULL,
          purge_deadline INTEGER NOT NULL,
          deleted_at INTEGER,
          next_attempt_at INTEGER,
          lease_until INTEGER
        )`,
      ),
      db.prepare(
        `CREATE INDEX IF NOT EXISTS idx_citizen_deletions_due
         ON citizen_deletions(next_attempt_at)`,
      ),
    ];
    if (typeof db.batch === "function") {
      await db.batch(statements);
    } else {
      for (const statement of statements) await statement.run();
    }
    schemaReady = true;
  }

  return {
    async get(uid) {
      await ensureSchema();
      return db
        .prepare("SELECT * FROM citizen_deletions WHERE uid = ?")
        .bind(uid)
        .first();
    },

    async insert(row) {
      await ensureSchema();
      await db
        .prepare(
          `INSERT INTO citizen_deletions (
            uid, email, status, email_status, requested_at,
            purge_deadline, next_attempt_at, lease_until
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(uid) DO NOTHING`,
        )
        .bind(
          row.uid,
          row.email,
          row.status,
          row.email_status,
          row.requested_at,
          row.purge_deadline,
          row.next_attempt_at,
          row.lease_until,
        )
        .run();
    },

    // Only one run may own a job at a time, and a finished job is never
    // claimed again.
    async claim(uid, leaseUntil, nextAttemptAt, at) {
      await ensureSchema();
      const result = await db
        .prepare(
          `UPDATE citizen_deletions
           SET lease_until = ?, next_attempt_at = ?
           WHERE uid = ?
             AND (lease_until IS NULL OR lease_until <= ?)
             AND status != 'cancelled'
             AND NOT (status = 'deleted' AND email_status != 'pending')`,
        )
        .bind(leaseUntil, nextAttemptAt, uid, at)
        .run();
      return Number(result?.meta?.changes || 0) > 0;
    },

    async update(uid, patch) {
      await ensureSchema();
      const columns = Object.keys(patch);
      if (!columns.length) return;
      const assignments = columns.map((column) => `${column} = ?`).join(", ");
      await db
        .prepare(`UPDATE citizen_deletions SET ${assignments} WHERE uid = ?`)
        .bind(...columns.map((column) => patch[column]), uid)
        .run();
    },

    async due(at, limit) {
      await ensureSchema();
      const result = await db
        .prepare(
          `SELECT uid FROM citizen_deletions
           WHERE next_attempt_at IS NOT NULL AND next_attempt_at <= ?
           ORDER BY next_attempt_at ASC
           LIMIT ?`,
        )
        .bind(at, limit)
        .all();
      return result?.results || [];
    },
  };
}

export function createCitizenDeletionHandlers({
  jobsFor,
  projectId,
  accessToken,
  sendConfirmation,
  deleteOtpChallenges,
  fetch: fetchImpl = (...args) => fetch(...args),
  now = Date.now,
  logger = console,
}) {
  function json(body, status = 200) {
    return new Response(JSON.stringify(body), {
      status,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "Content-Type, Authorization",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
      },
    });
  }

  function documentsUrl(env, path, suffix = "") {
    return `${FIRESTORE_BASE}/projects/${projectId(env)}/databases/(default)/documents/${path}${suffix}`;
  }

  function authHeader(token) {
    return { Authorization: `Bearer ${token}` };
  }

  async function readJson(response) {
    return response.json().catch(() => null);
  }

  async function firestoreGet(env, token, path) {
    const response = await fetchImpl(documentsUrl(env, path), {
      headers: authHeader(token),
    });
    if (!response.ok) return null;
    return readJson(response);
  }

  // Distinguishes "document is absent" (404) from "the read failed", so a
  // transient Firestore error can never be mistaken for a citizen account.
  async function firestoreProbe(env, token, path) {
    const response = await fetchImpl(documentsUrl(env, path), {
      headers: authHeader(token),
    });
    if (response.status === 404) return { exists: false, document: null };
    if (!response.ok) return { exists: null, document: null };
    return { exists: true, document: await readJson(response) };
  }

  async function firestoreRunQuery(env, token, body) {
    const response = await fetchImpl(documentsUrl(env, "", ":runQuery"), {
      method: "POST",
      headers: { ...authHeader(token), "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    if (!response.ok) {
      throw new Error(`firestore-query-${response.status}`);
    }
    const rows = await readJson(response);
    return Array.isArray(rows) ? rows : [];
  }

  async function firestoreCommit(env, token, writes) {
    const response = await fetchImpl(documentsUrl(env, "", ":commit"), {
      method: "POST",
      headers: { ...authHeader(token), "Content-Type": "application/json" },
      body: JSON.stringify({ writes }),
    });
    if (!response.ok) {
      throw new Error(`firestore-commit-${response.status}`);
    }
  }

  async function listCollectionIds(env, token, path) {
    const ids = [];
    let pageToken = "";
    do {
      const response = await fetchImpl(
        documentsUrl(env, path, ":listCollectionIds"),
        {
          method: "POST",
          headers: { ...authHeader(token), "Content-Type": "application/json" },
          body: JSON.stringify({ pageSize: PAGE_SIZE, pageToken }),
        },
      );
      if (!response.ok) {
        // A missing document has no subcollections to clean up.
        if (response.status === 404) return ids;
        throw new Error(`firestore-list-collections-${response.status}`);
      }
      const page = await readJson(response);
      for (const id of page?.collectionIds || []) ids.push(String(id));
      pageToken = page?.nextPageToken || "";
    } while (pageToken);
    return ids;
  }

  async function listDocuments(env, token, path) {
    const response = await fetchImpl(
      documentsUrl(env, path, `?pageSize=${PAGE_SIZE}`),
      { headers: authHeader(token) },
    );
    if (!response.ok) {
      if (response.status === 404) return [];
      throw new Error(`firestore-list-documents-${response.status}`);
    }
    const page = await readJson(response);
    return Array.isArray(page?.documents) ? page.documents : [];
  }

  async function deleteDocument(env, token, path) {
    const response = await fetchImpl(documentsUrl(env, path), {
      method: "DELETE",
      headers: authHeader(token),
    });
    if (!response.ok && response.status !== 404) {
      throw new Error(`firestore-delete-${response.status}`);
    }
  }

  // Firestore has no recursive delete in REST, so the profile tree is walked
  // depth first. Re-listing after each pass avoids stale page tokens.
  async function deleteDocumentTree(env, token, path, depth = 0) {
    if (depth > MAX_TREE_DEPTH || !path) return;
    for (const collectionId of await listCollectionIds(env, token, path)) {
      const collectionPath = `${path}/${collectionId}`;
      for (;;) {
        const documents = await listDocuments(env, token, collectionPath);
        if (!documents.length) break;
        for (const document of documents) {
          await deleteDocumentTree(
            env,
            token,
            documentPathFromName(document.name),
            depth + 1,
          );
        }
      }
    }
    await deleteDocument(env, token, path);
  }

  // PATCH (rather than a commit update) also creates the profile when the
  // account has none, so the app can always read the deletion state.
  async function patchProfile(env, token, uid, fields, fieldPaths) {
    const mask = fieldPaths
      .map((path) => `updateMask.fieldPaths=${encodeURIComponent(path)}`)
      .join("&");
    const response = await fetchImpl(
      documentsUrl(env, `users/${uid}`, `?${mask}`),
      {
        method: "PATCH",
        headers: { ...authHeader(token), "Content-Type": "application/json" },
        body: JSON.stringify({ fields }),
      },
    );
    if (!response.ok) throw new Error(`firestore-patch-${response.status}`);
  }

  // The profile carries the schedule so a signed-in citizen sees the dialog
  // without calling the worker.
  async function markProfileDeactivated(env, token, uid, requestedAt, deleteAt) {
    await patchProfile(
      env,
      token,
      uid,
      {
        deletionStatus: { stringValue: "deactivated" },
        deletionRequestedAt: { integerValue: String(requestedAt) },
        deletionScheduledFor: { integerValue: String(deleteAt) },
      },
      ["deletionStatus", "deletionRequestedAt", "deletionScheduledFor"],
    );
  }

  async function markProfileActive(env, token, uid) {
    await patchProfile(
      env,
      token,
      uid,
      { deletionStatus: { stringValue: "active" } },
      ["deletionStatus"],
    );
  }

  async function anonymizeContributions(env, token, uid, deadline) {
    const fields = {
      authorId: { nullValue: null },
      author: {
        mapValue: { fields: { name: { stringValue: ANONYMIZED_AUTHOR } } },
      },
      authorName: { stringValue: ANONYMIZED_AUTHOR },
      authorEmail: { nullValue: null },
      authorPhone: { nullValue: null },
      authorPhotoUrl: { nullValue: null },
      authorPhotoURL: { nullValue: null },
    };

    for (const collectionId of ["reports", "comments"]) {
      while (now() < deadline) {
        const rows = await firestoreRunQuery(env, token, {
          structuredQuery: {
            from: [{ collectionId, allDescendants: true }],
            where: {
              fieldFilter: {
                field: { fieldPath: "authorId" },
                op: "EQUAL",
                value: { stringValue: uid },
              },
            },
            limit: PAGE_SIZE,
          },
        });
        const documents = rows
          .map((row) => row?.document)
          .filter((document) => document?.name);
        if (!documents.length) break;
        await firestoreCommit(
          env,
          token,
          documents.map((document) => ({
            update: { name: document.name, fields },
            updateMask: { fieldPaths: ANONYMIZED_FIELDS },
          })),
        );
      }
      if (now() >= deadline) return false;
    }
    return true;
  }

  async function updateAccount(env, token, body) {
    const response = await fetchImpl(
      `${AUTH_BASE}/projects/${projectId(env)}/accounts:update`,
      {
        method: "POST",
        headers: { ...authHeader(token), "Content-Type": "application/json" },
        body: JSON.stringify(body),
      },
    );
    if (response.ok) return { ok: true };
    const detail = await response.text().catch(() => "");
    if (detail.includes("USER_NOT_FOUND")) return { ok: true, missing: true };
    return { ok: false, detail };
  }

  async function deleteAuthUser(env, token, uid) {
    const response = await fetchImpl(
      `${AUTH_BASE}/projects/${projectId(env)}/accounts:delete`,
      {
        method: "POST",
        headers: { ...authHeader(token), "Content-Type": "application/json" },
        body: JSON.stringify({ localId: uid }),
      },
    );
    if (response.ok) return;
    const detail = await response.text().catch(() => "");
    if (detail.includes("USER_NOT_FOUND")) return;
    throw new Error("auth-delete-failed");
  }

  // [fresh] is true for deletion, which needs a reauthentication from the last
  // five minutes, and false for cancelling, which only needs a session.
  async function verifyCaller(request, env, token, { fresh = true } = {}) {
    const header = request.headers.get("Authorization") || "";
    const match = /^Bearer\s+(.+)$/i.exec(header.trim());
    const idToken = match ? match[1].trim() : "";
    if (!idToken) {
      return { error: json({ error: "Sign in to delete your profile." }, 401) };
    }

    const lookup = await fetchImpl(
      `${AUTH_BASE}/projects/${projectId(env)}/accounts:lookup`,
      {
        method: "POST",
        headers: { ...authHeader(token), "Content-Type": "application/json" },
        body: JSON.stringify({ idToken }),
      },
    );
    if (!lookup.ok) {
      return {
        error: json({ error: "Your session has expired. Sign in again." }, 401),
      };
    }

    const payload = await readJson(lookup);
    const user = Array.isArray(payload?.users) ? payload.users[0] : null;
    const uid = String(user?.localId || "").trim();
    if (!uid) {
      return { error: json({ error: "Sign in to delete your profile." }, 401) };
    }

    const claims = decodeTokenPayload(idToken) || {};
    const verifiedAt = Number(claims.auth_time) * 1000;
    const provider = claims?.firebase?.sign_in_provider;
    if (
      fresh &&
      (!Number.isFinite(verifiedAt) ||
        verifiedAt > now() + 30000 ||
        now() - verifiedAt > VERIFICATION_WINDOW_MS ||
        !VERIFIED_PROVIDERS.has(provider))
    ) {
      return {
        error: json({ error: "Verify your account again." }, 401),
      };
    }

    return { uid, claims };
  }

  async function release(env, uid, nextAttemptAt) {
    await jobsFor(env).update(uid, {
      lease_until: null,
      next_attempt_at: nextAttemptAt,
    });
  }

  // The one email the citizen gets when the account is deactivated. The address
  // is dropped from D1 as soon as it is delivered.
  async function deliverDeactivationEmail(env, jobs, job) {
    if (!job.email || job.email_status !== "pending") return job.email_status;
    try {
      await sendConfirmation(env, job.email, Number(job.purge_deadline));
      await jobs.update(job.uid, { email: null, email_status: "sent" });
      return "sent";
    } catch (error) {
      logger.error("Citizen deletion email will be retried.", {
        code: error?.message || "unknown",
      });
      return "pending";
    }
  }

  // The final purge. It runs once the 30-day deactivation window has passed, or
  // immediately when the citizen asks for it from the deactivation dialog.
  async function processDeletion(env, token, uid, { force = false } = {}) {
    const jobs = jobsFor(env);
    const job = await jobs.get(uid);
    if (!job) return null;
    if (job.status === "deleted" && job.email_status !== "pending") return job;
    if (job.status === "cancelled") return job;

    // Any row still inside its window is left alone, including rows written by
    // the previous release, which used a `pending` status.
    if (job.status !== "deleted" && Number(job.purge_deadline) > now()) {
      if (!force) {
        // Still inside the window: only the confirmation email may be due.
        await deliverDeactivationEmail(env, jobs, job);
        return await jobs.get(uid);
      }
      // The citizen chose to finish now; the window no longer applies.
      await jobs.update(uid, { purge_deadline: now() });
    }

    if (job.lease_until && Number(job.lease_until) > now()) return job;

    const claimed = await jobs.claim(
      uid,
      now() + 2 * 60 * 1000,
      now() + 2 * 60 * 1000,
      now(),
    );
    if (!claimed) return await jobs.get(uid);

    try {
      if (job.status !== "deleted") {
        // Disabling and revoking first means a stolen session cannot recreate
        // the profile while the rest of the cleanup runs.
        const disabled = await updateAccount(env, token, {
          localId: uid,
          disable: true,
          validSince: String(Math.floor(now() / 1000)),
        });
        if (!disabled.ok) throw new Error("auth-disable-failed");

        const finished = await anonymizeContributions(
          env,
          token,
          uid,
          now() + 35000,
        );
        if (!finished) {
          await release(env, uid, now() + HOUR_MS);
          return await jobs.get(uid);
        }

        await deleteDocumentTree(env, token, `users/${uid}`);
        if (job.email) await deleteOtpChallenges(env, job.email);
        await deleteAuthUser(env, token, uid);

        await jobs.update(uid, {
          status: "deleted",
          deleted_at: now(),
          email: null,
          email_status: "unavailable",
          lease_until: null,
          next_attempt_at: null,
        });
      } else {
        await jobs.update(uid, { lease_until: null, next_attempt_at: null });
      }
    } catch (error) {
      // The purge stays queued and the hourly cron retries it.
      await jobs.update(uid, {
        lease_until: null,
        next_attempt_at: now() + HOUR_MS,
      });
      logger.error("Citizen profile deletion will be retried.", {
        code: error?.message || "unknown",
      });
    }

    return await jobs.get(uid);
  }

  async function handleDeleteRequest(request, env) {
    const token = await accessToken(env);
    if (!token) return json({ error: "Server is not configured." }, 500);
    if (!projectId(env)) return json({ error: "Server is not configured." }, 500);

    const caller = await verifyCaller(request, env, token);
    if (caller.error) return caller.error;

    const body = await request.json().catch(() => null);
    if (body?.confirm !== true) {
      return json({ error: "Confirm permanent profile deletion." }, 400);
    }

    // Identity comes only from the verified token; any caller-supplied uid or
    // email is ignored.
    const uid = caller.uid;
    const claims = caller.claims || {};

    const staff = await firestoreProbe(env, token, `staff/${uid}`);
    const profile = await firestoreProbe(env, token, `users/${uid}`);
    if (staff.exists === null || profile.exists === null) {
      return json(
        { error: "Could not verify your account. Please try again later." },
        500,
      );
    }
    const role = profile.document?.fields?.role?.stringValue;
    if (
      staff.exists ||
      claims.admin === true ||
      claims.staff === true ||
      (claims.role && claims.role !== "citizen") ||
      (role && role !== "citizen")
    ) {
      return json(
        { error: "Only citizen accounts can delete their profile." },
        403,
      );
    }

    const jobs = jobsFor(env);
    const existing = await jobs.get(uid);
    if (existing?.status === "deleted") {
      return json({
        status: "deleted",
        emailStatus: existing.email_status || "unavailable",
      });
    }

    const email = String(profile.document?.fields?.email?.stringValue || "")
      .trim()
      .toLowerCase();
    const usable = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ? email : null;
    const deleteAt = now() + RETENTION_MS;

    // The request no longer deletes anything right away: the account goes to a
    // deactivation stage, signs in normally, and is purged after 30 days.
    if (!existing) {
      await jobs.insert({
        uid,
        email: usable,
        status: "deactivated",
        email_status: usable ? "pending" : "unavailable",
        requested_at: now(),
        purge_deadline: deleteAt,
        next_attempt_at: deleteAt,
        lease_until: null,
      });
    } else if (existing.status === "cancelled") {
      // A new request after cancelling starts a fresh 30-day window.
      await jobs.update(uid, {
        status: "deactivated",
        email: usable ?? existing.email,
        email_status: usable || existing.email ? "pending" : "unavailable",
        requested_at: now(),
        purge_deadline: deleteAt,
        next_attempt_at: deleteAt,
        deleted_at: null,
        lease_until: null,
      });
    }

    const job = await jobs.get(uid);
    if (!job) {
      return json({ error: "Could not save the deletion request." }, 500);
    }

    // Signing in reads the schedule from the profile, so the dialog appears
    // even when the app never calls the worker again.
    try {
      await markProfileDeactivated(
        env,
        token,
        uid,
        Number(job.requested_at) || now(),
        Number(job.purge_deadline) || deleteAt,
      );
    } catch (error) {
      logger.error("Could not mark the profile as deactivated.", {
        code: error?.message || "unknown",
      });
    }

    if (body?.immediate === true) {
      const purged = await processDeletion(env, token, uid, { force: true });
      if (purged?.status === "deleted") {
        return json({
          status: "deleted",
          emailStatus: purged.email_status || "unavailable",
        });
      }
    }

    const emailStatus = await deliverDeactivationEmail(env, jobs, job);
    return json({
      status: "deactivated",
      deleteAt: Number(job.purge_deadline) || deleteAt,
      emailStatus: emailStatus || "unavailable",
    });
  }

  // Restores a deactivated account before its 30-day deadline.
  async function handleCancelRequest(request, env) {
    const token = await accessToken(env);
    if (!token) return json({ error: "Server is not configured." }, 500);
    if (!projectId(env)) return json({ error: "Server is not configured." }, 500);

    const caller = await verifyCaller(request, env, token, { fresh: false });
    if (caller.error) return caller.error;
    const uid = caller.uid;

    const jobs = jobsFor(env);
    const job = await jobs.get(uid);
    if (job?.status === "deleted") {
      return json({ error: "This profile has already been deleted." }, 410);
    }
    if (job?.lease_until && Number(job.lease_until) > now()) {
      return json(
        {
          error:
            "Deletion is already in progress and can no longer be cancelled.",
        },
        409,
      );
    }

    if (job) {
      await jobs.update(uid, {
        status: "cancelled",
        email: null,
        email_status: "unavailable",
        next_attempt_at: null,
        lease_until: null,
      });
    }

    // Only report the account as restored once the profile says so.
    try {
      await markProfileActive(env, token, uid);
    } catch (error) {
      logger.error("Could not restore the citizen profile.", {
        code: error?.message || "unknown",
      });
      return json(
        { error: "We could not restore your account. Please try again." },
        500,
      );
    }

    return json({ status: "active" });
  }

  async function cancelCitizenDeletion(request, env) {
    try {
      return await handleCancelRequest(request, env);
    } catch (error) {
      logger.error("Citizen deletion cancellation failed.", {
        code: error?.message || "unknown",
      });
      return json(
        { error: "We could not restore your account. Please try again." },
        500,
      );
    }
  }

  // Every failure answers with JSON, so the app can show the real reason
  // instead of its generic "could not confirm deletion" fallback.
  async function deleteCitizenProfile(request, env) {
    try {
      return await handleDeleteRequest(request, env);
    } catch (error) {
      logger.error("Citizen profile deletion failed.", {
        code: error?.message || "unknown",
      });
      return json(
        {
          error:
            "We could not finish deleting your profile. Please try again in a moment.",
        },
        500,
      );
    }
  }

  async function retryCitizenDeletions(env) {
    const token = await accessToken(env);
    if (!token) return;
    const rows = await jobsFor(env).due(now(), 50);
    for (const row of rows) {
      await processDeletion(env, token, row.uid);
    }
  }

  return {
    deleteCitizenProfile,
    cancelCitizenDeletion,
    retryCitizenDeletions,
  };
}
