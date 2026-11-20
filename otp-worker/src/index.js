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

  const mailResponse = await fetch(env.GMAIL_MAIL_ENDPOINT, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      apiKey: env.GMAIL_MAIL_SECRET,
      to: email,
      subject: "Your NagarSathi verification code",
      text:
        `Your NagarSathi verification code is ${otp}. It expires in 5 minutes.`,
      html: `
        <p>Your NagarSathi verification code is:</p>
        <h2>${otp}</h2>
        <p>This code expires in 5 minutes.</p>
      `,
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

  return json({
    verified: true,
    verificationToken: `${base64UrlEncode(payload)}.${signature}`,
  });
}

export default {
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
