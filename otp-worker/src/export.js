export const EXPORT_EXPIRY_MS = 48 * 60 * 60 * 1000;
export const DELIVERY_SLA_MINUTES = 15;
export const EXPORT_RATE_WINDOW_MS = 60 * 60 * 1000;
export const MAX_EXPORTS_PER_HOUR = 5;

const textEncoder = new TextEncoder();
const textDecoder = new TextDecoder();

export function base64UrlEncodeBytes(bytes) {
  let binary = "";
  for (let i = 0; i < bytes.length; i += 1) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary)
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}

export function base64UrlDecodeBytes(value) {
  const normalized = String(value || "")
    .replaceAll("-", "+")
    .replaceAll("_", "/");
  const padding = normalized.length % 4 === 0 ? "" : "=".repeat(4 - (normalized.length % 4));
  const binary = atob(normalized + padding);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

export function base64EncodeBytes(bytes) {
  let binary = "";
  for (let i = 0; i < bytes.length; i += 1) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

export function base64DecodeBytes(value) {
  const binary = atob(String(value || ""));
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

async function deriveAesKey(secret, purpose) {
  if (!secret) {
    throw new Error("Encryption secret is not configured.");
  }
  const keyMaterial = await crypto.subtle.digest(
    "SHA-256",
    textEncoder.encode(`nagarsathi:${purpose}:v1:${secret}`),
  );
  return crypto.subtle.importKey(
    "raw",
    keyMaterial,
    { name: "AES-GCM" },
    false,
    ["encrypt", "decrypt"],
  );
}

/**
 * Encrypts and authenticates a download token using AES-256-GCM so export IDs
 * and user identities are never exposed or forgeable in email links.
 */
export async function encryptDownloadToken(secret, payload) {
  const key = await deriveAesKey(secret, "export-download-token");
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const plaintext = textEncoder.encode(JSON.stringify(payload));
  const ciphertext = new Uint8Array(
    await crypto.subtle.encrypt({ name: "AES-GCM", iv }, key, plaintext),
  );
  const combined = new Uint8Array(iv.length + ciphertext.length);
  combined.set(iv, 0);
  combined.set(ciphertext, iv.length);
  return base64UrlEncodeBytes(combined);
}

export async function decryptDownloadToken(secret, token) {
  try {
    const combined = base64UrlDecodeBytes(token);
    if (combined.length <= 12) return null;
    const iv = combined.slice(0, 12);
    const ciphertext = combined.slice(12);
    const key = await deriveAesKey(secret, "export-download-token");
    const plaintext = await crypto.subtle.decrypt(
      { name: "AES-GCM", iv },
      key,
      ciphertext,
    );
    return JSON.parse(textDecoder.decode(plaintext));
  } catch {
    return null;
  }
}

/**
 * Encrypts the stored export package at rest using AES-256-GCM bound to exportId.
 */
export async function encryptExportBundle(secret, exportId, plainBytes) {
  const key = await deriveAesKey(secret, "export-payload-at-rest");
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ciphertext = new Uint8Array(
    await crypto.subtle.encrypt(
      {
        name: "AES-GCM",
        iv,
        additionalData: textEncoder.encode(exportId),
      },
      key,
      plainBytes,
    ),
  );
  return {
    ivBase64: base64EncodeBytes(iv),
    ciphertextBase64: base64EncodeBytes(ciphertext),
  };
}

export async function decryptExportBundle(
  secret,
  exportId,
  ivBase64,
  ciphertextBase64,
) {
  const key = await deriveAesKey(secret, "export-payload-at-rest");
  const iv = base64DecodeBytes(ivBase64);
  const ciphertext = base64DecodeBytes(ciphertextBase64);
  const plaintext = await crypto.subtle.decrypt(
    {
      name: "AES-GCM",
      iv,
      additionalData: textEncoder.encode(exportId),
    },
    key,
    ciphertext,
  );
  return new Uint8Array(plaintext);
}

// ─── Firestore REST Value Decoding ───────────────────────────────────────────

export function decodeFirestoreValue(value) {
  if (!value || typeof value !== "object") return null;
  if ("nullValue" in value) return null;
  if ("stringValue" in value) return value.stringValue;
  if ("booleanValue" in value) return Boolean(value.booleanValue);
  if ("integerValue" in value) return Number(value.integerValue);
  if ("doubleValue" in value) return Number(value.doubleValue);
  if ("timestampValue" in value) return value.timestampValue;
  if ("geoPointValue" in value) {
    return {
      latitude: value.geoPointValue?.latitude ?? null,
      longitude: value.geoPointValue?.longitude ?? null,
    };
  }
  if ("referenceValue" in value) return value.referenceValue;
  if ("arrayValue" in value) {
    const values = Array.isArray(value.arrayValue?.values)
      ? value.arrayValue.values
      : [];
    return values.map(decodeFirestoreValue);
  }
  if ("mapValue" in value) {
    return decodeFirestoreFields(value.mapValue?.fields || {});
  }
  return null;
}

export function decodeFirestoreFields(fields) {
  const result = {};
  if (!fields || typeof fields !== "object") return result;
  for (const [key, val] of Object.entries(fields)) {
    result[key] = decodeFirestoreValue(val);
  }
  return result;
}

export function decodeFirestoreDocument(doc) {
  if (!doc || !doc.name) return null;
  const parts = String(doc.name).split("/");
  const id = parts[parts.length - 1];
  return {
    id,
    ...decodeFirestoreFields(doc.fields || {}),
    ...(doc.createTime ? { _createTime: doc.createTime } : {}),
    ...(doc.updateTime ? { _updateTime: doc.updateTime } : {}),
  };
}

async function fetchFirestoreDoc(projectId, accessToken, docPath) {
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${docPath}`;
  const response = await fetch(url, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (response.status === 404) return null;
  if (!response.ok) return null;
  const doc = await response.json().catch(() => null);
  return decodeFirestoreDocument(doc);
}

async function queryFirestoreCollection(
  projectId,
  accessToken,
  parentPath,
  collectionId,
  fieldName,
  uid,
  { allDescendants = false } = {},
) {
  const base = parentPath
    ? `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${parentPath}`
    : `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;
  const fromClause = allDescendants
    ? [{ collectionId, allDescendants: true }]
    : [{ collectionId }];
  const body = fieldName
    ? {
        structuredQuery: {
          from: fromClause,
          where: {
            fieldFilter: {
              field: { fieldPath: fieldName },
              op: "EQUAL",
              value: { stringValue: uid },
            },
          },
        },
      }
    : {
        structuredQuery: {
          from: fromClause,
        },
      };

  const response = await fetch(`${base}:runQuery`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${accessToken}`,
    },
    body: JSON.stringify(body),
  });
  if (!response.ok) return [];

  const rows = await response.json().catch(() => []);
  if (!Array.isArray(rows)) return [];
  const docs = [];
  for (const row of rows) {
    if (row && row.document) {
      const decoded = decodeFirestoreDocument(row.document);
      if (decoded) docs.push(decoded);
    }
  }
  return docs;
}

function deduplicateById(items) {
  const byId = new Map();
  for (const item of items) {
    if (!item || !item.id) continue;
    if (!byId.has(item.id)) {
      byId.set(item.id, item);
    }
  }
  return Array.from(byId.values());
}

/**
 * Fetches the authenticated user's profile, reports, and comments from Firestore.
 */
export async function fetchUserExportData(projectId, accessToken, authUser) {
  const uid = authUser.uid;
  const [citizenDoc, staffDoc] = await Promise.all([
    fetchFirestoreDoc(projectId, accessToken, `users/${uid}`),
    fetchFirestoreDoc(projectId, accessToken, `staff/${uid}`),
  ]);

  const [
    reportsByUserId,
    reportsByAuthorId,
    reportsByReporterId,
    userSubReports,
    commentsByUserId,
    commentsByAuthorId,
    nestedCommentsByUserId,
    nestedCommentsByAuthorId,
    userSubComments,
  ] = await Promise.all([
    queryFirestoreCollection(projectId, accessToken, "", "reports", "userId", uid),
    queryFirestoreCollection(projectId, accessToken, "", "reports", "authorId", uid),
    queryFirestoreCollection(projectId, accessToken, "", "reports", "reporterId", uid),
    queryFirestoreCollection(projectId, accessToken, `users/${uid}`, "reports", null, uid),
    queryFirestoreCollection(projectId, accessToken, "", "comments", "userId", uid),
    queryFirestoreCollection(projectId, accessToken, "", "comments", "authorId", uid),
    queryFirestoreCollection(projectId, accessToken, "", "comments", "userId", uid, {
      allDescendants: true,
    }),
    queryFirestoreCollection(projectId, accessToken, "", "comments", "authorId", uid, {
      allDescendants: true,
    }),
    queryFirestoreCollection(projectId, accessToken, `users/${uid}`, "comments", null, uid),
  ]);

  const reports = deduplicateById([
    ...reportsByUserId,
    ...reportsByAuthorId,
    ...reportsByReporterId,
    ...userSubReports,
  ]);
  const comments = deduplicateById([
    ...commentsByUserId,
    ...commentsByAuthorId,
    ...nestedCommentsByUserId,
    ...nestedCommentsByAuthorId,
    ...userSubComments,
  ]);

  const profile = {
    uid,
    name: citizenDoc?.name || staffDoc?.name || authUser.displayName || null,
    email: authUser.email || citizenDoc?.email || staffDoc?.email || null,
    emailVerified: Boolean(authUser.emailVerified),
    phone: citizenDoc?.phone || staffDoc?.phone || authUser.phoneNumber || null,
    role: citizenDoc?.role || staffDoc?.role || "citizen",
    preferredLanguage: citizenDoc?.preferredLanguage || null,
    authProvider: citizenDoc?.authProvider || null,
    location: citizenDoc?.location || null,
    ward: staffDoc?.ward ?? citizenDoc?.location?.ward ?? null,
    createdAt: citizenDoc?.createdAt || authUser.createdAt || null,
    updatedAt: citizenDoc?.updatedAt || null,
  };

  return { profile, reports, comments };
}

// ─── JSON & PDF Export Generators ────────────────────────────────────────────

export function buildExportDocument({
  exportId,
  profile,
  reports = [],
  comments = [],
  requestedAt,
  expiresAt,
}) {
  return {
    exportMetadata: {
      exportId,
      app: "NagarSathi",
      schemaVersion: "1.0",
      generatedAt: new Date(requestedAt).toISOString(),
      expiresAt: new Date(expiresAt).toISOString(),
      formats: ["json", "pdf"],
    },
    profile: profile || {},
    summary: {
      totalReports: reports.length,
      totalComments: comments.length,
    },
    reports,
    comments,
  };
}

export function buildExportJson(params) {
  const doc = buildExportDocument(params);
  return JSON.stringify(doc, null, 2);
}

function pdfSafeText(value) {
  if (value === null || value === undefined) return "—";
  const raw = typeof value === "string" ? value : JSON.stringify(value);
  // Replace non-printable / non-Latin-1 characters cleanly for Type1 Helvetica streams.
  return raw
    .replaceAll("\r\n", " ")
    .replaceAll("\n", " ")
    .replaceAll("\r", " ")
    .replace(/[^\x20-\x7E\xA0-\xFF]/g, "?")
    .replaceAll("\\", "\\\\")
    .replaceAll("(", "\\(")
    .replaceAll(")", "\\)");
}

function wrapText(text, maxChars = 84) {
  const clean = String(text ?? "").replaceAll("\r\n", "\n");
  const paragraphs = clean.split("\n");
  const lines = [];
  for (const para of paragraphs) {
    const trimmed = para.trim();
    if (!trimmed) {
      lines.push("");
      continue;
    }
    const words = trimmed.split(/\s+/);
    let current = "";
    const pushWord = (word) => {
      if (word.length <= maxChars) {
        current = word;
        return;
      }
      let rest = word;
      while (rest.length > maxChars) {
        lines.push(rest.slice(0, maxChars));
        rest = rest.slice(maxChars);
      }
      current = rest;
    };
    for (const word of words) {
      if (!current) {
        pushWord(word);
      } else if (current.length + 1 + word.length <= maxChars) {
        current += ` ${word}`;
      } else {
        lines.push(current);
        pushWord(word);
      }
    }
    if (current) lines.push(current);
  }
  return lines.length > 0 ? lines : [""];
}

/**
 * Generates a human-readable, multi-page PDF 1.4 document with profile,
 * reports, and comments using pure bytes (no native/external dependencies).
 */
export function buildExportPdf(params) {
  const doc = buildExportDocument(params);
  const { exportMetadata, profile, summary, reports, comments } = doc;

  const entries = [];
  const addHeading = (text) => {
    entries.push({ kind: "spacer", height: 8 });
    entries.push({ kind: "heading", text });
    entries.push({ kind: "rule" });
  };
  const addSubheading = (text) => {
    entries.push({ kind: "spacer", height: 4 });
    entries.push({ kind: "subheading", text });
  };
  const addField = (label, value) => {
    const formatted =
      value === null || value === undefined || value === ""
        ? "Not provided"
        : typeof value === "object"
          ? JSON.stringify(value)
          : String(value);
    const wrapped = wrapText(`${label}: ${formatted}`, 84);
    for (const line of wrapped) {
      entries.push({ kind: "body", text: line });
    }
  };
  const addLine = (text) => {
    for (const line of wrapText(text, 84)) {
      entries.push({ kind: "body", text: line });
    }
  };

  entries.push({ kind: "title", text: "NagarSathi - Personal Data Export" });
  addField("Export ID", exportMetadata.exportId);
  addField("Generated At", exportMetadata.generatedAt);
  addField("Link Expires At", exportMetadata.expiresAt);
  addField(
    "Summary",
    `${summary.totalReports} report(s), ${summary.totalComments} comment(s)`,
  );

  addHeading("1. Profile & Account Information");
  addField("User ID", profile.uid);
  addField("Full Name", profile.name);
  addField("Email", profile.email);
  addField("Email Verified", profile.emailVerified ? "Yes" : "No");
  addField("Phone", profile.phone);
  addField("Role", profile.role);
  addField("Preferred Language", profile.preferredLanguage);
  addField("Auth Provider", profile.authProvider);
  if (profile.location && typeof profile.location === "object") {
    addField(
      "Saved Ward / Location",
      `Ward ${profile.location.ward ?? "-"}, ${profile.location.municipality ?? "-"}`,
    );
  } else {
    addField("Saved Ward", profile.ward);
  }
  addField("Account Created", profile.createdAt);
  addField("Last Updated", profile.updatedAt);

  addHeading(`2. Submitted Reports (${reports.length})`);
  if (reports.length === 0) {
    addLine("No reports have been submitted on this account yet.");
  } else {
    reports.forEach((report, idx) => {
      addSubheading(
        `Report #${idx + 1}: ${report.title || report.category || report.id}`,
      );
      addField("Report ID", report.id);
      if (report.category) addField("Category", report.category);
      if (report.status) addField("Status", report.status);
      if (report.ward !== undefined) addField("Ward", report.ward);
      if (report.location) addField("Location", report.location);
      if (report.description || report.details || report.body) {
        addField(
          "Description",
          report.description || report.details || report.body,
        );
      }
      if (report.createdAt || report._createTime) {
        addField("Created At", report.createdAt || report._createTime);
      }
    });
  }

  addHeading(`3. Comments & Activity (${comments.length})`);
  if (comments.length === 0) {
    addLine("No comments have been posted on this account yet.");
  } else {
    comments.forEach((comment, idx) => {
      addSubheading(`Comment #${idx + 1} (${comment.id})`);
      if (comment.reportId) addField("Report ID", comment.reportId);
      addField("Text", comment.text || comment.body || comment.content || "");
      if (comment.createdAt || comment._createTime) {
        addField("Created At", comment.createdAt || comment._createTime);
      }
    });
  }

  // Paginate onto US Letter / A4-compatible 612 x 792 pt pages.
  const pageWidth = 612;
  const pageHeight = 792;
  const marginX = 50;
  const startY = 742;
  const minY = 56;

  const pages = [];
  let currentOps = [];
  let y = startY;

  const pushPage = () => {
    pages.push(currentOps);
    currentOps = [];
    y = startY;
  };

  const ensureSpace = (needed) => {
    if (y - needed < minY) {
      pushPage();
    }
  };

  for (const item of entries) {
    if (item.kind === "spacer") {
      if (y < startY) y -= item.height;
      continue;
    }
    if (item.kind === "rule") {
      ensureSpace(8);
      currentOps.push(
        `0.75 w 0.80 0.83 0.78 RG ${marginX} ${y + 4} m ${pageWidth - marginX} ${y + 4} l S`,
      );
      y -= 8;
      continue;
    }
    if (item.kind === "title") {
      ensureSpace(24);
      currentOps.push(
        `BT /F2 17 Tf 0.09 0.23 0.17 rg ${marginX} ${y} Td (${pdfSafeText(item.text)}) Tj ET`,
      );
      y -= 24;
      continue;
    }
    if (item.kind === "heading") {
      ensureSpace(20);
      currentOps.push(
        `BT /F2 13 Tf 0.09 0.23 0.17 rg ${marginX} ${y} Td (${pdfSafeText(item.text)}) Tj ET`,
      );
      y -= 17;
      continue;
    }
    if (item.kind === "subheading") {
      ensureSpace(16);
      currentOps.push(
        `BT /F2 11 Tf 0.12 0.20 0.16 rg ${marginX} ${y} Td (${pdfSafeText(item.text)}) Tj ET`,
      );
      y -= 15;
      continue;
    }
    ensureSpace(14);
    currentOps.push(
      `BT /F1 10 Tf 0.15 0.18 0.16 rg ${marginX} ${y} Td (${pdfSafeText(item.text)}) Tj ET`,
    );
    y -= 14;
  }
  if (currentOps.length > 0 || pages.length === 0) {
    pages.push(currentOps);
  }

  // Add page footer to every page.
  const totalPages = pages.length;
  const pageStreams = pages.map((ops, index) => {
    const footer = `BT /F1 8.5 Tf 0.40 0.45 0.42 rg ${marginX} 32 Td (NagarSathi Data Export  |  Page ${index + 1} of ${totalPages}) Tj ET`;
    return [...ops, footer].join("\n");
  });

  // Assemble PDF objects:
  // 1: Catalog, 2: Pages, 3: Helvetica (/F1), 4: Helvetica-Bold (/F2),
  // 5..: Page + Content pairs.
  const objects = [
    "<< /Type /Catalog /Pages 2 0 R >>",
    null, // filled once page IDs are known
    "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
    "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>",
  ];

  const pageObjectIds = [];
  for (const stream of pageStreams) {
    const pageObjId = objects.length + 1;
    const contentObjId = objects.length + 2;
    pageObjectIds.push(pageObjId);
    objects.push(
      `<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${pageWidth} ${pageHeight}] /Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> /Contents ${contentObjId} 0 R >>`,
    );
    const streamBytes = textEncoder.encode(stream);
    objects.push(
      `<< /Length ${streamBytes.length} >>\nstream\n${stream}\nendstream`,
    );
  }

  objects[1] = `<< /Type /Pages /Kids [${pageObjectIds.map((id) => `${id} 0 R`).join(" ")}] /Count ${pageObjectIds.length} >>`;

  const chunks = [];
  let offset = 0;
  const appendText = (str) => {
    const bytes = textEncoder.encode(str);
    chunks.push(bytes);
    offset += bytes.length;
  };

  appendText("%PDF-1.4\n");
  const offsets = [0];
  for (let i = 0; i < objects.length; i += 1) {
    offsets.push(offset);
    appendText(`${i + 1} 0 obj\n${objects[i]}\nendobj\n`);
  }

  const xrefOffset = offset;
  appendText(`xref\n0 ${objects.length + 1}\n`);
  appendText("0000000000 65535 f \n");
  for (let i = 1; i <= objects.length; i += 1) {
    appendText(`${String(offsets[i]).padStart(10, "0")} 00000 n \n`);
  }
  appendText(
    `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xrefOffset}\n%%EOF\n`,
  );

  const output = new Uint8Array(offset);
  let cursor = 0;
  for (const chunk of chunks) {
    output.set(chunk, cursor);
    cursor += chunk.length;
  }
  return output;
}

