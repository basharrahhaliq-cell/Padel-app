/**
 * Let's Padel — Cloud Functions.
 *
 * These run on Firebase's servers and handle everything the phone app
 * can't do itself: sending push notifications to OTHER users, and
 * awarding XP after games actually happen.
 *
 * Deploy with:  firebase deploy --only functions
 * (Requires the Blaze pay-as-you-go plan; the free monthly quota easily
 * covers a club this size, so the expected cost is ~$0.)
 */
const {onDocumentCreated, onDocumentUpdated} =
    require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {setGlobalOptions} = require("firebase-functions/v2");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

setGlobalOptions({region: "europe-west1", maxInstances: 5});

// ---------- helpers ----------

/** "2026-07-09" for a JS date in Beirut time. */
function dateKey(d) {
  return new Intl.DateTimeFormat("en-CA", {timeZone: "Asia/Beirut"})
      .format(d);
}

/** 990 -> "4:30 PM" */
function fmtTime(minutes) {
  const h24 = Math.floor(minutes / 60);
  const m = minutes % 60;
  const ampm = h24 >= 12 ? "PM" : "AM";
  const h = h24 % 12 === 0 ? 12 : h24 % 12;
  return `${h}:${String(m).padStart(2, "0")} ${ampm}`;
}

/** Short weekday+day for a yyyy-MM-dd key, e.g. "Sat 12 Jul". */
function fmtDate(key) {
  const d = new Date(`${key}T12:00:00Z`);
  return new Intl.DateTimeFormat("en-GB",
      {weekday: "short", day: "numeric", month: "short"}).format(d);
}

/** Sends a notification to every device of the given user ids. */
async function notifyUsers(uids, title, body) {
  const tokens = [];
  for (const uid of [...new Set(uids)].filter(Boolean)) {
    const snap = await db.collection("users").doc(uid).get();
    tokens.push(...(snap.get("fcmTokens") || []));
  }
  if (tokens.length === 0) return;
  await messaging.sendEachForMulticast({
    tokens: [...new Set(tokens)],
    notification: {title, body},
  });
}

async function notifyTopic(topic, title, body) {
  await messaging.send({topic, notification: {title, body}});
}

// ---------- Open Match notifications ----------

exports.onOpenMatchCreated = onDocumentCreated(
    "openMatches/{matchId}", async (event) => {
      const m = event.data.data();
      if (!m || m.status !== "open") return;
      await notifyTopic(
          `open_matches_${m.level}`,
          `A level ${m.level} match needs players!`,
          `${m.branchName}, ${fmtDate(m.date)} ${fmtTime(m.startMinutes)}` +
          ` — ${m.playersNeeded} spot(s). Tap to join.`);
    });

exports.onOpenMatchUpdated = onDocumentUpdated(
    "openMatches/{matchId}", async (event) => {
      const before = event.data.before.data();
      const after = event.data.after.data();
      if (!before || !after) return;
      const everyone =
          [after.creatorId, ...(after.players || []).map((p) => p.uid)];

      if (before.status === "open" && after.status === "full") {
        await notifyUsers(everyone,
            "Your match is full — game on! 🎾",
            `${after.branchName} ${after.courtName}, ` +
            `${fmtDate(after.date)} ${fmtTime(after.startMinutes)}. ` +
            `Players: ${[after.creatorName,
              ...(after.players || []).map((p) => p.name)].join(", ")}`);
      }
      if (before.status !== "cancelled" && after.status === "cancelled") {
        await notifyUsers((after.players || []).map((p) => p.uid),
            "Open match cancelled",
            `The ${fmtDate(after.date)} ${fmtTime(after.startMinutes)} ` +
            `match at ${after.branchName} was cancelled by the creator.`);
      }
    });

// ---------- XP (awarded AFTER the game time has passed) ----------

const XP_BOOKING = 50;
const XP_OPEN_MATCH_JOIN = 20;
const XP_TOURNAMENT = 100;

/** Level thresholds: L2@200, L3@500, L4@1000, then +750 per level. */
function levelForXp(xp) {
  if (xp < 200) return 1;
  if (xp < 500) return 2;
  if (xp < 1000) return 3;
  return 4 + Math.floor((xp - 1000) / 750);
}
exports.levelForXp = levelForXp; // exported for reference/tests

async function grantXp(uid, amount, matchesDelta) {
  if (!uid || uid === "admin") return;
  await db.collection("users").doc(uid).set({
    xp: admin.firestore.FieldValue.increment(amount),
    matchesPlayed: admin.firestore.FieldValue.increment(matchesDelta),
  }, {merge: true});
}

/**
 * Every hour: find confirmed bookings whose start time has passed and
 * that haven't been awarded yet; give the owner (and open-match joiners)
 * their XP. Runs on Beirut time.
 */
