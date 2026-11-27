const { test } = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const { createCitizenDeletionHandlers } = require("../citizen_deletion");

const START = 1800000000000;
const HOUR = 3600000;
const DELETE = Symbol("delete");

class HttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

function fixture() {
  let clock = START;
  let transactions = Promise.resolve();
  const records = new Map([
    ["users/citizen", { uid: "citizen", role: "citizen", name: "Citizen", email: "citizen@example.com", phone: "+9779800000000" }],
    ["users/citizen/preferences/private", { email: "citizen@example.com" }],
    ["users/other", { uid: "other", role: "citizen", email: "other@example.com" }],
    ["otpChallenges/" + crypto.createHash("sha256").update("citizen@example.com").digest("hex"), { email: "citizen@example.com" }],
  ]);
  const accounts = new Map([
    ["citizen", { email: "citizen@example.com" }],
    ["other", { email: "other@example.com" }],
  ]);
  const events = [];
  const sent = [];
  const failures = { cleanup: false, mail: false, revoke: false };
  const Timestamp = { fromMillis: (millis) => ({ toMillis: () => millis }) };
  const snapshot = (path) => ({
    exists: records.has(path),
    ref: reference(path),
    data: () => records.has(path) ? { ...records.get(path) } : undefined,
  });
  function apply(path, patch) {
    const value = { ...records.get(path) };
    for (const [field, replacement] of Object.entries(patch)) {
      if (replacement === DELETE) delete value[field];
      else value[field] = replacement;
    }
    records.set(path, value);
  }
  function reference(path) {
    return {
      id: path.split("/").at(-1),
      path,
      get: async () => snapshot(path),
      update: async (patch) => apply(path, patch),
      delete: async () => records.delete(path),
    };
  }
  function query(collection, group = false) {
    let field;
    let operator;
    let comparison;
    let count = Infinity;
    const api = {
      doc: (id) => reference(collection + "/" + id),
      where: (key, op, value) => {
        field = key;
        operator = op;
        comparison = value;
        return api;
      },
      limit: (limit) => { count = limit; return api; },
      get: async () => {
        const docs = [...records.entries()].filter(([path, data]) => {
          const parts = path.split("/");
          if (parts.at(-2) !== collection || (!group && parts.length !== 2)) return false;
          if (!field) return true;
          const actual = data[field];
          if (operator === "==") return actual === comparison;
          return actual && actual.toMillis() <= comparison.toMillis();
        }).slice(0, count).map(([path]) => snapshot(path));
        return { docs, empty: docs.length === 0 };
      },
    };
    return api;
  }
  const db = {
    collection: (name) => query(name),
    collectionGroup: (name) => query(name, true),
    runTransaction: (work) => {
      const turn = transactions.then(async () => {
        const writes = [];
        const outcome = await work({
          get: (ref) => ref.get(),
          set: (ref, value) => writes.push(() => records.set(ref.path, value)),
          update: (ref, value) => writes.push(() => apply(ref.path, value)),
        });
        for (const write of writes) write();
        return outcome;
      });
      transactions = turn.catch(() => {});
      return turn;
    },
    batch: () => {
      const writes = [];
      return {
        update: (ref, value) => writes.push(() => apply(ref.path, value)),
        commit: async () => { for (const write of writes) write(); },
      };
    },
    recursiveDelete: async (ref) => {
      if (failures.cleanup) throw new HttpsError("unavailable", "Temporary outage");
      events.push("delete-profile");
      for (const path of records.keys()) {
        if (path === ref.path || path.startsWith(ref.path + "/")) records.delete(path);
      }
    },
  };
  function account(uid) {
    if (!accounts.has(uid)) throw new HttpsError("auth/user-not-found", "Missing");
    return accounts.get(uid);
  }
  const handlers = createCitizenDeletionHandlers({
    db,
    auth: {
      getUser: async (uid) => account(uid),
      updateUser: async (uid, update) => {
        Object.assign(account(uid), update);
        events.push("disable");
      },
      revokeRefreshTokens: async (uid) => {
        account(uid);
        if (failures.revoke) throw new HttpsError("unavailable", "Temporary outage");
        events.push("revoke");
      },
      deleteUser: async (uid) => {
        account(uid);
        accounts.delete(uid);
        events.push("delete-credentials");
      },
    },
    Timestamp,
    FieldValue: { delete: () => DELETE },
    HttpsError,
    now: () => clock,
    sendConfirmation: async (email) => {
      assert.equal(accounts.has("citizen"), false, "Confirmation must follow credential deletion");
      if (failures.mail) throw new HttpsError("unavailable", "Mail outage");
      sent.push(email);
      events.push("send-mail");
    },
  });
  return {
    ...handlers, records, accounts, events, failures, sent, Timestamp,
    advance: (millis) => { clock += millis; },
    request: (changes = {}) => ({
      auth: {
        uid: "citizen",
        token: { auth_time: clock / 1000, firebase: { sign_in_provider: "password" } },
      },
      data: { confirm: true },
      ...changes,
    }),
  };
}