// ─── Minimal Pure-JS ZIP Archive Builder (STORE, CRC-32) ─────────────────────

const crcTable = (() => {
  const table = new Uint32Array(256);
  for (let i = 0; i < 256; i += 1) {
    let c = i;
    for (let k = 0; k < 8; k += 1) {
      c = (c & 1) !== 0 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    }
    table[i] = c >>> 0;
  }
  return table;
})();

export function crc32(bytes) {
  let crc = 0xffffffff;
  for (let i = 0; i < bytes.length; i += 1) {
    crc = crcTable[(crc ^ bytes[i]) & 0xff] ^ (crc >>> 8);
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function writeUint16LE(view, offset, value) {
  view.setUint16(offset, value & 0xffff, true);
}

function writeUint32LE(view, offset, value) {
  view.setUint32(offset, value >>> 0, true);
}

/**
 * Packages multiple `{ name, data: Uint8Array }` files into a standard PKZIP
 * archive using STORE (method 0) so every OS opens it natively.
 */
export function buildZipArchive(files) {
  const localParts = [];
  const centralParts = [];
  let localOffset = 0;

  for (const file of files) {
    const nameBytes = textEncoder.encode(file.name);
    const data = file.data instanceof Uint8Array
      ? file.data
      : textEncoder.encode(String(file.data));
    const checksum = crc32(data);

    const localHeader = new Uint8Array(30 + nameBytes.length);
    const lv = new DataView(localHeader.buffer);
    writeUint32LE(lv, 0, 0x04034b50);
    writeUint16LE(lv, 4, 20); // version needed
    writeUint16LE(lv, 6, 0x0800); // UTF-8 filename flag
    writeUint16LE(lv, 8, 0); // STORE
    writeUint16LE(lv, 10, 0);
    writeUint16LE(lv, 12, 0);
    writeUint32LE(lv, 14, checksum);
    writeUint32LE(lv, 18, data.length);
    writeUint32LE(lv, 22, data.length);
    writeUint16LE(lv, 26, nameBytes.length);
    writeUint16LE(lv, 28, 0);
    localHeader.set(nameBytes, 30);

    localParts.push(localHeader, data);

    const centralHeader = new Uint8Array(46 + nameBytes.length);
    const cv = new DataView(centralHeader.buffer);
    writeUint32LE(cv, 0, 0x02014b50);
    writeUint16LE(cv, 4, 20);
    writeUint16LE(cv, 6, 20);
    writeUint16LE(cv, 8, 0x0800);
    writeUint16LE(cv, 10, 0);
    writeUint16LE(cv, 12, 0);
    writeUint16LE(cv, 14, 0);
    writeUint32LE(cv, 16, checksum);
    writeUint32LE(cv, 20, data.length);
    writeUint32LE(cv, 24, data.length);
    writeUint16LE(cv, 28, nameBytes.length);
    writeUint16LE(cv, 30, 0);
    writeUint16LE(cv, 32, 0);
    writeUint16LE(cv, 34, 0);
    writeUint16LE(cv, 36, 0);
    writeUint32LE(cv, 38, 0);
    writeUint32LE(cv, 42, localOffset);
    centralHeader.set(nameBytes, 46);

    centralParts.push(centralHeader);
    localOffset += localHeader.length + data.length;
  }

  let centralSize = 0;
  for (const part of centralParts) centralSize += part.length;

  const endRecord = new Uint8Array(22);
  const ev = new DataView(endRecord.buffer);
  writeUint32LE(ev, 0, 0x06054b50);
  writeUint16LE(ev, 4, 0);
  writeUint16LE(ev, 6, 0);
  writeUint16LE(ev, 8, files.length);
  writeUint16LE(ev, 10, files.length);
  writeUint32LE(ev, 12, centralSize);
  writeUint32LE(ev, 16, localOffset);
  writeUint16LE(ev, 20, 0);

  const totalSize = localOffset + centralSize + endRecord.length;
  const archive = new Uint8Array(totalSize);
  let cursor = 0;
  for (const part of localParts) {
    archive.set(part, cursor);
    cursor += part.length;
  }
  for (const part of centralParts) {
    archive.set(part, cursor);
    cursor += part.length;
  }
  archive.set(endRecord, cursor);
  return archive;
}

export function buildExportPackageZip({
  exportId,
  jsonString,
  pdfBytes,
  requestedAt,
  expiresAt,
}) {
  const readme = [
    "NagarSathi Personal Data Export",
    "===============================",
    `Export ID: ${exportId}`,
    `Generated At: ${new Date(requestedAt).toISOString()}`,
    `Link Expires At: ${new Date(expiresAt).toISOString()}`,
    "",
    "Included files:",
    "- nagarsathi-data-export.json (machine-readable profile, reports, and comments)",
    "- nagarsathi-data-export.pdf  (human-readable summary document)",
    "",
    "Keep this archive in a safe place as it contains your personal account data.",
  ].join("\n");

  return buildZipArchive([
    { name: "README.txt", data: textEncoder.encode(readme) },
    { name: "nagarsathi-data-export.json", data: textEncoder.encode(jsonString) },
    { name: "nagarsathi-data-export.pdf", data: pdfBytes },
  ]);
}

export function buildExportEmail({
  locale,
  name,
  downloadUrl,
  exportId,
  reportCount,
  commentCount,
  expiresAt,
}) {
  const isNepali = String(locale || "").toLowerCase() === "ne";
  const expiryIso = new Date(expiresAt).toISOString();
  const greetingName = name ? ` ${name}` : "";

  if (isNepali) {
    return {
      subject: "तपाईंको नगरसाथी व्यक्तिगत डाटा निर्यात तयार छ",
      text:
        `नमस्ते${greetingName},\n\n` +
        `तपाईंको नगरसाथी प्रोफाइल, रिपोर्ट (${reportCount}) र टिप्पणी (${commentCount}) को सुरक्षित निर्यात प्याकेज (JSON र PDF) तयार भएको छ।\n\n` +
        `इन्क्रिप्ट गरिएको डाउनलोड लिङ्क:\n${downloadUrl}\n\n` +
        `यो लिङ्क ४८ घण्टापछि (${expiryIso}) स्वतः निष्क्रिय हुनेछ।\n` +
        `निर्यात ID: ${exportId}\n`,
      html:
        `<p>नमस्ते${greetingName},</p>` +
        `<p>तपाईंको नगरसाथी प्रोफाइल, रिपोर्ट (${reportCount}) र टिप्पणी (${commentCount}) को सुरक्षित निर्यात प्याकेज (<strong>JSON</strong> र <strong>PDF</strong>) तयार भएको छ।</p>` +
        `<p><a href="${downloadUrl}">इन्क्रिप्ट गरिएको डाटा प्याकेज डाउनलोड गर्नुहोस्</a></p>` +
        `<p><strong>महत्वपूर्ण:</strong> यो डाउनलोड लिङ्क ४८ घण्टापछि (${expiryIso}) स्वतः निष्क्रिय हुनेछ।</p>` +
        `<p style="color:#666;font-size:12px;">निर्यात ID: ${exportId}</p>`,
    };
  }

  return {
    subject: "Your NagarSathi personal data export is ready",
    text:
      `Hello${greetingName},\n\n` +
      `Your NagarSathi data export package is ready. It includes your profile, ${reportCount} report(s), and ${commentCount} comment(s) in both machine-readable JSON and human-readable PDF formats.\n\n` +
      `Secure encrypted download link:\n${downloadUrl}\n\n` +
      `This download link will automatically expire after 48 hours (${expiryIso}).\n` +
      `Export ID: ${exportId}\n`,
    html:
      `<p>Hello${greetingName},</p>` +
      `<p>Your NagarSathi data export package is ready. It includes your profile, ${reportCount} report(s), and ${commentCount} comment(s) in both machine-readable <strong>JSON</strong> and human-readable <strong>PDF</strong> formats.</p>` +
      `<p><a href="${downloadUrl}">Download My Encrypted Data Package</a></p>` +
      `<p><strong>Security notice:</strong> This encrypted download link expires automatically after <strong>48 hours</strong> (${expiryIso}).</p>` +
      `<p style="color:#666;font-size:12px;">Export ID: ${exportId}</p>`,
  };
}
