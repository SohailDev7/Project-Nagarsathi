import test from "node:test";
import assert from "node:assert/strict";
import worker from "../src/index.js";
import {
  EXPORT_EXPIRY_MS,
  buildExportJson,
  buildExportPdf,
  buildZipArchive,
  decryptDownloadToken,
  encryptDownloadToken,
} from "../src/export.js";

function createMockD1() {
  const tables = {
    otp_challenges: new Map(),
    data_exports: new Map(),
  };

  return {
    tables,
    prepare(sql) {
      let bindings = [];
      const stmt = {
        bind(...args) {
          bindings = args;
          return stmt;
        },
        async first() {
          if (sql.includes("COUNT(*) AS total FROM data_exports")) {
            const [userId, cutoff] = bindings;
            let total = 0;
            for (const row of tables.data_exports.values()) {
              if (row.user_id === userId && row.created_at > cutoff) {
                total += 1;
              }
            }
            return { total };
          }
          if (sql.includes("SELECT * FROM data_exports WHERE export_id = ?")) {
            return tables.data_exports.get(bindings[0]) || null;
          }
          return null;
        },
        async run() {
          if (sql.startsWith("DELETE FROM data_exports WHERE expires_at <=")) {
            const [cutoff] = bindings;
            for (const [id, row] of tables.data_exports.entries()) {
              if (row.expires_at <= cutoff) tables.data_exports.delete(id);
            }
          } else if (sql.startsWith("DELETE FROM data_exports WHERE export_id = ?")) {
            tables.data_exports.delete(bindings[0]);
          } else if (sql.includes("INSERT INTO data_exports")) {
            const [
              export_id,
              user_id,
              email_hash,
              recipient_email,
              encrypted_payload,
              payload_iv,
              report_count,
              comment_count,
              created_at,
              expires_at,
            ] = bindings;
            tables.data_exports.set(export_id, {
              export_id,
              user_id,
              email_hash,
              recipient_email,
              status: "ready",
              encrypted_payload,
              payload_iv,
              report_count,
              comment_count,
              created_at,
              expires_at,
              delivered_at: null,
            });
          } else if (sql.includes("UPDATE data_exports SET status = 'sent'")) {
            const [delivered_at, export_id] = bindings;
            const row = tables.data_exports.get(export_id);
            if (row) {
              row.status = "sent";
              row.delivered_at = delivered_at;
            }
          }
          return { success: true };
        },
      };
      return stmt;
    },
  };
}

async function createTestPemPrivateKey() {
  const keyPair = await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"],
  );
  const pkcs8 = await crypto.subtle.exportKey("pkcs8", keyPair.privateKey);
  const b64 = Buffer.from(pkcs8).toString("base64");
  const lines = b64.match(/.{1,64}/g).join("\n");
  return `-----BEGIN PRIVATE KEY-----\n${lines}\n-----END PRIVATE KEY-----`;
}

test("encryptDownloadToken and decryptDownloadToken reject tampering", async () => {
  const secret = "test-secret-key-32-chars-minimum!!";
  const token = await encryptDownloadToken(secret, {
    exportId: "exp-1",
    userId: "user-1",
    expiresAt: Date.now() + EXPORT_EXPIRY_MS,
  });

  const decoded = await decryptDownloadToken(secret, token);
  assert.equal(decoded.exportId, "exp-1");
  assert.equal(decoded.userId, "user-1");

  const tampered = `${token.slice(0, -4)}AAAA`;
  assert.equal(await decryptDownloadToken(secret, tampered), null);
  assert.equal(await decryptDownloadToken("wrong-secret", token), null);
});

