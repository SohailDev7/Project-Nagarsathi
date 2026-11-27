import assert from "node:assert/strict";
import test from "node:test";

import { createCitizenDeletionHandlers } from "../src/citizen_deletion.js";

const NOW = Date.UTC(2026, 0, 1, 12, 0, 0);

function token({ authTime, provider = "password" }) {
  const encode = (value) =>
    Buffer.from(JSON.stringify(value)).toString("base64url");
  return `${encode({ alg: "RS256", typ: "JWT" })}.${encode({
    auth_time: authTime,
    firebase: { sign_in_provider: provider },
  })}.signature`;
}

function createJobs() {
  const rows = new Map();
  return {
    rows,
    async get(uid) {
      const row = rows.get(uid);
      return row ? { ...row } : null;
    },
    async insert(row) {
      if (!rows.has(row.uid)) rows.set(row.uid, { ...row });
    },
    async claim(uid, leaseUntil, nextAttemptAt, at) {
      const row = rows.get(uid);
      if (!row) return false;
      if (row.lease_until && row.lease_until > at) return false;
      if (row.status === "deleted" && row.email_status !== "pending") {
        return false;
      }
      row.lease_until = leaseUntil;
      row.next_attempt_at = nextAttemptAt;
      return true;
    },
    async update(uid, patch) {
      Object.assign(rows.get(uid), patch);
    },
    async due() {
      return [];
    },
  };
}

function firestoreRequest({ staffExists = false, profileRole, reportOnce = true }) {
  let queried = false;
  return (url, init = {}) => {
    const method = init.method || "GET";
    if (url.includes("accounts:lookup")) {
      return Promise.resolve(
        Response.json({ users: [{ localId: "citizen-1" }] }),
      );
    }
    if (url.includes("accounts:update") || url.includes("accounts:delete")) {
      return Promise.resolve(Response.json({}));
    }
    if (url.includes("/documents/staff/citizen-1")) {
      return Promise.resolve(
        staffExists ? Response.json({ name: "staff/citizen-1" }) : new Response("", { status: 404 }),
      );
    }
    if (url.includes("/documents/users/citizen-1") && method === "GET") {
      return Promise.resolve(
        Response.json({
          fields: {
            email: { stringValue: "citizen@example.com" },
            ...(profileRole ? { role: { stringValue: profileRole } } : {}),
          },
        }),
      );
    }
    if (url.includes(":runQuery")) {
      if (!reportOnce || queried) return Promise.resolve(Response.json([]));
      queried = true;
      return Promise.resolve(
        Response.json([
          {
            document: {
              name: "projects/p/databases/(default)/documents/reports/r1",
            },
          },
        ]),
      );
    }
    if (url.includes(":commit")) return Promise.resolve(Response.json({}));
    if (url.includes(":listCollectionIds")) {
      return Promise.resolve(Response.json({ collectionIds: [] }));
    }
    if (method === "GET" && url.includes("/documents/users/citizen-1/")) {
      return Promise.resolve(Response.json({ documents: [] }));
    }
    if (method === "DELETE") return Promise.resolve(Response.json({}));
    return Promise.resolve(new Response("", { status: 404 }));
  };
}

function request() {
  return new Request("https://worker.test/delete-citizen-profile", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token({ authTime: Math.floor(NOW / 1000) })}`,
    },
    body: JSON.stringify({ confirm: true }),
  });
}

function handlers(fetchImpl) {
  const jobs = createJobs();
  const emails = [];
  const deletedChallenges = [];
  const subject = createCitizenDeletionHandlers({
    jobsFor: () => jobs,
    projectId: () => "project",
    accessToken: async () => "token",
    sendConfirmation: async (_env, email) => {
      emails.push(email);
    },
    deleteOtpChallenges: async (_env, email) => {
      deletedChallenges.push(email);
    },
    fetch: fetchImpl,
    now: () => NOW,
    logger: { error() {} },
  });
  return { subject, jobs, emails, deletedChallenges };
}

test("deletes the verified citizen, anonymizes contributions and emails once", async () => {
  const calls = [];
  const base = firestoreRequest({});
  const { subject, jobs, emails, deletedChallenges } = handlers((url, init) => {
    calls.push(url.replace(/^https:\/\/[^/]+/, ""));
    return base(url, init);
  });

  const response = await subject.deleteCitizenProfile(request(), {});
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    status: "deleted",
    emailStatus: "sent",
  });

  assert.ok(calls.some((url) => url.endsWith("accounts:update")));
  assert.ok(calls.some((url) => url.endsWith("accounts:delete")));
  assert.deepEqual(emails, ["citizen@example.com"]);
  assert.deepEqual(deletedChallenges, ["citizen@example.com"]);

  const job = jobs.rows.get("citizen-1");
  assert.equal(job.status, "deleted");
  assert.equal(job.email_status, "sent");
  assert.equal(job.email, null);
});

test("rejects a verification older than five minutes without touching data", async () => {
  const calls = [];
  const base = firestoreRequest({});
  const { subject } = handlers((url, init) => {
    calls.push(url);
    return base(url, init);
  });

  const stale = new Request("https://worker.test/delete-citizen-profile", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token({ authTime: Math.floor(NOW / 1000) - 600 })}`,
    },
    body: JSON.stringify({ confirm: true }),
  });

  const response = await subject.deleteCitizenProfile(stale, {});
  assert.equal(response.status, 401);
  assert.deepEqual(await response.json(), { error: "Verify your account again." });
  assert.equal(calls.filter((url) => url.includes("accounts:delete")).length, 0);
});

test("staff and administrator accounts cannot delete a citizen profile", async () => {
  const { subject } = handlers(firestoreRequest({ staffExists: true }));
  const response = await subject.deleteCitizenProfile(request(), {});
  assert.equal(response.status, 403);
  assert.match((await response.json()).error, /Only citizen accounts/);
});

test("a caller cannot opt out of the confirmation flag", async () => {
  const { subject } = handlers(firestoreRequest({}));
  const response = await subject.deleteCitizenProfile(
    new Request("https://worker.test/delete-citizen-profile", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${token({ authTime: Math.floor(NOW / 1000) })}`,
      },
      body: JSON.stringify({ confirm: false }),
    }),
    {},
  );
  assert.equal(response.status, 400);
});
