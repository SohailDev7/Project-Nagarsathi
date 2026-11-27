// Citizen profile deletion on Cloudflare Workers.
//
// The Firebase project is on the Spark plan, so the equivalent Cloud Functions
// callable cannot be deployed. This module performs the same trusted cleanup
// through Google's REST APIs with the worker's Firebase service account:
// disable + revoke the account, anonymize its public contributions, remove the
// Firestore profile tree, delete the Firebase Auth user, then email the
// confirmation. D1 keeps the request durable so an interrupted run resumes on
// the hourly cron.

const HOUR_MS = 60 * 60 * 1000;
// Leave a day's margin for the hourly purge before the 30-day maximum.
const RETENTION_MS = 29 * 24 * HOUR_MS;
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
  return {
    async get(uid) {
      return db
        .prepare("SELECT * FROM citizen_deletions WHERE uid = ?")
        .bind(uid)
        .first();
    },

    async insert(row) {
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
      const result = await db
        .prepare(
          `UPDATE citizen_deletions
           SET lease_until = ?, next_attempt_at = ?
           WHERE uid = ?
             AND (lease_until IS NULL OR lease_until <= ?)
             AND NOT (status = 'deleted' AND email_status != 'pending')`,
        )
        .bind(leaseUntil, nextAttemptAt, uid, at)
        .run();
      return Number(result?.meta?.changes || 0) > 0;
    },

    async update(uid, patch) {
      const columns = Object.keys(patch);
      if (!columns.length) return;
      const assignments = columns.map((column) => `${column} = ?`).join(", ");
      await db
        .prepare(`UPDATE citizen_deletions SET ${assignments} WHERE uid = ?`)
        .bind(...columns.map((column) => patch[column]), uid)
        .run();
    },

    async due(at, limit) {
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

  async function verifyCaller(request, env, token) {
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
      !Number.isFinite(verifiedAt) ||
      verifiedAt > now() + 30000 ||
      now() - verifiedAt > VERIFICATION_WINDOW_MS ||
      !VERIFIED_PROVIDERS.has(provider)
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

  async function processDeletion(env, token, uid) {
    const jobs = jobsFor(env);
    const job = await jobs.get(uid);
    if (!job) return null;
    if (job.status === "deleted" && job.email_status !== "pending") return job;
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
        });
      }

      if (job.email && Number(job.purge_deadline) > now()) {
        await sendConfirmation(env, job.email);
        await jobs.update(uid, {
          email: null,
          email_status: "sent",
          lease_until: null,
          next_attempt_at: null,
        });
      } else {
        await jobs.update(uid, {
          email: null,
          email_status: "unavailable",
          lease_until: null,
          next_attempt_at: null,
        });
      }
    } catch (error) {
      // Keep the request durable; email survives only while it can still be
      // used to send the confirmation, which is at most 30 days.
      const expired = Number(job.purge_deadline) <= now();
      await jobs.update(uid, {
        lease_until: null,
        next_attempt_at: now() + HOUR_MS,
        ...(expired ? { email: null, email_status: "unavailable" } : {}),
      });
      logger.error("Citizen profile deletion will be retried.", {
        code: error?.message || "unknown",
      });
    }

    return await jobs.get(uid);
  }

  async function deleteCitizenProfile(request, env) {
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
    if (!existing) {
      const email = String(profile.document?.fields?.email?.stringValue || "")
        .trim()
        .toLowerCase();
      const usable = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ? email : null;
      await jobs.insert({
        uid,
        email: usable,
        status: "pending",
        email_status: usable ? "pending" : "unavailable",
        requested_at: now(),
        purge_deadline: now() + RETENTION_MS,
        next_attempt_at: now(),
        lease_until: null,
      });
    }

    const job = await processDeletion(env, token, uid);
    if (!job) return json({ error: "Could not save the deletion request." }, 500);
    return json({
      status: job.status === "deleted" ? "deleted" : "pending",
      emailStatus: job.email_status || "unavailable",
    });
  }

  async function retryCitizenDeletions(env) {
    const token = await accessToken(env);
    if (!token) return;
    const rows = await jobsFor(env).due(now(), 50);
    for (const row of rows) {
      await processDeletion(env, token, row.uid);
    }
  }

  return { deleteCitizenProfile, retryCitizenDeletions };
}
