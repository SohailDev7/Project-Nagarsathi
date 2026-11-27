const FIREBASE_PROJECT_ID = "nagar-sathi-23080";
const JWK_URL =
  "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...corsHeaders,
    },
  });
}

function isValidEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function decodeBase64Url(input) {
  const normalized = input.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized + "=".repeat((4 - (normalized.length % 4)) % 4);
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

function decodeJwtPart(part) {
  return JSON.parse(new TextDecoder().decode(decodeBase64Url(part)));
}

async function verifyFirebaseIdToken(token) {
  const parts = String(token || "").split(".");
  if (parts.length !== 3) {
    throw new Error("Malformed token");
  }

  const header = decodeJwtPart(parts[0]);
  const payload = decodeJwtPart(parts[1]);
  const now = Math.floor(Date.now() / 1000);

  if (header.alg !== "RS256" || !header.kid) {
    throw new Error("Unsupported token algorithm");
  }
  if (payload.aud !== FIREBASE_PROJECT_ID) {
    throw new Error("Invalid token audience");
  }
  if (payload.iss !== `https://securetoken.google.com/${FIREBASE_PROJECT_ID}`) {
    throw new Error("Invalid token issuer");
  }
  if (typeof payload.exp !== "number" || payload.exp <= now) {
    throw new Error("Token expired");
  }
  if (typeof payload.sub !== "string" || payload.sub.length === 0) {
    throw new Error("Missing token subject");
  }

  const jwkResponse = await fetch(JWK_URL);
  if (!jwkResponse.ok) {
    throw new Error("Could not fetch Firebase public keys");
  }
  const { keys } = await jwkResponse.json();
  const jwk = Array.isArray(keys) ? keys.find((k) => k.kid === header.kid) : null;
  if (!jwk) {
    throw new Error("Signing key not found");
  }

  const cryptoKey = await crypto.subtle.importKey(
    "jwk",
    jwk,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"]
  );

  const signingInput = new TextEncoder().encode(`${parts[0]}.${parts[1]}`);
  const signature = decodeBase64Url(parts[2]);
  const valid = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    signature,
    signingInput
  );
  if (!valid) {
    throw new Error("Invalid token signature");
  }

  return payload.sub;
}

async function assertStaffManager(uid, idToken) {
  const url = `https://firestore.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/databases/(default)/documents/staff/${encodeURIComponent(
    uid
  )}`;
  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${idToken}` },
  });
  if (!res.ok) {
    return false;
  }
  const doc = await res.json().catch(() => null);
  const fields = doc?.fields;
  if (!fields) return false;

  const role = fields.role?.stringValue;
  const active = fields.active?.booleanValue === true;
  const isAdmin = fields.admin?.booleanValue === true;
  const accountType = fields.accountType?.stringValue;

  return (
    active &&
    (role === "staff" || role === "admin") &&
    (isAdmin || accountType === "ward_creator")
  );
}

function encodeBase64Url(bytes) {
  let binary = "";
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToArrayBuffer(pem) {
  const clean = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  const binary = atob(clean);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

async function getGoogleAccessToken(serviceAccount) {
  const now = Math.floor(Date.now() / 1000);
  const header = encodeBase64Url(
    new TextEncoder().encode(JSON.stringify({ alg: "RS256", typ: "JWT" }))
  );
  const claim = encodeBase64Url(
    new TextEncoder().encode(
      JSON.stringify({
        iss: serviceAccount.client_email,
        scope: "https://www.googleapis.com/auth/identitytoolkit",
        aud: "https://oauth2.googleapis.com/token",
        iat: now,
        exp: now + 3600,
      })
    )
  );
  const unsigned = `${header}.${claim}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(serviceAccount.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned)
  );
  const assertion = `${unsigned}.${encodeBase64Url(new Uint8Array(sig))}`;

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const tokenJson = await tokenRes.json().catch(() => null);
  if (!tokenRes.ok || !tokenJson?.access_token) {
    throw new Error(tokenJson?.error_description || "Failed to get Google access token");
  }
  return tokenJson.access_token;
}

