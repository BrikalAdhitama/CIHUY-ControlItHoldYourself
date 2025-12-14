const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Helper untuk kirim push ke topic
 */
async function sendToTopic(topic, title, body) {
  const message = {
    topic,
    notification: {
      title,
      body,
    },
    android: {
      priority: "high",
    },
  };

  await admin.messaging().send(message);
}

/**
 * ⏰ SARAPAN — 09:00
 */
exports.reminderBreakfast = functions.pubsub
  .schedule("0 9 * * *")
  .timeZone("Asia/Jakarta")
  .onRun(async () => {
    await sendToTopic(
      "meal_reminder",
      "☀️ Selamat Pagi Pejuang!",
      "Hari baru, satu langkah lagi menuju hidup lebih sehat 💪"
    );
  });

/**
 * 🍽️ MAKAN SIANG — 13:00
 */
exports.reminderLunch = functions.pubsub
  .schedule("0 13 * * *")
  .timeZone("Asia/Jakarta")
  .onRun(async () => {
    await sendToTopic(
      "meal_reminder",
      "🍱 Waktunya Makan Siang",
      "Isi energi dulu, jangan lupa kamu lagi berjuang 🚀"
    );
  });

/**
 * 🌙 MAKAN MALAM — 20:00
 */
exports.reminderDinner = functions.pubsub
  .schedule("0 20 * * *")
  .timeZone("Asia/Jakarta")
  .onRun(async () => {
    await sendToTopic(
      "meal_reminder",
      "🌙 Malam Sudah Tiba",
      "Bangga sama kamu hari ini. Istirahat yang cukup ya 🤍"
    );
  });
