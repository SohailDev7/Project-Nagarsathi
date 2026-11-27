const crypto = require("crypto");

const EXPORT_EXPIRY_MS = 48 * 60 * 60 * 1000;
const DELIVERY_SLA_MINUTES = 15;

function base64UrlEncode(buf) {
  return Buffer.from(buf)
    .toString("base64")
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}

function base64UrlDecode(str) {
  const normalized = String(str || "").replaceAll("-", "+").replaceAll("_", "/");
  const padding = normalized.length % 4 === 0 ? "" : "=".repeat(4 - (normalized.length % 4));
  return Buffer.from(normalized + padding, "base64");
}

function deriveKey(secret, purpose) {
  if (!secret) throw new Error("Encryption secret is not configured.");
  return crypto
    .createHash("sha256")
    .update(`nagarsathi:${purpose}:v1:${secret}`)
    .digest();
}

function encryptDownloadToken(secret, payload) {
  const key = deriveKey(secret, "export-download-token");
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", key, iv);
  const encrypted = Buffer.concat([
    cipher.update(JSON.stringify(payload), "utf8"),
    cipher.final(),
  ]);
  const tag = cipher.getAuthTag();
  return base64UrlEncode(Buffer.concat([iv, encrypted, tag]));
}

function decryptDownloadToken(secret, token) {
  try {
    const raw = base64UrlDecode(token);
    if (raw.length <= 28) return null;
    const iv = raw.subarray(0, 12);
    const tag = raw.subarray(raw.length - 16);
    const ciphertext = raw.subarray(12, raw.length - 16);
    const key = deriveKey(secret, "export-download-token");
    const decipher = crypto.createDecipheriv("aes-256-gcm", key, iv);
    decipher.setAuthTag(tag);
    const decrypted = Buffer.concat([
      decipher.update(ciphertext),
      decipher.final(),
    ]);
    return JSON.parse(decrypted.toString("utf8"));
  } catch {
    return null;
  }
}

function encryptExportBundle(secret, exportId, plainBuffer) {
  const key = deriveKey(secret, "export-payload-at-rest");
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", key, iv);
  cipher.setAAD(Buffer.from(exportId, "utf8"));
  const encrypted = Buffer.concat([cipher.update(plainBuffer), cipher.final()]);
  const tag = cipher.getAuthTag();
  return {
    ivBase64: iv.toString("base64"),
    ciphertextBase64: Buffer.concat([encrypted, tag]).toString("base64"),
  };
}

function decryptExportBundle(secret, exportId, ivBase64, ciphertextBase64) {
  const key = deriveKey(secret, "export-payload-at-rest");
  const iv = Buffer.from(ivBase64, "base64");
  const combined = Buffer.from(ciphertextBase64, "base64");
  const tag = combined.subarray(combined.length - 16);
  const ciphertext = combined.subarray(0, combined.length - 16);
  const decipher = crypto.createDecipheriv("aes-256-gcm", key, iv);
  decipher.setAAD(Buffer.from(exportId, "utf8"));
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(ciphertext), decipher.final()]);
}

function normalizeFirestoreData(value) {
  if (value === null || value === undefined) return null;
  if (typeof value.toDate === "function") return value.toDate().toISOString();
  if (Array.isArray(value)) return value.map(normalizeFirestoreData);
  if (typeof value === "object") {
    const out = {};
    for (const [k, v] of Object.entries(value)) {
      out[k] = normalizeFirestoreData(v);
    }
    return out;
  }
  return value;
}

function pdfSafeText(value) {
  if (value === null || value === undefined) return "-";
  const raw = typeof value === "string" ? value : JSON.stringify(value);
  return raw
    .replaceAll("\r\n", " ")
    .replaceAll("\n", " ")
    .replaceAll("\r", " ")
    .replace(/[^\x20-\x7E\xA0-\xFF]/g, "?")
    .replaceAll("\\", "\\\\")
    .replaceAll("(", "\\(")
    .replaceAll(")", "\\)");
}