test("buildExportPdf creates valid multi-page PDF 1.4 and buildZipArchive packs JSON + PDF", () => {
  const reports = Array.from({ length: 30 }, (_, i) => ({
    id: `rep-${i + 1}`,
    title: `Pothole #${i + 1}`,
    category: "roads",
    status: "reported",
    description: "Broken asphalt near main chowk needing urgent repair.",
  }));
  const comments = [
    { id: "c-1", reportId: "rep-1", text: "Water logging makes this worse." },
  ];
  const requestedAt = 1795700000000;
  const expiresAt = requestedAt + EXPORT_EXPIRY_MS;

  const jsonStr = buildExportJson({
    exportId: "exp-pdf-1",
    profile: { uid: "u-1", name: "Sita Sharma", email: "sita@example.com" },
    reports,
    comments,
    requestedAt,
    expiresAt,
  });
  const parsed = JSON.parse(jsonStr);
  assert.equal(parsed.summary.totalReports, 30);
  assert.equal(parsed.summary.totalComments, 1);

  const pdfBytes = buildExportPdf({
    exportId: "exp-pdf-1",
    profile: { uid: "u-1", name: "Sita Sharma", email: "sita@example.com" },
    reports,
    comments,
    requestedAt,
    expiresAt,
  });
  const pdfText = Buffer.from(pdfBytes).toString("latin1");
  assert.ok(pdfText.startsWith("%PDF-1.4\n"));
  assert.ok(pdfText.includes("xref\n"));
  assert.ok(pdfText.trimEnd().endsWith("%%EOF"));
  assert.ok(pdfText.includes("Page 2 of"));

  const zip = buildZipArchive([
    { name: "nagarsathi-data-export.json", data: jsonStr },
    { name: "nagarsathi-data-export.pdf", data: pdfBytes },
  ]);
  // PKZIP local file header magic PK\x03\x04 and End of Central Directory PK\x05\x06
  assert.equal(zip[0], 0x50);
  assert.equal(zip[1], 0x4b);
  assert.equal(zip[2], 0x03);
  assert.equal(zip[3], 0x04);
  const zipStr = Buffer.from(zip).toString("latin1");
  assert.ok(zipStr.includes("nagarsathi-data-export.json"));
  assert.ok(zipStr.includes("nagarsathi-data-export.pdf"));
});