exports.awardXpHourly = onSchedule(
    {schedule: "every 60 minutes", timeZone: "Asia/Beirut"},
    async () => {
      const now = new Date();
      const today = dateKey(now);
      const beirut = new Date(now.toLocaleString("en-US",
          {timeZone: "Asia/Beirut"}));
      const nowMinutes = beirut.getHours() * 60 + beirut.getMinutes();

      const snap = await db.collection("bookings")
          .where("status", "==", "confirmed")
          .where("xpAwarded", "==", false)
          .where("date", "<=", today)
          .get();

      for (const doc of snap.docs) {
        const b = doc.data();
        if (b.isBlock) {
          await doc.ref.update({xpAwarded: true});
          continue;
        }
        // Only award once the start time has passed.
        if (b.date === today && b.startMinutes > nowMinutes) continue;

        await grantXp(b.userId, XP_BOOKING, 1);

        if (b.isOpenMatch && b.openMatchId) {
          const matchSnap = await db.collection("openMatches")
              .doc(b.openMatchId).get();
          const players = (matchSnap.get("players") || []);
          for (const p of players) {
            // Joiners played a completed game (+50) plus the join bonus.
            await grantXp(p.uid, XP_BOOKING + XP_OPEN_MATCH_JOIN, 1);
          }
        }
        await doc.ref.update({xpAwarded: true, xpAmount: XP_BOOKING});
      }
    });

/** If an awarded booking is cancelled later (by the owner), remove XP. */
exports.onBookingCancelled = onDocumentUpdated(
    "bookings/{bookingId}", async (event) => {
      const before = event.data.before.data();
      const after = event.data.after.data();
      if (!before || !after) return;
      if (before.status === "confirmed" && after.status === "cancelled" &&
          after.xpAwarded === true && !after.isBlock) {
        await grantXp(after.userId, -XP_BOOKING, -1);
      }
    });

// ---------- Tournament notifications & XP ----------

exports.onTournamentCreated = onDocumentCreated(
    "tournaments/{tid}", async (event) => {
      const t = event.data.data();
      if (!t || t.status !== "published") return;
      const topic = t.level === "Open" ?
          "tournaments_open" : `tournaments_${t.level}`;
      await notifyTopic(topic,
          `New tournament: ${t.name} 🏆`,
          `${t.branchName}, ${fmtDate(t.dates[0])} — ${t.format}, ` +
          `level ${t.level}. Register in the app!`);
    });

exports.onTournamentUpdated = onDocumentUpdated(
    "tournaments/{tid}", async (event) => {
      const before = event.data.before.data();
      const after = event.data.after.data();
      if (!before || !after) return;
      if (before.status !== "finished" && after.status === "finished") {
        const entries = await db.collection("tournaments")
            .doc(event.params.tid).collection("entries")
            .where("status", "==", "registered").get();
        const uids = [];
        for (const e of entries.docs) {
          uids.push(...(e.get("uids") || []));
        }
        await notifyUsers(uids,
            `${after.name}: results are out! 🏆`,
            after.winners && after.winners.length ?
                `Winners: ${after.winners.join(", ")}. ` +
                "Open the app for full standings." :
                "Open the app to see the final standings.");
        for (const uid of new Set(uids)) {
          await grantXp(uid, XP_TOURNAMENT, 0);
        }
      }
    });

exports.onEntryCreated = onDocumentCreated(
    "tournaments/{tid}/entries/{eid}", async (event) => {
      const e = event.data.data();
      if (!e) return;
      const t = await db.collection("tournaments")
          .doc(event.params.tid).get();
      const title = e.status === "waitlist" ?
          `You're on the waitlist for ${t.get("name")}` :
          `You're registered for ${t.get("name")}! 🏆`;
      await notifyUsers(e.uids || [], title,
          `${t.get("branchName")}, ${fmtDate(t.get("dates")[0])} at ` +
          `${fmtTime(t.get("startMinutes"))}.`);
    });

/** Waitlist promotion: notify when an entry flips waitlist -> registered. */
exports.onEntryUpdated = onDocumentUpdated(
    "tournaments/{tid}/entries/{eid}", async (event) => {
      const before = event.data.before.data();
      const after = event.data.after.data();
      if (!before || !after) return;
      if (before.status === "waitlist" && after.status === "registered") {
        const t = await db.collection("tournaments")
            .doc(event.params.tid).get();
        await notifyUsers(after.uids || [],
            "A spot opened up — you're in! 🏆",
            `You are now registered for ${t.get("name")} ` +
            `(${fmtDate(t.get("dates")[0])}).`);
      }
    });

/** Daily 10:00 Beirut: remind tournament players the day before. */
exports.tournamentReminders = onSchedule(
    {schedule: "0 10 * * *", timeZone: "Asia/Beirut"},
    async () => {
      const tomorrow = new Date(Date.now() + 24 * 3600 * 1000);
      const key = dateKey(tomorrow);
      const snap = await db.collection("tournaments")
          .where("dates", "array-contains", key)
          .get();
      for (const doc of snap.docs) {
        const t = doc.data();
        if (t.status === "finished") continue;
        const entries = await doc.ref.collection("entries")
            .where("status", "==", "registered").get();
        const uids = [];
        for (const e of entries.docs) uids.push(...(e.get("uids") || []));
        await notifyUsers(uids,
            `${t.name} is tomorrow! 🏆`,
            `${t.branchName}, ${fmtTime(t.startMinutes)}. Good luck!`);
      }
    });
