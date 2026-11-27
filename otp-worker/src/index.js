const OTP_TTL_MS = 5 * 60 * 1000;
const RESEND_WINDOW_MS = 60 * 60 * 1000;
const MAX_RESENDS = 6;
const MAX_ATTEMPTS = 6;

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "Content-Type",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
    },
  });
}

function isValidEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function base64UrlEncode(value) {
  const bytes = new TextEncoder().encode(value);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary)
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}

async function sha256(value) {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

async function hmacSha256(secret, value) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(signature))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

async function parseJson(request) {
  try {
    return await request.json();
  } catch {
    return null;
  }
}

// ─── Firebase custom tokens ───────────────────────────────────────────────
//
// A verified code alone cannot start a Firebase session. After the code checks
// out we mint a Firebase custom token, which the app exchanges with
// `signInWithCustomToken` to become a real signed-in user.
//
// This needs a service account: Firebase console → Project settings →
// Service accounts → Generate new private key, then store the JSON as the
// FIREBASE_SERVICE_ACCOUNT secret (`wrangler secret put FIREBASE_SERVICE_ACCOUNT`).
// Without it the worker still verifies codes, it just cannot sign anyone in.

const IDENTITY_TOOLKIT_AUDIENCE =
  "https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit";
const GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token";
const GOOGLE_SCOPE =
  "https://www.googleapis.com/auth/identitytoolkit https://www.googleapis.com/auth/cloud-platform";

let serviceAccountCache = null;
let privateKeyCache = null;
let accessTokenCache = null;
let accessTokenExpiry = 0;

function base64UrlEncodeBytes(bytes) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary)
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}

function readServiceAccount(env) {
  if (serviceAccountCache) return serviceAccountCache;

  let account = null;
  if (env.FIREBASE_SERVICE_ACCOUNT) {
    try {
      account = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT);
    } catch {
      account = null;
    }
  } else if (env.FIREBASE_CLIENT_EMAIL && env.FIREBASE_PRIVATE_KEY) {
    account = {
      client_email: env.FIREBASE_CLIENT_EMAIL,
      private_key: env.FIREBASE_PRIVATE_KEY,
      project_id: env.FIREBASE_PROJECT_ID,
    };
  }

  if (!account || !account.client_email || !account.private_key) return null;
  if (!account.project_id && env.FIREBASE_PROJECT_ID) {
    account.project_id = env.FIREBASE_PROJECT_ID;
  }

  serviceAccountCache = account;
  return account;
}

async function loadPrivateKey(pem) {
  if (privateKeyCache) return privateKeyCache;

  // Secrets pasted through the dashboard often keep literal "\n" escapes.
  const normalized = String(pem).replaceAll("\\n", "\n");
  const body = normalized
    .replace(/-----BEGIN [^-]+-----/g, "")
    .replace(/-----END [^-]+-----/g, "")
    .replace(/\s+/g, "");

  const binary = atob(body);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }

  privateKeyCache = await crypto.subtle.importKey(
    "pkcs8",
    bytes,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return privateKeyCache;
}

async function signServiceJwt(account, claims) {
  const header = base64UrlEncode(
    JSON.stringify({ alg: "RS256", typ: "JWT" }),
  );
  const payload = base64UrlEncode(JSON.stringify(claims));
  const unsigned = `${header}.${payload}`;
  const key = await loadPrivateKey(account.private_key);
  const signature = await crypto.subtle.sign(
    { name: "RSASSA-PKCS1-v1_5" },
    key,
    new TextEncoder().encode(unsigned),
  );
  return `${unsigned}.${base64UrlEncodeBytes(new Uint8Array(signature))}`;
}

async function getGoogleAccessToken(env) {
  const now = Math.floor(Date.now() / 1000);
  if (accessTokenCache && accessTokenExpiry > now + 60) {
    return accessTokenCache;
  }

  const account = readServiceAccount(env);
  if (!account) return null;

  const assertion = await signServiceJwt(account, {
    iss: account.client_email,
    scope: GOOGLE_SCOPE,
    aud: GOOGLE_TOKEN_URL,
    iat: now,
    exp: now + 3600,
  });

  const response = await fetch(GOOGLE_TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!response.ok) return null;

  const payload = await response.json().catch(() => null);
  if (!payload || !payload.access_token) return null;

  accessTokenCache = payload.access_token;
  accessTokenExpiry = now + Number(payload.expires_in || 3600);
  return accessTokenCache;
}

