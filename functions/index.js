const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");
const crypto = require("crypto");
const { createCitizenDeletionHandlers } = require("./citizen_deletion");
const {
  EXPORT_EXPIRY_MS,
  DELIVERY_SLA_MINUTES,
  encryptDownloadToken,
  decryptDownloadToken,
  encryptExportBundle,
  decryptExportBundle,
  normalizeFirestoreData,
  buildExportDocument,
  buildExportPdf,
  buildZipArchive,
} = require("./export_helpers");

admin.initializeApp();
const db = admin.firestore();

const otpPepper = defineSecret("OTP_PEPPER");
const mailHost = defineSecret("MAIL_HOST");
const mailPort = defineSecret("MAIL_PORT");
const mailUser = defineSecret("MAIL_USER");
const mailPass = defineSecret("MAIL_PASS");
const gmailUser = defineSecret("GMAIL_USER");
const gmailAppPassword = defineSecret("GMAIL_APP_PASSWORD");

function mailer(user, pass) {
  return nodemailer.createTransport({
    service: "gmail",
    auth: { user, pass },
  });
}

function hashEmail(email) {
  return crypto.createHash("sha256").update(email.trim().toLowerCase()).digest("hex");
}

function hashOtp(email, otp, pepper) {
  return crypto.createHash("sha256")
    .update(email.trim().toLowerCase() + ":" + otp + ":" + pepper)
    .digest("hex");
}

exports.requestEmailOtp = onCall(
  { secrets: [otpPepper, gmailUser, gmailAppPassword] },
  async (request) => {
    const email = String(request.data?.email || "").trim().toLowerCase();
    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      throw new HttpsError("invalid-argument", "A valid email address is required.");
    }

    const otp = String(Math.floor(100004 + Math.random() * 899990));
    const hashed = hashOtp(email, otp, otpPepper.value());
    const expiresAt = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + 10 * 60 * 1000)
    );

    await db.collection("emailOtps").doc(hashEmail(email)).set({
      otpHash: hashed,
      expiresAt,
      attempts: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    try {
      await mailer(gmailUser.value(), gmailAppPassword.value()).sendMail({
        from: "NagarSathi <" + gmailUser.value() + ">",
        to: email,
        subject: otp + " is your NagarSathi verification code",
        text: "Your NagarSathi verification code is " + otp + ". It expires in 10 minutes.\n\nIf you did not request this, please ignore this email.",
        html: "<div style='font-family:sans-serif;padding:20px;max-width:480px;border:1px solid #e0e0e0;border-radius:12px;'>" +
          "<h2 style='color:#163B2B;margin-top:0;'>NagarSathi Code</h2>" +
          "<p style='font-size:15px;color:#333;'>Your verification code is:</p>" +
          "<div style='font-size:32px;font-weight:900;letter-spacing:6px;color:#2E7D0B;background:#F0FDF4;padding:16px;border-radius:8px;text-align:center;margin:16px 0;'>" + otp + "</div>" +
          "<p style='font-size:13px;color:#666;'>This code expires in 10 minutes. Do not share it with anyone.</p>" +
          "</div>",
      });
    } catch (err) {
      logger.error("Failed to send email OTP via Gmail Nodemailer", { email, error: err.message });
      throw new HttpsError("internal", "Failed to send verification email. Please try again later.");
    }

    return { sent: true };
  }
);

exports.verifyEmailOtp = onCall(
  { secrets: [otpPepper] },
  async (request) => {
    const email = String(request.data?.email || "").trim().toLowerCase();
    const otp = String(request.data?.otp || "").trim();
    if (!email || !otp) {
      throw new HttpsError("invalid-argument", "Email and code are required.");
    }

    const docRef = db.collection("emailOtps").doc(hashEmail(email));
    const doc = await docRef.get();

    if (!doc.exists) {
      throw new HttpsError("not-found", "No code found for this email. Request a new one.");
    }

    const data = doc.data();
    if (data.attempts >= 5) {
      await docRef.delete();
      throw new HttpsError("resource-exhausted", "Too many invalid attempts. Request a new code.");
    }

    if (data.expiresAt.toDate() < new Date()) {
      await docRef.delete();
      throw new HttpsError("deadline-exceeded", "Code has expired. Request a new one.");
    }

    if (data.otpHash !== hashOtp(email, otp, otpPepper.value())) {
      await docRef.update({ attempts: admin.firestore.FieldValue.increment(1) });
      throw new HttpsError("invalid-argument", "Invalid verification code. Please check and try again.");
    }

    await docRef.delete();

    let token = null;
    try {
      const user = await admin.auth().getUserByEmail(email);
      token = await admin.auth().createCustomToken(user.uid);
    } catch (_) {
      // User doesn't exist yet, that's fine for sign-up flow
    }
    return { verified: true, token };
  }
);

