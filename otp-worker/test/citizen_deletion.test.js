import assert from "node:assert/strict";
import test from "node:test";

import {
  createCitizenDeletionHandlers,
  createD1Jobs,
} from "../src/citizen_deletion.js";

const NOW = Date.UTC(2026, 0, 1, 12, 0, 0);
const DAY = 24 * 60 * 60 * 1000;

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
    dueRows: [],
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
      if (row.status === "cancelled") return false;
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
      return this.dueRows;
    },
  };
}

function firestoreRequest({ staffExists = false, profileRole } = {}) {
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
        staffExists
          ? Response.json({ name: "staff/citizen-1" })
          : new Response("", { status: 404 }),
      );
    }
    if (url.includes("/documents/users/citizen-1") && method === "PATCH") {
      return Promise.resolve(Response.json({}));
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
    if (url.includes(":runQuery")) return Promise.resolve(Response.json([]));
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

function request(path = "/delete-citizen-profile", body = { confirm: true }) {
  return new Request(`https://worker.test${path}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token({ authTime: Math.floor(NOW / 1000) })}`,
    },
    body: JSON.stringify(body),
  });
}

function handlers(fetchImpl) {
  const jobs = createJobs();
  const emails = [];
  const deletedChallenges = [];
  const clock = { now: NOW };
  const subject = createCitizenDeletionHandlers({
    jobsFor: () => jobs,
    projectId: () => "project",
    accessToken: async () => "token",
    sendConfirmation: async (_env, email, deleteAt) => {
      emails.push({ email, deleteAt });
    },
    deleteOtpChallenges: async (_env, email) => {
      deletedChallenges.push(email);
    },
    fetch: fetchImpl,
    now: () => clock.now,
    logger: { error() {} },
  });
  return { subject, jobs, emails, deletedChallenges, clock };
}

test("confirming deletion deactivates the account and schedules the purge", async () => {
  const calls = [];
  const base = firestoreRequest({});
  const { subject, jobs, emails, deletedChallenges } = handlers((url, init) => {
    calls.push(url.replace(/^https:\/\/[^/]+/, ""));
    return base(url, init);
  });

  const response = await subject.deleteCitizenProfile(request(), {});
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    status: "deactivated",
    deleteAt: NOW + 30 * DAY,
    emailStatus: "sent",
  });

  // Nothing is removed yet: the citizen can still sign in during the window.
  assert.equal(calls.filter((url) => url.includes("accounts:delete")).length, 0);
  assert.equal(calls.filter((url) => url.includes("accounts:update")).length, 0);
  assert.deepEqual(deletedChallenges, []);

  const patched = calls.find((url) => url.includes("users/citizen-1?"));
  assert.ok(patched.includes("deletionStatus"));

  assert.deepEqual(emails, [
    { email: "citizen@example.com", deleteAt: NOW + 30 * DAY },
  ]);

  const job = jobs.rows.get("citizen-1");
  assert.equal(job.status, "deactivated");
  assert.equal(job.email_status, "sent");
  assert.equal(job.email, null);
  assert.equal(job.purge_deadline, NOW + 30 * DAY);
  assert.equal(job.next_attempt_at, NOW + 30 * DAY);
});

test("the hourly cron purges the account once the 30 days are over", async () => {
  const calls = [];
  const base = firestoreRequest({});
  const { subject, jobs, clock, deletedChallenges } = handlers((url, init) => {
    calls.push(url.replace(/^https:\/\/[^/]+/, ""));
    return base(url, init);
  });

  await subject.deleteCitizenProfile(request(), {});
  calls.length = 0;

  // Still inside the window: the cron must not touch the account.
  jobs.dueRows = [{ uid: "citizen-1" }];
  clock.now = NOW + 20 * DAY;
  await subject.retryCitizenDeletions({});
  assert.equal(calls.filter((url) => url.includes("accounts:delete")).length, 0);
  assert.equal(jobs.rows.get("citizen-1").status, "deactivated");

  // A row written by the previous release (`pending`) keeps its own deadline
  // instead of being purged the moment the new worker is deployed.
  jobs.rows.set("legacy", {
    uid: "legacy",
    status: "pending",
    email: null,
    email_status: "unavailable",
    purge_deadline: NOW + 29 * DAY,
    next_attempt_at: NOW,
    lease_until: null,
  });
  jobs.dueRows = [{ uid: "legacy" }];
  await subject.retryCitizenDeletions({});
  assert.equal(calls.filter((url) => url.includes("accounts:delete")).length, 0);
  assert.equal(jobs.rows.get("legacy").status, "pending");
  jobs.rows.delete("legacy");
  jobs.dueRows = [{ uid: "citizen-1" }];

  // Past the deadline: full cleanup.
  clock.now = NOW + 31 * DAY;
  await subject.retryCitizenDeletions({});
  assert.ok(calls.some((url) => url.endsWith("accounts:update")));
  assert.ok(calls.some((url) => url.endsWith("accounts:delete")));
  assert.equal(jobs.rows.get("citizen-1").status, "deleted");
  // The confirmation address was dropped at deactivation; expired OTP rows are
  // removed by the worker's hourly sweep instead.
  assert.deepEqual(deletedChallenges, []);
});

