const crypto = require("node:crypto");

const HOUR_MS = 60 * 60 * 1000;
// Leave a day's margin for the hourly purge before the 30-day maximum.
const RETENTION_MS = 29 * 24 * HOUR_MS;
const VERIFIED_PROVIDERS = new Set(["password", "phone", "google.com", "facebook.com"]);

// Dependencies are supplied by index.js so tests never contact live Firebase
// accounts or send real email.
function createCitizenDeletionHandlers({
  db, auth, Timestamp, FieldValue, HttpsError, sendConfirmation,
  now = Date.now, logger = { error() {} },
}) {
  function result(data) {
    return {
      status: data.status === "deleted" ? "deleted" : "pending",
      emailStatus: data.emailStatus || "unavailable",
    };
  }

  function authorUpdate() {
    return {
      authorId: FieldValue.delete(),
      author: { name: "Deleted citizen" },
      authorName: "Deleted citizen",
      authorEmail: FieldValue.delete(),
      authorPhone: FieldValue.delete(),
      authorPhotoUrl: FieldValue.delete(),
      authorPhotoURL: FieldValue.delete(),
    };
  }

  async function anonymizeContributions(uid, deadline) {
    for (const collection of ["reports", "comments"]) {
      while (now() < deadline) {
        const snapshot = await db.collectionGroup(collection)
          .where("authorId", "==", uid).limit(200).get();
        if (snapshot.empty) break;
        const batch = db.batch();
        for (const doc of snapshot.docs) batch.update(doc.ref, authorUpdate());
        await batch.commit();
      }
      if (now() >= deadline) return false;
    }
    return true;
  }

  async function processDeletion(ref) {
    const data = await db.runTransaction(async (tx) => {
      const snapshot = await tx.get(ref);
      if (!snapshot.exists) return null;
      const job = snapshot.data();
      if (job.status === "deleted" && job.emailStatus !== "pending") return null;
      if (job.leaseUntil && job.leaseUntil.toMillis() > now()) return null;
      tx.update(ref, {
        leaseUntil: Timestamp.fromMillis(now() + 2 * 60 * 1000),
        nextAttemptAt: Timestamp.fromMillis(now() + 2 * 60 * 1000),
      });
      return job;
    });
    if (!data) return;

    try {
      if (data.status !== "deleted") {
        try {
          await auth.updateUser(ref.id, { disabled: true });
          await auth.revokeRefreshTokens(ref.id);
        } catch (error) {
          if (error.code !== "auth/user-not-found") throw error;
        }

        // Detaching authorId makes the next page query exclude processed
        // records. The job resumes on the next run if a large feed takes longer.
        const finished = await anonymizeContributions(ref.id, now() + 35000);
        if (!finished) {
          await ref.update({
            leaseUntil: FieldValue.delete(),
            nextAttemptAt: Timestamp.fromMillis(now() + HOUR_MS),
          });
          return;
        }
        await db.recursiveDelete(db.collection("users").doc(ref.id));
        if (data.otpChallengeId) {
          await db.collection("otpChallenges").doc(data.otpChallengeId).delete();
        }
        try {
          await auth.deleteUser(ref.id);
        } catch (error) {
          if (error.code !== "auth/user-not-found") throw error;
        }
        await ref.update({
          status: "deleted",
          deletedAt: Timestamp.fromMillis(now()),
          otpChallengeId: FieldValue.delete(),
        });
      }

      if (data.email && data.purgeDeadline.toMillis() > now()) {
        await sendConfirmation(data.email);
        await ref.update({
          email: FieldValue.delete(),
          emailStatus: "sent",
          leaseUntil: FieldValue.delete(),
          nextAttemptAt: FieldValue.delete(),
        });
      } else {
        await ref.update({
          email: FieldValue.delete(),
          emailStatus: "unavailable",
          leaseUntil: FieldValue.delete(),
          nextAttemptAt: FieldValue.delete(),
        });
      }
    } catch (error) {
      // Keep the citizen's deletion request durable after any partial failure.
      // Email is retained only for delivery retries, for at most 30 days.
      const expired = data.purgeDeadline.toMillis() <= now();
      await ref.update({
        leaseUntil: FieldValue.delete(),
        nextAttemptAt: Timestamp.fromMillis(now() + HOUR_MS),
        ...(expired ? { email: FieldValue.delete(), emailStatus: "unavailable" } : {}),
      });
      logger.error("Citizen profile deletion will be retried.", {
        code: error.code || "unknown",
      });
    }
  }

  async function deleteCitizenProfile(request) {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to delete your profile.");
    }
    if (request.data?.confirm !== true) {
      throw new HttpsError("invalid-argument", "Confirm permanent profile deletion.");
    }
    const token = request.auth.token;
    const verifiedAt = Number(token.auth_time) * 1000;
    if (!Number.isFinite(verifiedAt) || verifiedAt > now() + 30000 ||
        now() - verifiedAt > 5 * 60 * 1000 ||
        !VERIFIED_PROVIDERS.has(token.firebase?.sign_in_provider)) {
      throw new HttpsError("failed-precondition", "Verify your account again.");
    }

    // Ignore any caller-supplied user ID or email. The authenticated UID owns
    // the only account this endpoint can delete.
    const uid = request.auth.uid;
    const ref = db.collection("citizenDeletions").doc(uid);
    let account;
    try {
      account = await auth.getUser(uid);
    } catch (error) {
      if (error.code !== "auth/user-not-found") throw error;
      const previous = await ref.get();
      if (previous.exists) {
        await processDeletion(ref);
        return result((await ref.get()).data());
      }
      throw new HttpsError("unauthenticated", "Your account is already signed out.");
    }

    await db.runTransaction(async (tx) => {
      const [profile, staff, previous] = await Promise.all([
        tx.get(db.collection("users").doc(uid)),
        tx.get(db.collection("staff").doc(uid)),
        tx.get(ref),
      ]);
      const claims = account.customClaims || {};
      if (staff.exists || claims.admin === true || claims.staff === true ||
          (claims.role && claims.role !== "citizen") ||
          (profile.exists && profile.data().role !== "citizen")) {
        throw new HttpsError("permission-denied", "Only citizens can delete their profile.");
      }
      if (previous.exists) return;

      const candidate = String(account.email || profile.data()?.email || "")
        .trim().toLowerCase();
      const email = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(candidate) ? candidate : null;
      tx.set(ref, {
        status: "pending",
        requestedAt: Timestamp.fromMillis(now()),
        purgeDeadline: Timestamp.fromMillis(now() + RETENTION_MS),
        nextAttemptAt: Timestamp.fromMillis(now()),
        emailStatus: email ? "pending" : "unavailable",
        ...(email ? {
          email,
          otpChallengeId: crypto.createHash("sha256").update(email).digest("hex"),
        } : {}),
      });
    });

    await processDeletion(ref);
    return result((await ref.get()).data());
  }

  async function retryCitizenDeletions() {
    const snapshot = await db.collection("citizenDeletions")
      .where("nextAttemptAt", "<=", Timestamp.fromMillis(now())).limit(50).get();
    for (let index = 0; index < snapshot.docs.length; index += 5) {
      await Promise.all(snapshot.docs.slice(index, index + 5)
        .map((doc) => processDeletion(doc.ref)));
    }
  }

  return { deleteCitizenProfile, retryCitizenDeletions };
}

module.exports = { createCitizenDeletionHandlers };