const citizenDeletion = createCitizenDeletionHandlers({
  db,
  auth: admin.auth(),
  Timestamp: admin.firestore.Timestamp,
  FieldValue: admin.firestore.FieldValue,
  HttpsError,
  logger,
  sendConfirmation: (email) =>
    mailer(gmailUser.value(), gmailAppPassword.value()).sendMail({
      from: "NagarSathi <" + gmailUser.value() + ">",
      to: email,
      subject: "Your NagarSathi profile has been deleted",
      text: "Your NagarSathi profile, personal data and sign-in credentials " +
        "have been permanently removed. Public reports and comments remain " +
        "without your identity. All account sessions have been revoked.",
    }),
});

exports.deleteCitizenProfile = onCall(
  { secrets: [gmailUser, gmailAppPassword], timeoutSeconds: 120 },
  citizenDeletion.deleteCitizenProfile,
);

exports.retryCitizenDeletions = onSchedule(
  {
    schedule: "every 60 minutes",
    secrets: [gmailUser, gmailAppPassword],
    timeoutSeconds: 540,
  },
  citizenDeletion.retryCitizenDeletions,
);

const GITHUB_OWNER = process.env.GITHUB_REPO_OWNER || "SohailDev7";
const GITHUB_REPO = process.env.GITHUB_REPO_NAME || "Project-Nagarsathi";
const RELEASE_TOPIC = "app_updates";
const RELEASE_CHANNEL_ID = "app_updates";