test("a deactivated citizen can cancel the deletion from the sign-in dialog", async () => {
  const calls = [];
  const base = firestoreRequest({});
  const { subject, jobs } = handlers((url, init) => {
    calls.push(url.replace(/^https:\/\/[^/]+/, ""));
    return base(url, init);
  });

  await subject.deleteCitizenProfile(request(), {});
  calls.length = 0;

  const response = await subject.cancelCitizenDeletion(
    request("/cancel-citizen-deletion", { confirm: true }),
    {},
  );
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { status: "active" });

  const patched = calls.find((url) => url.includes("users/citizen-1?"));
  assert.ok(patched.includes("deletionStatus"));
  assert.equal(jobs.rows.get("citizen-1").status, "cancelled");
  assert.equal(jobs.rows.get("citizen-1").next_attempt_at, null);

  // A cancelled job is never purged by the cron.
  jobs.dueRows = [{ uid: "citizen-1" }];
  await subject.retryCitizenDeletions({});
  assert.equal(calls.filter((url) => url.includes("accounts:delete")).length, 0);
});

test("rejects a verification older than five minutes without touching data", async () => {
  const calls = [];
  const base = firestoreRequest({});
  const { subject, jobs } = handlers((url, init) => {
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
  assert.equal(jobs.rows.has("citizen-1"), false);
});

test("staff and administrator accounts cannot delete a citizen profile", async () => {
  const { subject, jobs } = handlers(firestoreRequest({ staffExists: true }));
  const response = await subject.deleteCitizenProfile(request(), {});
  assert.equal(response.status, 403);
  assert.match((await response.json()).error, /Only citizen accounts/);
  assert.equal(jobs.rows.has("citizen-1"), false);
});

test("creates the deletion table before the first query", async () => {
  const statements = [];
  const db = {
    prepare(sql) {
      return {
        sql,
        bind() {
          return this;
        },
        async first() {
          return null;
        },
        async all() {
          return { results: [] };
        },
        async run() {
          statements.push(sql);
          return { meta: { changes: 0 } };
        },
      };
    },
    async batch(list) {
      for (const statement of list) statements.push(statement.sql);
    },
  };

  const jobs = createD1Jobs(db);
  await jobs.get("citizen-1");
  await jobs.get("citizen-1");

  const creates = statements.filter((sql) =>
    sql.includes("CREATE TABLE IF NOT EXISTS citizen_deletions"),
  );
  assert.equal(creates.length, 1);
  assert.ok(statements.some((sql) => sql.includes("CREATE INDEX")));
});

test("a storage failure answers with JSON instead of an empty 500", async () => {
  const subject = createCitizenDeletionHandlers({
    jobsFor: () => ({
      async get() {
        throw new Error("D1_ERROR: no such table: citizen_deletions");
      },
    }),
    projectId: () => "project",
    accessToken: async () => "token",
    sendConfirmation: async () => {},
    deleteOtpChallenges: async () => {},
    fetch: firestoreRequest({}),
    now: () => NOW,
    logger: { error() {} },
  });

  const response = await subject.deleteCitizenProfile(request(), {});
  assert.equal(response.status, 500);
  assert.match((await response.json()).error, /could not finish deleting/);
});

test("a caller cannot opt out of the confirmation flag", async () => {
  const { subject } = handlers(firestoreRequest({}));
  const response = await subject.deleteCitizenProfile(
    request("/delete-citizen-profile", { confirm: false }),
    {},
  );
  assert.equal(response.status, 400);
});