test("deletes only the verified citizen, anonymizes contributions and sends final email", async () => {
  const f = fixture();
  f.records.set("reports/one", {
    authorId: "citizen", authorName: "Citizen", authorEmail: "citizen@example.com",
    authorPhone: "+9779800000000", authorPhotoUrl: "private-photo",
    author: { uid: "citizen", name: "Citizen", email: "citizen@example.com" },
    title: "Pothole on the main road", status: "open",
  });
  f.records.set("reports/one/comments/first", {
    authorId: "citizen", author: { name: "Citizen", phone: "+9779800000000" },
    body: "Still needs repair",
  });
  f.records.set("reports/other", { authorId: "other", author: { name: "Other" }, title: "Street light" });
  const result = await f.deleteCitizenProfile(f.request({
    data: { confirm: true, uid: "other", email: "other@example.com" },
  }));

  assert.deepEqual(result, { status: "deleted", emailStatus: "sent" });
  assert.equal(f.accounts.has("citizen"), false);
  assert.equal(f.accounts.has("other"), true);
  assert.equal(f.records.has("users/citizen"), false);
  assert.equal(f.records.has("users/citizen/preferences/private"), false);
  assert.equal([...f.records.keys()].some((key) => key.startsWith("otpChallenges/")), false);
  const report = f.records.get("reports/one");
  assert.equal(report.title, "Pothole on the main road");
  assert.equal(report.status, "open");
  assert.deepEqual(report.author, { name: "Deleted citizen" });
  for (const field of ["authorId", "authorEmail", "authorPhone", "authorPhotoUrl"]) {
    assert.equal(field in report, false);
  }
  assert.equal(f.records.get("reports/one/comments/first").body, "Still needs repair");
  assert.deepEqual(f.records.get("reports/one/comments/first").author, { name: "Deleted citizen" });
  assert.equal(f.records.get("reports/other").authorId, "other");
  assert.deepEqual(f.sent, ["citizen@example.com"]);
  assert.deepEqual(f.events, ["disable", "revoke", "delete-profile", "delete-credentials", "send-mail"]);
  const marker = f.records.get("citizenDeletions/citizen");
  assert.equal(marker.status, "deleted");
  assert.equal("email" in marker, false);
  assert.equal("otpChallengeId" in marker, false);
  assert.equal("nextAttemptAt" in marker, false);
});

test("rejects missing consent, anonymous sessions, stale verification and custom tokens", async () => {
  for (const [changes, expected] of [
    [{ data: { confirm: false } }, "invalid-argument"],
    [{ auth: null }, "unauthenticated"],
    [{ auth: { uid: "citizen", token: { auth_time: (START - 301000) / 1000, firebase: { sign_in_provider: "password" } } } }, "failed-precondition"],
    [{ auth: { uid: "citizen", token: { auth_time: START / 1000, firebase: { sign_in_provider: "custom" } } } }, "failed-precondition"],
  ]) {
    const f = fixture();
    await assert.rejects(f.deleteCitizenProfile(f.request(changes)), { code: expected });
    assert.equal(f.accounts.has("citizen"), true);
    assert.equal(f.records.has("citizenDeletions/citizen"), false);
    assert.deepEqual(f.events, []);
  }
});

