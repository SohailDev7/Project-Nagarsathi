/**
 * Google Apps Script Gmail mail endpoint.
 *
 * Create a standalone Apps Script project, paste this file's contents into
 * Code.gs, deploy as a Web app, and set Execute as: Me / Access: Anyone.
 *
 * The deployed web app URL is stored by the Cloudflare Worker as
 * GMAIL_MAIL_ENDPOINT. Cloudflare calls this endpoint to send OTP emails.
 */

function doPost(event) {
  const output = (body) => ContentService
    .createTextOutput(JSON.stringify(body))
    .setMimeType(ContentService.MimeType.JSON);

  try {
    const expectedKey =
      PropertiesService.getScriptProperties().getProperty("MAIL_API_KEY");
    const payload = JSON.parse(event.postData.contents);
    const suppliedKey = String(payload.apiKey || "");
    if (!expectedKey || suppliedKey !== expectedKey) {
      return output({ error: "Unauthorized." });
    }

    const to = String(payload.to || "").trim();
    const subject = String(payload.subject || "").trim();
    const text = String(payload.text || "").trim();
    const html = String(payload.html || "").trim();

    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(to)) {
      return output({ error: "Invalid recipient." });
    }
    if (!subject || (!text && !html)) {
      return output({ error: "Missing email content." });
    }

    GmailApp.sendEmail(to, subject, text, {
      htmlBody: html || undefined,
      name: "NagarSathi",
    });

    return output({ sent: true });
  } catch (error) {
    return output({ error: String(error) });
  }
}