async function requireStaffManager(request) {
  const authHeader = request.headers.get("Authorization") || "";
  const idToken = authHeader.startsWith("Bearer ")
    ? authHeader.slice(7).trim()
    : "";
  if (!idToken) {
    return { error: json({ error: "Missing authorization token." }, 401) };
  }

  let uid;
  try {
    uid = await verifyFirebaseIdToken(idToken);
  } catch (err) {
    return { error: json({ error: `Unauthorized: ${err.message}` }, 401) };
  }

  const allowed = await assertStaffManager(uid, idToken);
  if (!allowed) {
    return { error: json({ error: "Forbidden: staff manager access required." }, 403) };
  }
  return { uid };
}

async function handleSendOfficerEmail(request, env) {
  const mailEndpoint = String(env.GMAIL_MAIL_ENDPOINT || "").trim();
  const mailSecret = String(env.GMAIL_MAIL_SECRET || "").trim();
  if (!mailEndpoint || !mailSecret) {
    return json({ error: "Mail service is not configured on worker." }, 500);
  }

  const auth = await requireStaffManager(request);
  if (auth.error) return auth.error;

  let body;
  try {
    body = await request.json();
  } catch {
    return json({ error: "Invalid JSON body." }, 400);
  }

  const to = String(body?.to || "").trim();
  const subject = String(body?.subject || "").trim();
  const text = String(body?.text || "").trim();
  const html = typeof body?.html === "string" ? body.html : undefined;

  if (!isValidEmail(to) || !subject || !text) {
    return json({ error: "Fields 'to', 'subject', and 'text' are required." }, 400);
  }

  const mailResponse = await fetch(mailEndpoint, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      apiKey: mailSecret,
      to,
      subject,
      text,
      html,
    }),
  });

  if (!mailResponse.ok) {
    const detail = await mailResponse.text().catch(() => "");
    return json({ error: "Failed to reach Gmail endpoint.", detail }, 502);
  }

  const mailPayload = await mailResponse.json().catch(() => null);
  if (!mailPayload || mailPayload.sent !== true) {
    return json(
      { error: mailPayload?.error || "Gmail endpoint did not confirm delivery." },
      502
    );
  }

  return json({ sent: true });
}

async function handleDeleteOfficerAuth(request, env) {
  const rawAccount = String(env.FIREBASE_SERVICE_ACCOUNT || "").trim();
  if (!rawAccount) {
    return json({ error: "FIREBASE_SERVICE_ACCOUNT is not configured." }, 500);
  }

  const auth = await requireStaffManager(request);
  if (auth.error) return auth.error;

  let body;
  try {
    body = await request.json();
  } catch {
    return json({ error: "Invalid JSON body." }, 400);
  }

  const email = String(body?.email || "").trim().toLowerCase();
  const uid = String(body?.uid || "").trim();
  if (!email && !uid) {
    return json({ error: "Field 'email' or 'uid' is required." }, 400);
  }

  const serviceAccount = JSON.parse(rawAccount);
  const projectId = serviceAccount.project_id || FIREBASE_PROJECT_ID;
  const accessToken = await getGoogleAccessToken(serviceAccount);

  let targetUid = uid && !uid.startsWith("officer_") ? uid : "";
  if (!targetUid && isValidEmail(email)) {
    const lookupRes = await fetch(
      `https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts:lookup`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({ email: [email] }),
      }
    );
    const lookupJson = await lookupRes.json().catch(() => null);
    targetUid = lookupJson?.users?.[0]?.localId || "";
  }

  if (!targetUid) {
    return json({ deleted: false, reason: "user-not-found" });
  }

  const delRes = await fetch(
    `https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts:delete`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({ localId: targetUid }),
    }
  );
  if (!delRes.ok) {
    const detail = await delRes.text().catch(() => "");
    return json({ error: "Failed to delete Firebase Auth user.", detail }, 502);
  }

  return json({ deleted: true, uid: targetUid });
}

export default {
  async fetch(request, env) {
    try {
      if (request.method === "OPTIONS") {
        return new Response(null, { status: 204, headers: corsHeaders });
      }
      if (request.method !== "POST") {
        return json({ error: "Method not allowed." }, 405);
      }

      const url = new URL(request.url);
      if (url.pathname === "/send-officer-email") {
        return await handleSendOfficerEmail(request, env);
      }
      if (url.pathname === "/delete-officer-auth") {
        return await handleDeleteOfficerAuth(request, env);
      }
      return json({ error: "Not found." }, 404);
    } catch (err) {
      return json({ error: err?.message || String(err) }, 500);
    }
  },
};