function parseReleaseSummary(notes) {
  const lines = String(notes || "")
    .split(/\r?\n/)
    .map((line) => line.replace(/^[\s\-#*•]+/, "").trim())
    .filter(Boolean);
  return lines[0] || "";
}

async function fetchLatestApkRelease() {
  const url = `https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/releases?per_page=10`;
  const headers = {
    Accept: "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
    "User-Agent": "NagarSathi-Release-Notifier",
  };
  if (process.env.GITHUB_TOKEN) {
    headers.Authorization = `Bearer ${process.env.GITHUB_TOKEN}`;
  }

  const response = await fetch(url, { headers });
  if (!response.ok) {
    throw new Error(`GitHub releases request failed with HTTP ${response.status}`);
  }
  const releases = await response.json();
  if (!Array.isArray(releases)) return null;

  for (const item of releases) {
    if (!item || item.draft || item.prerelease) continue;
    const tagName = String(item.tag_name || "").trim();
    if (!tagName) continue;
    const assets = Array.isArray(item.assets) ? item.assets : [];
    const apk = assets.find((asset) =>
      String(asset?.name || "").toLowerCase().endsWith(".apk")
    );
    if (!apk || !apk.browser_download_url) continue;

    return {
      tagName,
      version: tagName.replace(/^[vV]/, ""),
      title: String(item.name || tagName).trim(),
      notes: String(item.body || "").trim(),
      htmlUrl: String(item.html_url || ""),
      downloadUrl: String(apk.browser_download_url),
    };
  }
  return null;
}

async function broadcastReleaseIfNew(release) {
  if (!release || !release.tagName) {
    return { notified: false, reason: "no-release-with-apk" };
  }

  const stateRef = db.collection("appConfig").doc("latestRelease");
  const isNew = await db.runTransaction(async (tx) => {
    const snap = await tx.get(stateRef);
    const prevTag = snap.exists ? String(snap.data().lastNotifiedTag || "") : "";
    if (prevTag === release.tagName) {
      return false;
    }
    tx.set(
      stateRef,
      {
        lastNotifiedTag: release.tagName,
        version: release.version,
        downloadUrl: release.downloadUrl,
        htmlUrl: release.htmlUrl,
        notifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    return true;
  });

  if (!isNew) {
    return { notified: false, reason: "already-notified", tag: release.tagName };
  }

  const summary = parseReleaseSummary(release.notes);
  const title = `NagarSathi v${release.version} is available`;
  const body = summary
    ? `${summary} — Tap to update NagarSathi.`
    : "A new GitHub release is ready. Tap to update NagarSathi.";

  const messageId = await admin.messaging().send({
    topic: RELEASE_TOPIC,
    notification: {
      title,
      body,
    },
    data: {
      type: "github_release",
      tag: release.tagName,
      version: release.version,
      notes: summary,
      downloadUrl: release.downloadUrl,
      htmlUrl: release.htmlUrl,
    },
    android: {
      priority: "high",
      notification: {
        channelId: RELEASE_CHANNEL_ID,
        clickAction: "FLUTTER_NOTIFICATION_CLICK",
      },
    },
  });

  return { notified: true, tag: release.tagName, messageId };
}

function verifyWebhookSignature(rawBody, signatureHeader, secret) {
  if (!secret) return true;
  if (!signatureHeader || !rawBody) return false;
  const expected =
    "sha256=" + crypto.createHmac("sha256", secret).update(rawBody).digest("hex");
  const a = Buffer.from(String(signatureHeader));
  const b = Buffer.from(expected);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

// Polls GitHub Releases periodically so newly published APK releases notify all
// app_updates subscribers even without a manual GitHub webhook trigger.
exports.checkGithubReleaseAndNotify = onSchedule("every 15 minutes", async () => {
  const release = await fetchLatestApkRelease();
  await broadcastReleaseIfNew(release);
});

// HTTPS webhook that .github/workflows/release-notify.yml calls when a GitHub
// Release is published for instant push notification delivery.
exports.githubReleaseWebhook = onRequest(async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  const secret = process.env.GITHUB_RELEASE_WEBHOOK_SECRET || "";
  const sig = req.get("X-Hub-Signature-256");
  if (!verifyWebhookSignature(req.rawBody, sig, secret)) {
    res.status(401).json({ error: "Invalid signature" });
    return;
  }

  try {
    const release = await fetchLatestApkRelease();
    const result = await broadcastReleaseIfNew(release);
    res.status(200).json(result);
  } catch (error) {
    res.status(500).json({ error: String(error?.message || error) });
  }
});

function emailKey(email) {
  return crypto.createHash("sha256").update(email.trim().toLowerCase()).digest("hex");
}

async function collectUserDocs(queries) {
  const byId = new Map();
  const snapshots = await Promise.all(
    queries.map((q) => q.get().catch(() => null)),
  );
  for (const snap of snapshots) {
    if (!snap) continue;
    for (const doc of snap.docs) {
      if (!byId.has(doc.id)) {
        byId.set(doc.id, { id: doc.id, ...normalizeFirestoreData(doc.data()) });
      }
    }
  }
  return Array.from(byId.values());
}

exports.requestDataExport = onCall(
  { secrets: [gmailUser, gmailAppPassword, otpPepper] },
  async (request) => {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError("unauthenticated", "Sign in to request your data export.");
    }

    const uid = request.auth.uid;
    const authUser = await admin.auth().getUser(uid);
    const [userSnap, staffSnap] = await Promise.all([
      db.collection("users").doc(uid).get().catch(() => null),
      db.collection("staff").doc(uid).get().catch(() => null),
    ]);

    const userData = userSnap?.exists ? normalizeFirestoreData(userSnap.data()) : {};
    const staffData = staffSnap?.exists ? normalizeFirestoreData(staffSnap.data()) : {};
    const recipientEmail = String(
      authUser.email || userData.email || staffData.email || "",
    ).trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(recipientEmail)) {
      throw new HttpsError(
        "failed-precondition",
        "A registered email address is required to receive your export.",
      );
    }

    const [reports, comments] = await Promise.all([
      collectUserDocs([
        db.collection("reports").where("userId", "==", uid),
        db.collection("reports").where("authorId", "==", uid),
        db.collection("reports").where("reporterId", "==", uid),
        db.collection("users").doc(uid).collection("reports"),
      ]),
      collectUserDocs([
        db.collection("comments").where("userId", "==", uid),
        db.collection("comments").where("authorId", "==", uid),
        db.collection("users").doc(uid).collection("comments"),
      ]),
    ]);

    const profile = {
      uid,
      name: userData.name || staffData.name || authUser.displayName || null,
      email: recipientEmail,
      emailVerified: Boolean(authUser.emailVerified),
      phone: userData.phone || staffData.phone || authUser.phoneNumber || null,
      role: userData.role || staffData.role || "citizen",
      preferredLanguage: userData.preferredLanguage || null,
      location: userData.location || null,
      createdAt: userData.createdAt || authUser.metadata?.creationTime || null,
      updatedAt: userData.updatedAt || null,
    };

    const exportId = crypto.randomUUID();
    const requestedAt = Date.now();
    const expiresAt = requestedAt + EXPORT_EXPIRY_MS;

    const exportDoc = buildExportDocument({
      exportId,
      profile,
      reports,
      comments,
      requestedAt,
      expiresAt,
    });
    const jsonString = JSON.stringify(exportDoc, null, 2);
    const pdfBuffer = buildExportPdf({
      exportId,
      profile,
      reports,
      comments,
      requestedAt,
      expiresAt,
    });

    const envelope = Buffer.from(
      JSON.stringify({ json: jsonString, pdfBase64: pdfBuffer.toString("base64") }),
      "utf8",
    );
    const encrypted = encryptExportBundle(otpPepper.value(), exportId, envelope);
    const emailHash = emailKey(recipientEmail);

    await db.collection("dataExportPackages").doc(exportId).set({
      exportId,
      userId: uid,
      emailHash,
      recipientEmail,
      status: "ready",
      encryptedPayload: encrypted.ciphertextBase64,
      payloadIv: encrypted.ivBase64,
      reportCount: reports.length,
      commentCount: comments.length,
      createdAt: requestedAt,
      expiresAt,
    });

    const token = encryptDownloadToken(otpPepper.value(), {
      exportId,
      userId: uid,
      emailHash,
      expiresAt,
    });
    const projectId = process.env.GCLOUD_PROJECT || "nagar-sathi-23080";
    const downloadUrl = `https://us-central1-${projectId}.cloudfunctions.net/downloadDataExport?token=${encodeURIComponent(token)}`;
    const isNepali = String(request.data?.locale || "").toLowerCase() === "ne";
    const expiryIso = new Date(expiresAt).toISOString();

    await mailer(gmailUser.value(), gmailAppPassword.value()).sendMail({
      from: `NagarSathi <${gmailUser.value()}>`,
      to: recipientEmail,
      subject: isNepali
        ? "तपाईंको नगरसाथी व्यक्तिगत डाटा निर्यात तयार छ"
        : "Your NagarSathi personal data export is ready",
      text: isNepali
        ? `तपाईंको नगरसाथी निर्यात प्याकेज (JSON र PDF) तयार छ:\n${downloadUrl}\n\nयो इन्क्रिप्ट गरिएको लिङ्क ४८ घण्टापछि (${expiryIso}) स्वतः निष्क्रिय हुनेछ।`
        : `Your NagarSathi export package (JSON & PDF) is ready:\n${downloadUrl}\n\nThis encrypted link expires in 48 hours (${expiryIso}).`,
      html: isNepali
        ? `<p>तपाईंको नगरसाथी निर्यात प्याकेज (<strong>JSON</strong> र <strong>PDF</strong>) तयार छ।</p><p><a href="${downloadUrl}">इन्क्रिप्ट गरिएको डाटा प्याकेज डाउनलोड गर्नुहोस्</a></p><p>यो लिङ्क <strong>४८ घण्टा</strong>पछि (${expiryIso}) स्वतः निष्क्रिय हुनेछ।</p>`
        : `<p>Your NagarSathi export package (<strong>JSON</strong> &amp; <strong>PDF</strong>) is ready.</p><p><a href="${downloadUrl}">Download My Encrypted Data Package</a></p><p>This link expires automatically after <strong>48 hours</strong> (${expiryIso}).</p>`,
    });

    const deliveredAt = Date.now();
    await db.collection("dataExportPackages").doc(exportId).update({
      status: "sent",
      deliveredAt,
    });

    return {
      exportId,
      status: "sent",
      email: recipientEmail,
      formats: ["json", "pdf"],
      reportCount: reports.length,
      commentCount: comments.length,
      requestedAt,
      expiresAt,
      deliveredAt,
      expiresInSeconds: EXPORT_EXPIRY_MS / 1000,
      deliverySlaMinutes: DELIVERY_SLA_MINUTES,
    };
  },
);

exports.downloadDataExport = onRequest(
  { secrets: [otpPepper] },
  async (req, res) => {
    const token = String(req.query.token || "").trim();
    const format = String(req.query.format || "zip").toLowerCase();
    if (!token) {
      res.status(400).json({ error: "Missing export download token." });
      return;
    }

    const tokenPayload = decryptDownloadToken(otpPepper.value(), token);
    if (!tokenPayload || !tokenPayload.exportId || !tokenPayload.userId) {
      res.status(403).json({ error: "This download link is invalid." });
      return;
    }

    const now = Date.now();
    const docRef = db.collection("dataExportPackages").doc(tokenPayload.exportId);
    if (Number(tokenPayload.expiresAt || 0) <= now) {
      await docRef.delete().catch(() => {});
      res.status(410).json({ error: "This export download link has expired after 48 hours." });
      return;
    }

    const snap = await docRef.get();
    if (!snap.exists) {
      res.status(410).json({ error: "This export is no longer available or has expired." });
      return;
    }

    const row = snap.data();
    if (Number(row.expiresAt || 0) <= now) {
      await docRef.delete().catch(() => {});
      res.status(410).json({ error: "This export download link has expired after 48 hours." });
      return;
    }

    if (row.userId !== tokenPayload.userId || row.emailHash !== tokenPayload.emailHash) {
      res.status(403).json({ error: "This download link is invalid." });
      return;
    }

    let envelope;
    try {
      const decrypted = decryptExportBundle(
        otpPepper.value(),
        row.exportId,
        row.payloadIv,
        row.encryptedPayload,
      );
      envelope = JSON.parse(decrypted.toString("utf8"));
    } catch {
      res.status(500).json({ error: "Could not decrypt export package." });
      return;
    }
    const shortId = String(row.exportId).slice(0, 8);

    res.setHeader("Cache-Control", "no-store, no-cache, must-revalidate, private");
    res.setHeader("X-Content-Type-Options", "nosniff");

    if (format === "json") {
      res.setHeader("Content-Type", "application/json; charset=utf-8");
      res.setHeader("Content-Disposition", `attachment; filename="nagarsathi-data-export-${shortId}.json"`);
      res.status(200).send(envelope.json);
      return;
    }

    const pdfBuf = Buffer.from(envelope.pdfBase64, "base64");
    if (format === "pdf") {
      res.setHeader("Content-Type", "application/pdf");
      res.setHeader("Content-Disposition", `attachment; filename="nagarsathi-data-export-${shortId}.pdf"`);
      res.status(200).send(pdfBuf);
      return;
    }

    const zipBuf = buildZipArchive([
      {
        name: "README.txt",
        data: Buffer.from(`NagarSathi Personal Data Export\nExport ID: ${row.exportId}\nExpires At: ${new Date(row.expiresAt).toISOString()}\n`, "utf8"),
      },
      { name: "nagarsathi-data-export.json", data: Buffer.from(envelope.json, "utf8") },
      { name: "nagarsathi-data-export.pdf", data: pdfBuf },
    ]);
    res.setHeader("Content-Type", "application/zip");
    res.setHeader("Content-Disposition", `attachment; filename="nagarsathi-data-export-${shortId}.zip"`);
    res.status(200).send(zipBuf);
  },
);

exports.cleanupExpiredDataExports = onSchedule("every 6 hours", async () => {
  const now = Date.now();
  const expired = await db
    .collection("dataExportPackages")
    .where("expiresAt", "<=", now)
    .limit(200)
    .get();
  if (expired.empty) return;
  const batch = db.batch();
  for (const doc of expired.docs) {
    batch.delete(doc.ref);
  }
  await batch.commit();
});