function buildExportDocument({ exportId, profile, reports = [], comments = [], requestedAt, expiresAt }) {
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

function wrapText(text, maxChars = 84) {
  const words = String(text ?? "").replaceAll("\r\n", "\n").split(/\s+/);
  const lines = [];
  let current = "";
  for (const word of words) {
    if (!word) continue;
    if (!current) {
      let rest = word;
      while (rest.length > maxChars) {
        lines.push(rest.slice(0, maxChars));
        rest = rest.slice(maxChars);
      }
      current = rest;
    } else if (current.length + 1 + word.length <= maxChars) {
      current += ` ${word}`;
    } else {
      lines.push(current);
      let rest = word;
      while (rest.length > maxChars) {
        lines.push(rest.slice(0, maxChars));
        rest = rest.slice(maxChars);
      }
      current = rest;
    }
  }
  if (current) lines.push(current);
  return lines.length > 0 ? lines : [""];
}

function buildExportPdf(params) {
  const doc = buildExportDocument(params);
  const { exportMetadata, profile, summary, reports, comments } = doc;
  const lines = [
    ["title", "NagarSathi - Personal Data Export"],
    ["body", `Export ID: ${exportMetadata.exportId}`],
    ["body", `Generated At: ${exportMetadata.generatedAt}`],
    ["body", `Link Expires At: ${exportMetadata.expiresAt}`],
    ["body", `Summary: ${summary.totalReports} report(s), ${summary.totalComments} comment(s)`],
    ["heading", "1. Profile & Account Information"],
    ["body", `User ID: ${profile.uid || "Not provided"}`],
    ["body", `Full Name: ${profile.name || "Not provided"}`],
    ["body", `Email: ${profile.email || "Not provided"}`],
    ["body", `Phone: ${profile.phone || "Not provided"}`],
    ["body", `Role: ${profile.role || "citizen"}`],
    ["heading", `2. Submitted Reports (${reports.length})`],
  ];
  if (reports.length === 0) {
    lines.push(["body", "No reports have been submitted on this account yet."]);
  } else {
    reports.forEach((r, i) => {
      for (const wrapped of wrapText(`Report #${i + 1} (${r.id}): ${r.title || r.category || "Report"} | Status: ${r.status || "reported"}`)) {
        lines.push(["body", wrapped]);
      }
      if (r.description || r.details) {
        for (const wrapped of wrapText(`  Details: ${r.description || r.details}`)) {
          lines.push(["body", wrapped]);
        }
      }
    });
  }
  lines.push(["heading", `3. Comments & Activity (${comments.length})`]);
  if (comments.length === 0) {
    lines.push(["body", "No comments have been posted on this account yet."]);
  } else {
    comments.forEach((c, i) => {
      for (const wrapped of wrapText(`Comment #${i + 1} (${c.id}): ${c.text || c.body || c.content || ""}`)) {
        lines.push(["body", wrapped]);
      }
    });
  }

  const pages = [];
  let ops = [];
  let y = 742;
  for (const [kind, text] of lines) {
    const step = kind === "title" ? 24 : kind === "heading" ? 18 : 14;
    if (y - step < 56) {
      pages.push(ops);
      ops = [];
      y = 742;
    }
    const font = kind === "body" ? "/F1 10" : kind === "title" ? "/F2 17" : "/F2 13";
    ops.push(`BT ${font} Tf 0.12 0.18 0.16 rg 50 ${y} Td (${pdfSafeText(text)}) Tj ET`);
    y -= step;
  }
  if (ops.length > 0 || pages.length === 0) pages.push(ops);

  const objects = [
    "<< /Type /Catalog /Pages 2 0 R >>",
    null,
    "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
    "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>",
  ];
  const pageIds = [];
  pages.forEach((pageOps, idx) => {
    const pageId = objects.length + 1;
    const contentId = objects.length + 2;
    pageIds.push(pageId);
    const stream = [
      ...pageOps,
      `BT /F1 8.5 Tf 0.40 0.45 0.42 rg 50 32 Td (NagarSathi Data Export | Page ${idx + 1} of ${pages.length}) Tj ET`,
    ].join("\n");
    objects.push(
      `<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> /Contents ${contentId} 0 R >>`,
    );
    objects.push(`<< /Length ${Buffer.byteLength(stream, "utf8")} >>\nstream\n${stream}\nendstream`);
  });
  objects[1] = `<< /Type /Pages /Kids [${pageIds.map((id) => `${id} 0 R`).join(" ")}] /Count ${pageIds.length} >>`;

  const chunks = [Buffer.from("%PDF-1.4\n", "utf8")];
  let offset = chunks[0].length;
  const offsets = [0];
  objects.forEach((obj, i) => {
    offsets.push(offset);
    const buf = Buffer.from(`${i + 1} 0 obj\n${obj}\nendobj\n`, "utf8");
    chunks.push(buf);
    offset += buf.length;
  });
  const xrefOffset = offset;
  const xref = [
    `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`,
    ...offsets.slice(1).map((o) => `${String(o).padStart(10, "0")} 00000 n \n`),
    `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xrefOffset}\n%%EOF\n`,
  ].join("");
  chunks.push(Buffer.from(xref, "utf8"));
  return Buffer.concat(chunks);
}

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

function crc32(buf) {
  let crc = 0xffffffff;
  for (let i = 0; i < buf.length; i += 1) {
    crc = crcTable[(crc ^ buf[i]) & 0xff] ^ (crc >>> 8);
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function buildZipArchive(files) {
  const localParts = [];
  const centralParts = [];
  let offset = 0;
  for (const file of files) {
    const nameBuf = Buffer.from(file.name, "utf8");
    const data = Buffer.isBuffer(file.data) ? file.data : Buffer.from(file.data);
    const sum = crc32(data);

    const local = Buffer.alloc(30 + nameBuf.length);
    local.writeUInt32LE(0x04034b50, 0);
    local.writeUInt16LE(20, 4);
    local.writeUInt16LE(0x0800, 6);
    local.writeUInt16LE(0, 8);
    local.writeUInt32LE(sum, 14);
    local.writeUInt32LE(data.length, 18);
    local.writeUInt32LE(data.length, 22);
    local.writeUInt16LE(nameBuf.length, 26);
    nameBuf.copy(local, 30);
    localParts.push(local, data);

    const central = Buffer.alloc(46 + nameBuf.length);
    central.writeUInt32LE(0x02014b50, 0);
    central.writeUInt16LE(20, 4);
    central.writeUInt16LE(20, 6);
    central.writeUInt16LE(0x0800, 8);
    central.writeUInt32LE(sum, 16);
    central.writeUInt32LE(data.length, 20);
    central.writeUInt32LE(data.length, 24);
    central.writeUInt16LE(nameBuf.length, 28);
    central.writeUInt32LE(offset, 42);
    nameBuf.copy(central, 46);
    centralParts.push(central);

    offset += local.length + data.length;
  }
  const centralBuf = Buffer.concat(centralParts);
  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0);
  end.writeUInt16LE(files.length, 8);
  end.writeUInt16LE(files.length, 10);
  end.writeUInt32LE(centralBuf.length, 12);
  end.writeUInt32LE(offset, 16);
  return Buffer.concat([...localParts, centralBuf, end]);
}

module.exports = {
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
};