test("worker request-data-export encrypts export, emails link, serves JSON/PDF/ZIP, and enforces 48h expiry", async () => {
  const privateKey = await createTestPemPrivateKey();
  const db = createMockD1();
  const sentEmails = [];

  const env = {
    DB: db,
    OTP_PEPPER: "pepper-secret-for-testing-1234",
    GMAIL_MAIL_ENDPOINT: "https://mail.example.test/send",
    GMAIL_MAIL_SECRET: "mail-key",
    FIREBASE_SERVICE_ACCOUNT: JSON.stringify({
      project_id: "nagar-sathi-test",
      client_email: "test@nagar-sathi-test.iam.gserviceaccount.com",
      private_key: privateKey,
    }),
  };

  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (url, options) => {
    const href = String(url);
    if (href === "https://oauth2.googleapis.com/token") {
      return new Response(
        JSON.stringify({ access_token: "google-access-token", expires_in: 3600 }),
        { status: 200 },
      );
    }
    if (href.includes("identitytoolkit.googleapis.com") && href.includes("accounts:lookup")) {
      return new Response(
        JSON.stringify({
          users: [
            {
              localId: "citizen-uid-42",
              email: "citizen@example.com",
              emailVerified: true,
              displayName: "Aarav Thapa",
            },
          ],
        }),
        { status: 200 },
      );
    }
    if (href.endsWith("/documents/users/citizen-uid-42")) {
      return new Response(
        JSON.stringify({
          name: "projects/nagar-sathi-test/databases/(default)/documents/users/citizen-uid-42",
          fields: {
            name: { stringValue: "Aarav Thapa" },
            email: { stringValue: "citizen@example.com" },
            role: { stringValue: "citizen" },
          },
        }),
        { status: 200 },
      );
    }
    if (href.endsWith(":runQuery")) {
      const reqBody = JSON.parse(options.body);
      const collectionId = reqBody.structuredQuery.from[0].collectionId;
      if (collectionId === "reports") {
        return new Response(
          JSON.stringify([
            {
              document: {
                name: "projects/nagar-sathi-test/databases/(default)/documents/reports/rep-101",
                fields: {
                  userId: { stringValue: "citizen-uid-42" },
                  title: { stringValue: "Streetlight outage" },
                  status: { stringValue: "reported" },
                },
              },
            },
          ]),
          { status: 200 },
        );
      }
      if (collectionId === "comments") {
        return new Response(
          JSON.stringify([
            {
              document: {
                name: "projects/nagar-sathi-test/databases/(default)/documents/comments/com-202",
                fields: {
                  userId: { stringValue: "citizen-uid-42" },
                  reportId: { stringValue: "rep-101" },
                  text: { stringValue: "Still dark near the school gate." },
                },
              },
            },
          ]),
          { status: 200 },
        );
      }
      return new Response(JSON.stringify([]), { status: 200 });
    }
    if (href === "https://mail.example.test/send") {
      sentEmails.push(JSON.parse(options.body));
      return new Response(JSON.stringify({ sent: true }), { status: 200 });
    }
    return new Response("Not found", { status: 404 });
  };

  try {
    // 1. Unauthenticated request is rejected
    const unauthRes = await worker.fetch(
      new Request("https://worker.example.test/request-data-export", {
        method: "POST",
        body: JSON.stringify({ locale: "en" }),
      }),
      env,
    );
    assert.equal(unauthRes.status, 401);

    // 2. Authenticated request succeeds
    const req = new Request("https://worker.example.test/request-data-export", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: "Bearer valid-firebase-id-token",
      },
      body: JSON.stringify({ locale: "en" }),
    });
    const res = await worker.fetch(req, env);
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.status, "sent");
    assert.equal(body.email, "citizen@example.com");
    assert.deepEqual(body.formats, ["json", "pdf"]);
    assert.equal(body.reportCount, 1);
    assert.equal(body.commentCount, 1);
    assert.equal(body.expiresAt - body.requestedAt, EXPORT_EXPIRY_MS);
    assert.equal(body.deliverySlaMinutes, 15);

    // 3. Stored payload in D1 is encrypted (not readable as plaintext JSON/PDF)
    const stored = db.tables.data_exports.get(body.exportId);
    assert.ok(stored);
    assert.ok(!stored.encrypted_payload.includes("Aarav Thapa"));
    assert.ok(!stored.encrypted_payload.includes("Streetlight outage"));

    // 4. Email was sent with encrypted download link
    assert.equal(sentEmails.length, 1);
    assert.equal(sentEmails[0].to, "citizen@example.com");
    const linkMatch = sentEmails[0].text.match(
      /https:\/\/worker\.example\.test\/data-export\/download\?token=([^\s]+)/,
    );
    assert.ok(linkMatch, "Expected download link in email text");
    const downloadUrl = linkMatch[0];

    // 5. Download ZIP, JSON, and PDF using encrypted link
    const zipRes = await worker.fetch(new Request(downloadUrl), env);
    assert.equal(zipRes.status, 200);
    assert.equal(zipRes.headers.get("Content-Type"), "application/zip");
    const zipBytes = new Uint8Array(await zipRes.arrayBuffer());
    assert.equal(zipBytes[0], 0x50);
    assert.equal(zipBytes[1], 0x4b);

    const jsonRes = await worker.fetch(new Request(`${downloadUrl}&format=json`), env);
    assert.equal(jsonRes.status, 200);
    const exportedJson = await jsonRes.json();
    assert.equal(exportedJson.profile.name, "Aarav Thapa");
    assert.equal(exportedJson.reports.length, 1);
    assert.equal(exportedJson.comments.length, 1);

    const pdfRes = await worker.fetch(new Request(`${downloadUrl}&format=pdf`), env);
    assert.equal(pdfRes.status, 200);
    assert.equal(pdfRes.headers.get("Content-Type"), "application/pdf");
    const pdfStr = Buffer.from(await pdfRes.arrayBuffer()).toString("latin1");
    assert.ok(pdfStr.startsWith("%PDF-1.4"));

    // 6. Tampered download token is rejected with 403
    const badRes = await worker.fetch(
      new Request(`${downloadUrl.slice(0, -4)}zzzz`),
      env,
    );
    assert.equal(badRes.status, 403);

    // 7. Expired link (>48 hours) returns 410 Gone and removes the export
    stored.expires_at = Date.now() - 1000;
    const expiredRes = await worker.fetch(new Request(downloadUrl), env);
    assert.equal(expiredRes.status, 410);
    assert.equal(db.tables.data_exports.has(body.exportId), false);

    // 8. Nepali locale email and hourly rate limiting (5 exports/hour max)
    for (let i = 0; i < 5; i += 1) {
      const okRes = await worker.fetch(
        new Request("https://worker.example.test/request-data-export", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: "Bearer valid-firebase-id-token",
          },
          body: JSON.stringify({ locale: "ne" }),
        }),
        env,
      );
      assert.equal(okRes.status, 200);
    }
    assert.ok(sentEmails[sentEmails.length - 1].subject.includes("नगरसाथी"));

    const rateLimitedRes = await worker.fetch(
      new Request("https://worker.example.test/request-data-export", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: "Bearer valid-firebase-id-token",
        },
        body: JSON.stringify({ locale: "en" }),
      }),
      env,
    );
    assert.equal(rateLimitedRes.status, 429);
  } finally {
    globalThis.fetch = originalFetch;
  }
});