/// Returns the Firebase Auth uid that already owns [email], or `null`.
///
/// Deliberately never creates accounts: sign-up verification runs through the
/// same endpoint and then calls `createUserWithEmailAndPassword`, so creating a
/// passwordless user here would make sign-up fail with `email-already-in-use`.
async function findFirebaseUser(env, accessToken, email) {
  const account = readServiceAccount(env);
  if (!account || !account.project_id) return null;

  const lookup = await fetch(
    `https://identitytoolkit.googleapis.com/v1/projects/${account.project_id}/accounts:lookup`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({ email: [email] }),
    },
  );
  if (!lookup.ok) return null;

  const payload = await lookup.json().catch(() => null);
  const user = Array.isArray(payload?.users) ? payload.users[0] : null;
  return user?.localId || null;
}

async function createFirebaseCustomToken(env, uid) {
  const account = readServiceAccount(env);
  if (!account) return null;

  const now = Math.floor(Date.now() / 1000);
  return signServiceJwt(account, {
    iss: account.client_email,
    sub: account.client_email,
    aud: IDENTITY_TOOLKIT_AUDIENCE,
    iat: now,
    exp: now + 3600,
    uid,
  });
}

async function mintFirebaseToken(env, email) {
  try {
    const accessToken = await getGoogleAccessToken(env);
    if (!accessToken) return { token: null, reason: "not-configured" };

    const uid = await findFirebaseUser(env, accessToken, email);
    if (!uid) return { token: null, reason: "user-not-found" };

    const token = await createFirebaseCustomToken(env, uid);
    return { token, reason: token ? null : "not-configured" };
  } catch {
    return { token: null, reason: "error" };
  }
}

async function requestOtp(request, env) {
  if (!env.GMAIL_MAIL_ENDPOINT || !env.GMAIL_MAIL_SECRET || !env.OTP_PEPPER) {
    return json({ error: "OTP email service is not configured." }, 500);
  }

  const body = await parseJson(request);
  const email = String(body?.email || "").trim().toLowerCase();
  if (!isValidEmail(email)) {
    return json({ error: "Enter a valid email address." }, 400);
  }

  const now = Date.now();
  const emailHash = await sha256(`${env.OTP_PEPPER}:${email}`);
  const row = await env.DB
    .prepare("SELECT * FROM otp_challenges WHERE email_hash = ?")
    .bind(emailHash)
    .first();

  let resendCount = 0;
  let windowStart = now;
  if (row) {
    const windowActive =
      Number(row.resend_window_start) + RESEND_WINDOW_MS > now;
    resendCount = windowActive ? Number(row.resend_count) : 0;
    windowStart = windowActive ? Number(row.resend_window_start) : now;
  }

  if (resendCount >= MAX_RESENDS) {
    return json(
      { error: "Too many OTP requests. Try again later." },
      429,
    );
  }

  const otp = String(crypto.getRandomValues(new Uint32Array(1))[0] % 900000 + 100000);
  const otpHash = await sha256(`${env.OTP_PEPPER}:${email}:${otp}`);

  await env.DB
    .prepare(`
      INSERT INTO otp_challenges (
        email_hash, email, otp_hash, expires_at,
        resend_window_start, resend_count, attempts,
        verified, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, 0, 0, ?)
      ON CONFLICT(email_hash) DO UPDATE SET
        email = excluded.email,
        otp_hash = excluded.otp_hash,
        expires_at = excluded.expires_at,
        resend_window_start = excluded.resend_window_start,
        resend_count = excluded.resend_count,
        attempts = 0,
        verified = 0,
        updated_at = excluded.updated_at
    `)
    .bind(
      emailHash,
      email,
      otpHash,
      now + OTP_TTL_MS,
      windowStart,
      resendCount + 1,
      now,
    )
    .run();

  const isNepali = String(body?.locale || "").toLowerCase() === "ne";
  const emailSubject = isNepali
    ? "तपाईंको नगरसाथी प्रमाणीकरण कोड"
    : "Your NagarSathi verification code";
  const emailText = isNepali
    ? `तपाईंको नगरसाथी प्रमाणीकरण कोड ${otp} हो। यो ५ मिनेटमा निष्क्रिय हुनेछ।`
    : `Your NagarSathi verification code is ${otp}. It expires in 5 minutes.`;
  const emailHtml = isNepali
    ? `<p>तपाईंको नगरसाथी प्रमाणीकरण कोड:</p><h2>${otp}</h2><p>यो कोड ५ मिनेटमा निष्क्रिय हुनेछ।</p>`
    : `<p>Your NagarSathi verification code is:</p><h2>${otp}</h2><p>This code expires in 5 minutes.</p>`;

  const mailResponse = await fetch(env.GMAIL_MAIL_ENDPOINT, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      apiKey: env.GMAIL_MAIL_SECRET,
      to: email,
      subject: emailSubject,
      text: emailText,
      html: emailHtml,
    }),
  });

  if (!mailResponse.ok) {
    const detail = await mailResponse.text();
    return json({
      error: "The verification email could not be sent.",
      detail,
    }, 502);
  }

  const mailPayload = await mailResponse.json().catch(() => null);
  if (!mailPayload || mailPayload.sent !== true) {
    return json({
      error: mailPayload?.error || "The verification email could not be sent.",
    }, 502);
  }

  return json({
    expiresInSeconds: OTP_TTL_MS / 1000,
    remainingResends: MAX_RESENDS - resendCount - 1,
  });
}

