const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const crypto = require("crypto");
const nodemailer = require("nodemailer");

admin.initializeApp();
const db = admin.firestore();
const gmailUser = defineSecret("GMAIL_USER");
const gmailAppPassword = defineSecret("GMAIL_APP_PASSWORD");
const otpPepper = defineSecret("OTP_PEPPER");

const OTP_TTL_MS = 5 * 60 * 1000;
const RESEND_WINDOW_MS = 60 * 60 * 1000;
const MAX_RESENDS = 6;

function emailKey(email) {
  return crypto.createHash("sha256").update(email.trim().toLowerCase()).digest("hex");
}

function hashOtp(email, otp, pepper) {
  return crypto.createHash("sha256")
    .update(`${email.trim().toLowerCase()}:${otp}:${pepper}`)
    .digest("hex");
}

function assertEmail(value) {
  const email = String(value || "").trim().toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new HttpsError("invalid-argument", "Enter a valid email address.");
  }
  return email;
}

function mailer(user, password) {
  return nodemailer.createTransport({
    host: "smtp.gmail.com",
    port: 587,
    secure: false,
    auth: { user, pass: password },
  });
}

exports.requestEmailOtp = onCall(
  { secrets: [gmailUser, gmailAppPassword, otpPepper] },
  async (request) => {
    const email = assertEmail(request.data?.email);
    const ref = db.collection("otpChallenges").doc(emailKey(email));
    const now = Date.now();
    const otp = crypto.randomInt(100000, 1000000).toString();

    const state = await db.runTransaction(async (tx) => {
      const snapshot = await tx.get(ref);
      const previous = snapshot.exists ? snapshot.data() : {};
      const windowStart = Number(previous.windowStart || 0);
      const resendCount = windowStart + RESEND_WINDOW_MS <= now
        ? 0
        : Number(previous.resendCount || 0);
      if (resendCount >= MAX_RESENDS) {
        throw new HttpsError("resource-exhausted", "Too many OTP requests. Try again later.");
      }
      tx.set(ref, {
        email,
        otpHash: hashOtp(email, otp, otpPepper.value()),
        expiresAt: admin.firestore.Timestamp.fromMillis(now + OTP_TTL_MS),
        windowStart: windowStart + RESEND_WINDOW_MS <= now ? now : windowStart,
        resendCount: resendCount + 1,
        attempts: 0,
        verified: false,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return resendCount + 1;
    });

    const isNepali = String(request.data?.locale || "").toLowerCase() === "ne";
    const subject = isNepali
      ? "तपाईंको नगरसाथी प्रमाणीकरण कोड"
      : "Your NagarSathi verification code";
    const text = isNepali
      ? `तपाईंको नगरसाथी प्रमाणीकरण कोड ${otp} हो। यो ५ मिनेटमा निष्क्रिय हुनेछ।`
      : `Your NagarSathi verification code is ${otp}. It expires in 5 minutes.`;
    const html = isNepali
      ? `<p>तपाईंको नगरसाथी प्रमाणीकरण कोड:</p><h2>${otp}</h2><p>यो कोड ५ मिनेटमा निष्क्रिय हुनेछ।</p>`
      : `<p>Your NagarSathi verification code is:</p><h2>${otp}</h2><p>This code expires in 5 minutes.</p>`;

    await mailer(gmailUser.value(), gmailAppPassword.value()).sendMail({
      from: `NagarSathi <${gmailUser.value()}>`,
      to: email,
      subject,
      text,
      html,
    });
    return { expiresInSeconds: OTP_TTL_MS / 1000, remainingThisHour: MAX_RESENDS - state };
  },
);

exports.verifyEmailOtp = onCall(
  { secrets: [otpPepper] },
  async (request) => {
    const email = assertEmail(request.data?.email);
    const otp = String(request.data?.otp || "").trim();
    if (!/^\d{6}$/.test(otp)) {
      throw new HttpsError("invalid-argument", "Enter the 6-digit code.");
    }
    const ref = db.collection("otpChallenges").doc(emailKey(email));
    const snapshot = await ref.get();
    if (!snapshot.exists) throw new HttpsError("not-found", "Request a new code.");
    const data = snapshot.data();
    if (data.expiresAt.toMillis() <= Date.now()) {
      throw new HttpsError("deadline-exceeded", "That code has expired. Request a new one.");
    }
    if (Number(data.attempts || 0) >= 6) {
      throw new HttpsError("resource-exhausted", "Too many incorrect codes. Request a new one.");
    }
    if (data.otpHash !== hashOtp(email, otp, otpPepper.value())) {
      await ref.update({ attempts: admin.firestore.FieldValue.increment(1) });
      throw new HttpsError("unauthenticated", "That code is incorrect.");
    }
    await ref.update({ verified: true, verifiedAt: admin.firestore.FieldValue.serverTimestamp() });
    let token = null;
    try {
      const user = await admin.auth().getUserByEmail(email);
      token = await admin.auth().createCustomToken(user.uid);
    } catch (_) {
      // User might be creating account, so custom token is best-effort.
    }
    return { verified: true, token };
  },
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