test("staff and administrator accounts cannot enter the citizen deletion workflow", async () => {
  for (const setup of [
    (f) => f.records.set("staff/citizen", { role: "staff", active: false }),
    (f) => f.records.set("users/citizen", { role: "staff" }),
    (f) => { f.accounts.get("citizen").customClaims = { admin: true }; },
  ]) {
    const f = fixture();
    setup(f);
    await assert.rejects(f.deleteCitizenProfile(f.request()), { code: "permission-denied" });
    assert.equal(f.records.has("citizenDeletions/citizen"), false);
    assert.equal(f.accounts.has("citizen"), true);
  }
});

test("anonymization spans multiple pages without changing other citizens' reports", async () => {
  const f = fixture();
  for (let index = 0; index < 505; index++) {
    f.records.set("reports/" + index, { authorId: "citizen", title: "Report " + index });
  }
  await f.deleteCitizenProfile(f.request());
  assert.equal([...f.records.values()].some((data) => data.authorId === "citizen"), false);
  assert.equal([...f.records.keys()].filter((key) => key.startsWith("reports/")).length, 505);
});

test("interrupted cleanup is saved, closes the account and resumes on the hourly retry", async () => {
  const f = fixture();
  f.failures.cleanup = true;
  assert.deepEqual(await f.deleteCitizenProfile(f.request()), { status: "pending", emailStatus: "pending" });
  assert.equal(f.accounts.get("citizen").disabled, true);
  assert.equal(f.records.has("users/citizen"), true);
  assert.deepEqual(f.sent, []);
  f.failures.cleanup = false;
  f.advance(HOUR);
  await f.retryCitizenDeletions();
  assert.equal(f.accounts.has("citizen"), false);
  assert.equal(f.records.has("users/citizen"), false);
  assert.equal(f.records.get("citizenDeletions/citizen").emailStatus, "sent");
});

test("an email outage does not undo deletion and delivery is retried after credentials are gone", async () => {
  const f = fixture();
  f.failures.mail = true;
  assert.deepEqual(await f.deleteCitizenProfile(f.request()), { status: "deleted", emailStatus: "pending" });
  assert.equal(f.accounts.has("citizen"), false);
  assert.equal(f.records.get("citizenDeletions/citizen").email, "citizen@example.com");
  f.failures.mail = false;
  f.advance(HOUR);
  await f.retryCitizenDeletions();
  assert.deepEqual(f.sent, ["citizen@example.com"]);
  assert.equal("email" in f.records.get("citizenDeletions/citizen"), false);
});

test("a revocation outage saves the request and retries session closure before final deletion", async () => {
  const f = fixture();
  f.failures.revoke = true;
  assert.deepEqual(await f.deleteCitizenProfile(f.request()), { status: "pending", emailStatus: "pending" });
  assert.equal(f.accounts.get("citizen").disabled, true);
  assert.equal(f.records.has("users/citizen"), true);
  assert.deepEqual(f.sent, []);
  f.failures.revoke = false;
  f.advance(HOUR);
  await f.retryCitizenDeletions();
  assert.equal(f.accounts.has("citizen"), false);
  assert.deepEqual(f.sent, ["citizen@example.com"]);
});

test("undeliverable confirmation addresses are purged after 30 days", async () => {
  const f = fixture();
  f.failures.mail = true;
  await f.deleteCitizenProfile(f.request());
  f.advance(30 * 24 * HOUR);
  await f.retryCitizenDeletions();
  const marker = f.records.get("citizenDeletions/citizen");
  assert.equal("email" in marker, false);
  assert.equal("nextAttemptAt" in marker, false);
  assert.equal(marker.emailStatus, "unavailable");
});

test("phone-only citizens can leave without claiming an email was sent", async () => {
  const f = fixture();
  f.accounts.get("citizen").email = null;
  f.records.set("users/citizen", { uid: "citizen", role: "citizen", phone: "+9779800000000" });
  const request = f.request();
  request.auth.token.firebase.sign_in_provider = "phone";
  assert.deepEqual(await f.deleteCitizenProfile(request), { status: "deleted", emailStatus: "unavailable" });
  assert.deepEqual(f.sent, []);
});

test("concurrent confirmed requests share one deletion and one confirmation email", async () => {
  const f = fixture();
  await Promise.all([
    f.deleteCitizenProfile(f.request()),
    f.deleteCitizenProfile(f.request()),
  ]);
  assert.equal(f.events.filter((event) => event === "delete-credentials").length, 1);
  assert.equal(f.sent.length, 1);
});