async function verifyOtp(request, env) {
  if (!env.OTP_PEPPER) {
    return json({ error: "OTP service is not configured." }, 500);
  }

  const body = await parseJson(request);
  const email = String(body?.email || "").trim().toLowerCase();
  const otp = String(body?.otp || "").trim();

  if (!isValidEmail(email) || !/^\d{6}$/.test(otp)) {
    return json({ error: "Enter a valid email and 6-digit code." }, 400);
  }

  const now = Date.now();
  const emailHash = await sha256(`${env.OTP_PEPPER}:${email}`);
  const row = await env.DB
    .prepare("SELECT * FROM otp_challenges WHERE email_hash = ?")
    .bind(emailHash)
    .first();

  if (!row) {
    return json({ error: "Request a new verification code." }, 404);
  }
  if (Number(row.expires_at) <= now) {
    return json({ error: "That code has expired." }, 410);
  }
  if (Number(row.attempts) >= MAX_ATTEMPTS) {
    return json(
      { error: "Too many attempts. Request a new code." },
      429,
    );
  }

  const otpHash = await sha256(`${env.OTP_PEPPER}:${email}:${otp}`);
  if (row.otp_hash !== otpHash) {
    await env.DB
      .prepare(
        "UPDATE otp_challenges SET attempts = attempts + 1, updated_at = ? WHERE email_hash = ?",
      )
      .bind(now, emailHash)
      .run();
    return json({ error: "That code is incorrect." }, 401);
  }

  await env.DB
    .prepare(
      "UPDATE otp_challenges SET verified = 1, updated_at = ? WHERE email_hash = ?",
    )
    .bind(now, emailHash)
    .run();

  const payload = JSON.stringify({
    email,
    verified: true,
    expiresAt: now + 10 * 60 * 1000,
  });
  const signature = await hmacSha256(
    env.OTP_PEPPER,
    payload,
  );

  // Best effort: when no service account is configured the code still verifies,
  // the app just cannot open a session from it. Accounts are never created here.
  const minted = await mintFirebaseToken(env, email);

  return json({
    verified: true,
    token: minted.token,
    tokenReason: minted.reason,
    verificationToken: `${base64UrlEncode(payload)}.${signature}`,
  });
}

export default {
  async scheduled(_event, env) {
    // Expired challenges contain email addresses; do not retain them after
    // their short verification window, including for deleted accounts.
    await env.DB.prepare("DELETE FROM otp_challenges WHERE expires_at <= ?")
      .bind(Date.now()).run();
  },

  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return json({});
    }
    if (request.method !== "POST") {
      return json({ error: "Method not allowed." }, 405);
    }

    const url = new URL(request.url);
    if (url.pathname === "/request-email-otp") {
      return requestOtp(request, env);
    }
    if (url.pathname === "/verify-email-otp") {
      return verifyOtp(request, env);
    }
    return json({ error: "Not found." }, 404);
  },
};
