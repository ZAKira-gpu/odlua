// const { onRequest } = require("firebase-functions/v2/https");
// const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
// const { logger } = require("firebase-functions");
// const admin = require("firebase-admin");

// admin.initializeApp();

// // --------------------
// // 🔔 HTTP Notification
// // --------------------
// exports.sendNotification = onRequest(async (req, res) => {
//   res.set("Access-Control-Allow-Origin", "*");
//   res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
//   res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");

//   if (req.method === "OPTIONS") {
//     return res.status(204).send("");
//   }

//   if (req.method !== "POST") {
//     return res.status(405).json({ error: "Method Not Allowed" });
//   }

//   try {
//     const { token, title, body, data, notificationType } = req.body;

//     if (!token || !title || !body) {
//       return res.status(400).json({ error: "Missing required fields" });
//     }

//     const message = {
//       token,
//       notification: {
//         title: title,
//         body: body,
//       },
//       data: {
//         ...data,
//         click_action: "FLUTTER_NOTIFICATION_CLICK",
//         notificationType: notificationType || "general",
//       },
//       android: {
//         priority: "high",
//         notification: {
//           channelId: "odlua_channel",
//           sound: "default",
//           clickAction: "FLUTTER_NOTIFICATION_CLICK",
//           icon: "ic_notification",
//           color: "#FF6B35",
//           tag: notificationType || "general",
//         },
//       },
//       apns: {
//         payload: {
//           aps: {
//             alert: {
//               title: title,
//               body: body,
//             },
//             sound: "default",
//             badge: 1,
//           },
//         },
//       },
//       webpush: {
//         notification: {
//           icon: "https://odlua.com/icon.png",
//           badge: "https://odlua.com/badge.png",
//           title: title,
//           body: body,
//         },
//       },
//     };

//     const response = await admin.messaging().send(message);
//     logger.info("✅ Notification sent:", response);
//     res.status(200).json({ success: true, messageId: response });
//   } catch (error) {
//     logger.error("❌ Notification error:", error);

//     let errorMessage = error.message;
//     let statusCode = 500;

//     if (error.code === "messaging/invalid-registration-token" ||
//         error.code === "messaging/registration-token-not-registered") {
//       statusCode = 400;
//       errorMessage = "Invalid or unregistered FCM token";
//     }

//     res.status(statusCode).json({
//       success: false,
//       error: errorMessage,
//       code: error.code,
//     });
//   }
// });

// // --------------------------
// // 💬 Chat Message Trigger - IMPROVED NOTIFICATION
// // --------------------------
// exports.sendChatNotification = onDocumentCreated(
//     "chats/{chatId}/messages/{messageId}",
//     async (event) => {
//       try {
//         const snapshot = event.data;
//         const { chatId } = event.params;

//         if (!snapshot.exists) {
//           logger.log("❌ No snapshot data exists");
//           return null;
//         }

//         const messageData = snapshot.data();

//         if (!messageData.text || messageData.senderId === "system") {
//           logger.log("⏭️ Skipping: No text or system message");
//           return null;
//         }

//         if (messageData.isDeleted) {
//           logger.log("⏭️ Skipping: Message is deleted");
//           return null;
//         }

//         const chatDoc = await admin.firestore().collection("chats").doc(chatId).get();
//         if (!chatDoc.exists) {
//           logger.log("❌ Chat document doesn't exist");
//           return null;
//         }

//         const chatData = chatDoc.data();
//         const participants = chatData.participants || [];

//         // Find recipient (the one who didn't send the message)
//         const recipientId = participants.find((p) => p !== messageData.senderId);
//         if (!recipientId) {
//           logger.log("❌ No recipient found");
//           return null;
//         }

//         // Check if user is blocked
//         const blockedUsers = chatData.blockedUsers || {};
//         if (blockedUsers[recipientId] || blockedUsers[messageData.senderId]) {
//           logger.log("⏭️ Skipping: User is blocked");
//           return null;
//         }

//         // Get sender data
//         const senderDoc = await admin
//             .firestore()
//             .collection("users")
//             .doc(messageData.senderId)
//             .get();

//         if (!senderDoc.exists) {
//           logger.log("❌ Sender document doesn't exist");
//           return null;
//         }

//         const senderData = senderDoc.data() || {};
//         const senderName = senderData.name || senderData.displayName || "Someone";

//         // Get recipient data and FCM token
//         const recipientDoc = await admin
//             .firestore()
//             .collection("users")
//             .doc(recipientId)
//             .get();

//         if (!recipientDoc.exists) {
//           logger.log("❌ Recipient document doesn't exist");
//           return null;
//         }

//         const recipientData = recipientDoc.data() || {};
//         const fcmToken = recipientData.fcmToken;

//         if (!fcmToken) {
//           logger.log("❌ No FCM token for recipient");
//           return null;
//         }

//         // Check if recipient has notifications disabled
//         if (recipientData.notificationSettings?.chat === false) {
//           logger.log("⏭️ Skipping: Recipient has chat notifications disabled");
//           return null;
//         }

//         const messageText = messageData.text || "";
//         const truncatedBody = messageText.length > 100 ?
//             `${messageText.substring(0, 100)}...` : messageText;

//         // IMPROVED: Better notification title and body
//         const message = {
//           token: fcmToken,
//           notification: {
//             title: `💬 ${senderName}`, // Added emoji and sender name
//             body: truncatedBody,
//           },
//           data: {
//             type: "chat_message",
//             chatId: chatId,
//             senderId: messageData.senderId,
//             senderName: senderName,
//             message: messageText,
//             timestamp: new Date().toISOString(),
//             click_action: "FLUTTER_NOTIFICATION_CLICK",
//             // ADDED: Navigation data to open chat list
//             navigationRoute: "/chatList", // This will help Flutter navigate to chat list
//             screen: "chat_list",
//           },
//           android: {
//             priority: "high",
//             notification: {
//               channelId: "odlua_channel",
//               sound: "default",
//               clickAction: "FLUTTER_NOTIFICATION_CLICK",
//               icon: "ic_notification",
//               color: "#FF6B35", // Odlua brand color
//               tag: `chat_${chatId}`, // Group notifications by chat
//             },
//           },
//           apns: {
//             payload: {
//               aps: {
//                 alert: {
//                   title: `💬 ${senderName}`,
//                   body: truncatedBody,
//                 },
//                 sound: "default",
//                 badge: 1,
//                 threadId: `chat_${chatId}`, // Group iOS notifications
//               },
//             },
//           },
//           webpush: {
//             notification: {
//               icon: "https://odlua.com/icon.png",
//               badge: "https://odlua.com/badge.png",
//               title: `💬 ${senderName}`,
//               body: truncatedBody,
//               tag: `chat_${chatId}`,
//             },
//           },
//         };

//         const response = await admin.messaging().send(message);
//         logger.info("✅ Chat notification sent successfully:", response);
//         return null;
//       } catch (error) {
//         logger.error("❌ sendChatNotification error:", error);
//         return null;
//       }
//     },
// );

// // ------------------------------
// // 🍽 Reservation Update Trigger - IMPROVED NOTIFICATION
// // ------------------------------
// exports.sendReservationNotification = onDocumentUpdated(
//     "reservations/{reservationId}",
//     async (event) => {
//       try {
//         const beforeData = event.data.before.data();
//         const afterData = event.data.after.data();

//         if (beforeData.status === afterData.status) {
//           return null;
//         }

//         let recipientId;
//         let title;
//         let body;
//         let notificationType = "reservation_update";
//         let emoji = "🍽️"; // Default food emoji

//         const status = afterData.status;
//         const dishName = afterData.dishName || "a dish";
//         const customerId = afterData.customerId;
//         const chefId = afterData.chefId;

//         switch (status) {
//           case "reserved": {
//             recipientId = chefId;
//             title = "📋 New Reservation Request";
//             body = `Someone wants to reserve "${dishName}"`;
//             notificationType = "reservation_request";
//             emoji = "📋";
//             break;
//           }
//           case "confirmed": {
//             recipientId = customerId;
//             title = "✅ Reservation Confirmed!";
//             body = `Your reservation for "${dishName}" has been confirmed`;
//             notificationType = "reservation_confirmed";
//             emoji = "✅";
//             break;
//           }
//           case "declined": {
//             recipientId = customerId;
//             title = "❌ Reservation Declined";
//             body = `Your reservation for "${dishName}" was declined`;
//             notificationType = "reservation_declined";
//             emoji = "❌";
//             break;
//           }
//           case "expired": {
//             recipientId = customerId;
//             title = "⏰ Reservation Expired";
//             body = `Your reservation for "${dishName}" has expired`;
//             notificationType = "reservation_expired";
//             emoji = "⏰";
//             break;
//           }
//           case "completed": {
//             recipientId = chefId;
//             title = "🎉 Reservation Completed";
//             body = `Reservation for "${dishName}" has been completed`;
//             notificationType = "reservation_completed";
//             emoji = "🎉";
//             break;
//           }
//           case "cancelled": {
//             const cancelledBy = afterData.cancelledBy;
//             if (cancelledBy === "customer") {
//               recipientId = chefId;
//               title = "🚫 Reservation Cancelled";
//               body = `Customer cancelled reservation for "${dishName}"`;
//             } else {
//               recipientId = customerId;
//               title = "🚫 Reservation Cancelled";
//               body = `Chef cancelled reservation for "${dishName}"`;
//             }
//             notificationType = "reservation_cancelled";
//             emoji = "🚫";
//             break;
//           }
//           default:
//             return null;
//         }

//         if (!recipientId) {
//           logger.log("❌ No recipient ID for reservation notification");
//           return null;
//         }

//         // Get recipient data
//         const recipientDoc = await admin
//             .firestore()
//             .collection("users")
//             .doc(recipientId)
//             .get();

//         if (!recipientDoc.exists) {
//           logger.log("❌ Recipient document doesn't exist");
//           return null;
//         }

//         const recipientData = recipientDoc.data() || {};
//         const fcmToken = recipientData.fcmToken;

//         if (!fcmToken) {
//           logger.log("❌ No FCM token for recipient");
//           return null;
//         }

//         // Check if recipient has reservation notifications disabled
//         if (recipientData.notificationSettings?.reservations === false) {
//           logger.log("⏭️ Skipping: Recipient has reservation notifications disabled");
//           return null;
//         }

//         const message = {
//           token: fcmToken,
//           notification: {
//             title: `${emoji} ${title}`,
//             body: body,
//           },
//           data: {
//             type: notificationType,
//             reservationId: event.params.reservationId,
//             status: status,
//             dishName: dishName,
//             timestamp: new Date().toISOString(),
//             click_action: "FLUTTER_NOTIFICATION_CLICK",
//             // ADDED: Navigation data
//             navigationRoute: "/reservations", // Navigate to reservations screen
//             screen: "reservations",
//           },
//           android: {
//             priority: "high",
//             notification: {
//               channelId: "odlua_reservations",
//               sound: "default",
//               clickAction: "FLUTTER_NOTIFICATION_CLICK",
//               icon: "ic_notification",
//               color: "#FF6B35",
//               tag: `reservation_${event.params.reservationId}`,
//             },
//           },
//           apns: {
//             payload: {
//               aps: {
//                 alert: {
//                   title: `${emoji} ${title}`,
//                   body: body,
//                 },
//                 sound: "default",
//                 badge: 1,
//               },
//             },
//           },
//         };

//         const response = await admin.messaging().send(message);
//         logger.info(`✅ Reservation notification sent (${status}):`, response);
//         return null;
//       } catch (error) {
//         logger.error("❌ sendReservationNotification error:", error);
//         return null;
//       }
//     },
// );

const { onRequest } = require("firebase-functions/v2/https");
const {
  onDocumentCreated,
  onDocumentUpdated,
  onDocumentWritten,
} = require("firebase-functions/v2/firestore");
const { onCall } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler"); // Added for scheduled tasks
const { logger } = require("firebase-functions");
const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

// --------------------
// 🔔 HTTP Notification - PRODUCTION READY
// --------------------
exports.sendNotification = onRequest(async (req, res) => {
  // Enhanced CORS handling
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.set(
      "Access-Control-Allow-Headers",
      "Content-Type, Authorization, X-Requested-With",
  );

  if (req.method === "OPTIONS") {
    return res.status(204).send("");
  }

  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method Not Allowed" });
  }

  try {
    const { token, title, body, data, imageUrl } = req.body;

    // Input validation
    if (!token || !title || !body) {
      return res.status(400).json({
        success: false,
        error: "Missing required fields: token, title, body",
      });
    }

    if (typeof token !== "string" || token.length === 0) {
      return res.status(400).json({
        success: false,
        error: "Invalid FCM token",
      });
    }

    // Enhanced message payload
    const message = {
      token: token.trim(),
      notification: {
        title: title,
        body: body,
      },
      data: {
        ...data,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        timestamp: new Date().toISOString(),
      },
      android: {
        priority: "high",
        notification: {
          channelId: "odlua_channel",
          sound: "default",
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
          icon: "ic_launcher",
          color: "#197533",
          tag: data?.type || "general",
          ...(imageUrl && { image: imageUrl }),
        },
      },
      apns: {
        headers: {
          "apns-priority": "10",
          "apns-push-type": "alert",
        },
        payload: {
          aps: {
            "alert": {
              title: title,
              body: body,
            },
            "sound": "default",
            "badge": 1,
            "content-available": 1,
            "mutable-content": 1,
          },
        },
      },
      webpush: {
        notification: {
          icon: "https://your-domain.com/icon.png",
          badge: "https://your-domain.com/badge.png",
          title: title,
          body: body,
          ...(imageUrl && { image: imageUrl }),
        },
        fcmOptions: {
          link: "https://your-domain.com",
        },
      },
    };

    // Send notification
    const response = await admin.messaging().send(message);

    logger.info("✅ Notification sent successfully", {
      messageId: response,
      type: data?.type,
      token: token.substring(0, 10) + "...", // Log partial token for security
    });

    res.status(200).json({
      success: true,
      messageId: response,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error("❌ Notification error:", error);

    // Enhanced error handling
    let errorMessage = error.message;
    let statusCode = 500;

    if (
      error.code === "messaging/invalid-registration-token" ||
      error.code === "messaging/registration-token-not-registered"
    ) {
      statusCode = 400;
      errorMessage = "Invalid or unregistered FCM token";

      // Optional: Clean up invalid token from user documents
      try {
        const usersSnapshot = await admin
            .firestore()
            .collection("users")
            .where("fcmToken", "==", req.body.token)
            .get();

        for (const doc of usersSnapshot.docs) {
          await doc.ref.update({
            fcmToken: admin.firestore.FieldValue.delete(),
            fcmTokens: admin.firestore.FieldValue.arrayRemove(req.body.token),
          });
        }
      } catch (cleanupError) {
        logger.warn("Failed to cleanup invalid token:", cleanupError);
      }
    }

    res.status(statusCode).json({
      success: false,
      error: errorMessage,
      code: error.code,
      timestamp: new Date().toISOString(),
    });
  }
});

// --------------------------
// 🧪 Test Notification - Simple iOS/Android Test
// --------------------------
exports.testNotification = onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    return res.status(204).send("");
  }

  try {
    const { userId } = req.body;

    if (!userId) {
      return res.status(400).json({ error: "Missing userId" });
    }

    // Get user's FCM token
    const userDoc = await admin.firestore().collection("users").doc(userId).get();
    if (!userDoc.exists) {
      return res.status(404).json({ error: "User not found" });
    }

    const userData = userDoc.data();
    const fcmToken = userData.fcmToken;
    const platform = userData.fcmPlatform || "unknown";

    if (!fcmToken) {
      return res.status(400).json({ error: "No FCM token for user", platform: platform });
    }

    logger.info(`🧪 Sending test notification to ${platform} device`);

    // Very simple notification payload - should work on both platforms
    const message = {
      token: fcmToken,
      notification: {
        title: "🧪 Test Notification",
        body: `This is a test! Platform: ${platform}`,
      },
      apns: {
        headers: {
          "apns-priority": "10",
          "apns-push-type": "alert",
        },
        payload: {
          aps: {
            alert: {
              title: "🧪 Test Notification",
              body: `This is a test! Platform: ${platform}`,
            },
            sound: "default",
          },
        },
      },
      android: {
        priority: "high",
        notification: {
          channelId: "odlua_channel",
          sound: "default",
        },
      },
    };

    const response = await admin.messaging().send(message);

    logger.info(`✅ Test notification sent to ${platform}:`, response);

    res.status(200).json({
      success: true,
      messageId: response,
      platform: platform,
      tokenPrefix: fcmToken.substring(0, 20) + "...",
    });
  } catch (error) {
    logger.error("❌ Test notification error:", error);
    res.status(500).json({
      success: false,
      error: error.message,
      code: error.code,
    });
  }
});

// --------------------------
// 💬 Chat Message Trigger - PRODUCTION READY
// --------------------------
exports.sendChatNotification = onDocumentCreated(
    "chats/{chatId}/messages/{messageId}",
    async (event) => {
      try {
        const snapshot = event.data;
        const { chatId } = event.params;

        if (!snapshot.exists) {
          logger.log("❌ No snapshot data exists");
          return null;
        }

        const messageData = snapshot.data();

        // Skip conditions
        if (!messageData.text || messageData.senderId === "system") {
          logger.log("⏭️ Skipping: No text or system message");
          return null;
        }

        if (messageData.isDeleted) {
          logger.log("⏭️ Skipping: Message is deleted");
          return null;
        }

        // Get chat document
        const chatDoc = await admin
            .firestore()
            .collection("chats")
            .doc(chatId)
            .get();
        if (!chatDoc.exists) {
          logger.log("❌ Chat document doesn't exist");
          return null;
        }

        const chatData = chatDoc.data();
        const participants = chatData.participants || [];

        // Find recipient
        const recipientId = participants.find((p) => p !== messageData.senderId);
        if (!recipientId) {
          logger.log("❌ No recipient found");
          return null;
        }

        // Check if user is blocked
        const blockedUsers = chatData.blockedUsers || {};
        if (blockedUsers[recipientId] || blockedUsers[messageData.senderId]) {
          logger.log("⏭️ Skipping: User is blocked");
          return null;
        }

        // Get sender data
        const senderDoc = await admin
            .firestore()
            .collection("users")
            .doc(messageData.senderId)
            .get();

        if (!senderDoc.exists) {
          logger.log("❌ Sender document doesn't exist");
          return null;
        }

        const senderData = senderDoc.data() || {};
        const senderName = senderData.name || senderData.displayName || "Someone";

        // Get recipient data
        const recipientDoc = await admin
            .firestore()
            .collection("users")
            .doc(recipientId)
            .get();

        if (!recipientDoc.exists) {
          logger.log("❌ Recipient document doesn't exist");
          return null;
        }

        const recipientData = recipientDoc.data() || {};

        // Check notification settings
        if (recipientData.notificationSettings?.chat === false) {
          logger.log("⏭️ Skipping: Recipient has chat notifications disabled");
          return null;
        }

        const fcmToken = recipientData.fcmToken;
        if (!fcmToken) {
          logger.log("❌ No FCM token for recipient");
          return null;
        }

        const messageText = messageData.text || "";
        const truncatedBody =
        messageText.length > 100 ?
          `${messageText.substring(0, 100)}...` :
          messageText;

        // Enhanced notification message
        const message = {
          token: fcmToken,
          notification: {
            title: `💬 ${senderName}`,
            body: truncatedBody,
          },
          data: {
            type: "chat_message",
            chatId: chatId,
            senderId: messageData.senderId,
            senderName: senderName,
            message: messageText,
            timestamp: new Date().toISOString(),
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            navigationRoute: "/chat",
            screen: "chat_conversation",
          },
          android: {
            priority: "high",
            notification: {
              channelId: "odlua_channel",
              sound: "default",
              clickAction: "FLUTTER_NOTIFICATION_CLICK",
              icon: "ic_launcher",
              color: "#197533",
              tag: `chat_${chatId}`,
            },
          },
          apns: {
            headers: {
              "apns-priority": "10",
              "apns-push-type": "alert",
            },
            payload: {
              aps: {
                "alert": {
                  title: `💬 ${senderName}`,
                  body: truncatedBody,
                },
                "sound": "default",
                "badge": 1,
                "content-available": 1,
                "mutable-content": 1,
              },
            },
          },
        };

        const response = await admin.messaging().send(message);
        logger.info("✅ Chat notification sent successfully", {
          messageId: response,
          chatId: chatId,
          sender: messageData.senderId,
          recipient: recipientId,
        });

        return null;
      } catch (error) {
        logger.error("❌ sendChatNotification error:", error);
        return null;
      }
    },
);

// ------------------------------
// 🍽 Reservation Update Trigger - PRODUCTION READY
// ------------------------------
exports.sendReservationNotification = onDocumentUpdated(
    "reservations/{reservationId}",
    async (event) => {
      try {
        const beforeData = event.data.before.data();
        const afterData = event.data.after.data();

        // Only send notification if status changed
        if (beforeData.status === afterData.status) {
          return null;
        }

        let recipientId;
        let title;
        let body;
        let notificationType = "reservation_update";
        let emoji = "🍽️";

        const status = afterData.status;
        const dishName = afterData.dishName || "a dish";
        const customerId = afterData.customerId;
        const chefId = afterData.chefId;

        switch (status) {
          case "reserved":
          case "pending":
            recipientId = chefId;
            title = "New Reservation Request";
            body = `Someone wants to reserve "${dishName}"`;
            notificationType = "reservation_request";
            emoji = "📋";
            break;

          case "confirmed":
          case "accepted":
            recipientId = customerId;
            title = "Reservation Confirmed!";
            body = `Your reservation for "${dishName}" has been confirmed`;
            notificationType = "reservation_confirmed";
            emoji = "✅";
            break;

          case "declined":
            recipientId = customerId;
            title = "Reservation Declined";
            body = `Your reservation for "${dishName}" was declined`;
            if (afterData.declineReason) {
              body += ` - ${afterData.declineReason}`;
            }
            notificationType = "reservation_declined";
            emoji = "❌";
            break;

          case "expired":
            recipientId = customerId;
            title = "Reservation Expired";
            body = `Your reservation for "${dishName}" has expired`;
            notificationType = "reservation_expired";
            emoji = "⏰";
            break;

          case "completed":
            recipientId = chefId;
            title = "Reservation Completed";
            body = `Reservation for "${dishName}" has been completed`;
            notificationType = "reservation_completed";
            emoji = "🎉";
            break;

          case "cancelled": {
          // ✅ wrapped in braces to allow const declaration safely
            const cancelledBy = afterData.cancelledBy;
            if (cancelledBy === "customer") {
              recipientId = chefId;
              title = "Reservation Cancelled";
              body = `Customer cancelled reservation for "${dishName}"`;
            } else {
              recipientId = customerId;
              title = "Reservation Cancelled";
              body = `Chef cancelled reservation for "${dishName}"`;
            }
            notificationType = "reservation_cancelled";
            emoji = "🚫";
            break;
          }

          default:
            return null;
        }
        if (!recipientId) {
          logger.log("❌ No recipient ID for reservation notification");
          return null;
        }

        // Get recipient data
        const recipientDoc = await admin
            .firestore()
            .collection("users")
            .doc(recipientId)
            .get();

        if (!recipientDoc.exists) {
          logger.log("❌ Recipient document doesn't exist");
          return null;
        }

        const recipientData = recipientDoc.data() || {};

        // Check notification settings
        if (recipientData.notificationSettings?.reservations === false) {
          logger.log(
              "⏭️ Skipping: Recipient has reservation notifications disabled",
          );
          return null;
        }

        const fcmToken = recipientData.fcmToken;
        if (!fcmToken) {
          logger.log("❌ No FCM token for recipient");
          return null;
        }

        // Enhanced notification message
        const message = {
          token: fcmToken,
          notification: {
            title: `${emoji} ${title}`,
            body: body,
          },
          data: {
            type: notificationType,
            reservationId: event.params.reservationId,
            status: status,
            dishName: dishName,
            timestamp: new Date().toISOString(),
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            navigationRoute: "/reservations",
            screen: "reservation_status",
          },
          android: {
            priority: "high",
            notification: {
              channelId: "odlua_channel",
              sound: "default",
              clickAction: "FLUTTER_NOTIFICATION_CLICK",
              icon: "ic_launcher",
              color: "#197533",
              tag: `reservation_${event.params.reservationId}`,
            },
          },
          apns: {
            headers: {
              "apns-priority": "10",
              "apns-push-type": "alert",
            },
            payload: {
              aps: {
                "alert": {
                  title: `${emoji} ${title}`,
                  body: body,
                },
                "sound": "default",
                "badge": 1,
                "content-available": 1,
                "mutable-content": 1,
              },
            },
          },
        };

        const response = await admin.messaging().send(message);
        logger.info(`✅ Reservation notification sent`, {
          messageId: response,
          reservationId: event.params.reservationId,
          status: status,
          recipient: recipientId,
        });

        return null;
      } catch (error) {
        logger.error("❌ sendReservationNotification error:", error);
        return null;
      }
    },
);

// --------------------------
// 📦 NEW ORDER CREATION - CHEF NOTIFICATION (FIXED #8)
// --------------------------
exports.sendNewOrderNotification = onDocumentCreated(
    "orders/{orderId}",
    async (event) => {
      try {
        const orderData = event.data.data();
        const orderId = event.params.orderId;

        if (!orderData) {
          logger.log("❌ No order data exists");
          return null;
        }

        const dishName = orderData.dishName || "a dish";
        const customerName = orderData.customerName || "A customer";
        const quantity = orderData.quantity || 1;
        const chefId = orderData.chefId;

        if (!chefId) {
          logger.log("❌ No chefId in order data");
          return null;
        }

        logger.info(
            `📦 New order created: ${orderId}, notifying chef: ${chefId}`,
        );

        // Get chef data and FCM token
        const chefDoc = await admin
            .firestore()
            .collection("users")
            .doc(chefId)
            .get();

        if (!chefDoc.exists) {
          logger.log("❌ Chef document doesn't exist");
          return null;
        }

        const chefData = chefDoc.data() || {};

        // Check notification settings
        if (chefData.notificationSettings?.orders === false) {
          logger.log("⏭️ Skipping: Chef has order notifications disabled");
          return null;
        }

        const fcmToken = chefData.fcmToken;
        if (!fcmToken) {
          logger.log("❌ No FCM token for chef");
          return null;
        }

        // Enhanced notification message for chef
        const title = "🎉 New Order Received!";
        const body = `${customerName} ordered ${quantity}x "${dishName}"`;

        const message = {
          token: fcmToken,
          notification: {
            title: title,
            body: body,
          },
          data: {
            type: "order_created",
            orderId: orderId,
            dishName: dishName,
            customerName: customerName,
            quantity: quantity.toString(),
            timestamp: new Date().toISOString(),
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            navigationRoute: "/chef_orders",
            screen: "chef_order_management",
          },
          android: {
            priority: "high",
            notification: {
              channelId: "odlua_channel", // Use the main channel created by the app
              sound: "default",
              clickAction: "FLUTTER_NOTIFICATION_CLICK",
              icon: "ic_launcher",
              color: "#197533",
              tag: `order_${orderId}`,
              priority: "max", // Maximum priority for new orders
              visibility: "public",
            },
          },
          apns: {
            headers: {
              "apns-priority": "10",
              "apns-push-type": "alert",
            },
            payload: {
              aps: {
                "alert": {
                  title: title,
                  body: body,
                },
                "sound": "default",
                "badge": 1,
                "content-available": 1,
                "mutable-content": 1,
              },
            },
          },
        };

        const response = await admin.messaging().send(message);
        logger.info(`✅ New order notification sent to chef`, {
          messageId: response,
          orderId: orderId,
          chefId: chefId,
          dishName: dishName,
        });

        // Update order with notification status
        await admin.firestore().collection("orders").doc(orderId).update({
          chefNotified: true,
          chefNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        return null;
      } catch (error) {
        logger.error("❌ sendNewOrderNotification error:", error);
        return null;
      }
    },
);

// --------------------------
// 📦 Order Status Update Trigger - FOR STATUS CHANGES
// --------------------------
exports.sendOrderNotification = onDocumentUpdated(
    "orders/{orderId}",
    async (event) => {
      try {
        const beforeData = event.data.before.data();
        const afterData = event.data.after.data();

        // Only send notification if status changed
        if (beforeData.status === afterData.status) {
          return null;
        }

        let recipientId;
        let title;
        let body;
        let notificationType = "order_update";
        let emoji = "📦";

        const status = afterData.status;
        const dishName = afterData.dishName || "your order";
        const customerId = afterData.customerId;
        const chefId = afterData.chefId;

        switch (status) {
          case "pending":
          // Skip - already handled by onCreate trigger
            return null;

          case "preparing":
            recipientId = customerId;
            title = "🍳 Chef Started Preparing";
            body = `Great news! The chef has started preparing your "${dishName}"`;
            notificationType = "order_preparing";
            emoji = "👨‍🍳";
            break;

          case "ready":
            recipientId = customerId;
            title = "✅ Order Ready!";
            body = `Your "${dishName}" is ready for pickup! Head over to collect it.`;
            notificationType = "order_ready";
            emoji = "🎯";
            break;

          case "completed":
          case "delivered":
            recipientId = customerId;
            title = "🎉 Order Completed";
            body = `Thank you! Your order for "${dishName}" has been completed. Enjoy your meal!`;
            notificationType = "order_completed";
            emoji = "🎉";
            break;

          case "cancelled": {
            const cancelledBy = afterData.cancelledBy || "system";
            if (cancelledBy === "customer" || cancelledBy === customerId) {
              recipientId = chefId;
              title = "❌ Order Cancelled";
              body = `Customer cancelled the order for "${dishName}"`;
              emoji = "❌";
            } else {
              recipientId = customerId;
              title = "❌ Order Cancelled";
              body = `Your order for "${dishName}" was cancelled by the chef`;
              if (afterData.cancellationReason) {
                body += ` - ${afterData.cancellationReason}`;
              }
              emoji = "❌";
            }
            notificationType = "order_cancelled";

            // CRITICAL FIX #29: Restore stock when order is cancelled
            // Only restore if previous status was not already cancelled
            if (beforeData.status !== "cancelled") {
              const quantity = afterData.quantity || 1;
              const dishId = afterData.dishId;
              if (dishId && quantity > 0) {
                try {
                  await admin.firestore().collection("dishes").doc(dishId).update({
                    stock: admin.firestore.FieldValue.increment(quantity),
                    availableStock: admin.firestore.FieldValue.increment(quantity),
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                  });
                  logger.info(`✅ Stock restored: +${quantity} for dish ${dishId} (order cancelled)`);
                } catch (stockError) {
                  logger.error(`❌ Failed to restore stock for dish ${dishId}:`, stockError);
                }
              }
            }
            break;
          }

          default:
            return null;
        }

        if (!recipientId) {
          logger.log("❌ No recipient ID for order notification");
          return null;
        }

        // Get recipient data
        const recipientDoc = await admin
            .firestore()
            .collection("users")
            .doc(recipientId)
            .get();

        if (!recipientDoc.exists) {
          logger.log("❌ Recipient document doesn't exist");
          return null;
        }

        const recipientData = recipientDoc.data() || {};

        // Check notification settings
        if (recipientData.notificationSettings?.orders === false) {
          logger.log("⏭️ Skipping: Recipient has order notifications disabled");
          return null;
        }

        const fcmToken = recipientData.fcmToken;
        if (!fcmToken) {
          logger.log("❌ No FCM token for recipient");
          return null;
        }

        const message = {
          token: fcmToken,
          notification: {
            title: `${emoji} ${title}`,
            body: body,
          },
          data: {
            type: notificationType,
            orderId: event.params.orderId,
            status: status,
            dishName: dishName,
            timestamp: new Date().toISOString(),
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            navigationRoute: "/orders",
            screen: "order_status",
          },
          android: {
            priority: "high",
            notification: {
              channelId: "odlua_channel",
              sound: "default",
              clickAction: "FLUTTER_NOTIFICATION_CLICK",
              icon: "ic_launcher",
              color: "#197533",
              tag: `order_${event.params.orderId}`,
            },
          },
          apns: {
            headers: {
              "apns-priority": "10",
              "apns-push-type": "alert",
            },
            payload: {
              aps: {
                "alert": {
                  title: `${emoji} ${title}`,
                  body: body,
                },
                "sound": "default",
                "badge": 1,
                "content-available": 1,
                "mutable-content": 1,
              },
            },
          },
        };

        const response = await admin.messaging().send(message);
        logger.info(`✅ Order notification sent`, {
          messageId: response,
          orderId: event.params.orderId,
          status: status,
          recipient: recipientId,
        });

        return null;
      } catch (error) {
        logger.error("❌ sendOrderNotification error:", error);
        return null;
      }
    },
);

// --------------------------
// 🔄 Token Cleanup Function
// --------------------------
exports.cleanupInvalidTokens = onRequest(async (req, res) => {
  try {
    // This function can be called periodically to clean up invalid tokens
    const usersSnapshot = await admin
        .firestore()
        .collection("users")
        .where("fcmToken", "!=", null)
        .get();

    let cleanedCount = 0;

    for (const doc of usersSnapshot.docs) {
      const userData = doc.data();
      const fcmToken = userData.fcmToken;

      if (fcmToken) {
        try {
          // Test if token is valid by sending a silent notification
          await admin.messaging().send(
              {
                token: fcmToken,
                data: { type: "token_validation" },
              },
              true,
          ); // dryRun mode - doesn't actually send
        } catch (error) {
          if (
            error.code === "messaging/invalid-registration-token" ||
            error.code === "messaging/registration-token-not-registered"
          ) {
            // Remove invalid token
            await doc.ref.update({
              fcmToken: admin.firestore.FieldValue.delete(),
              fcmTokens: admin.firestore.FieldValue.arrayRemove(fcmToken),
            });
            cleanedCount++;
            logger.info(`🧹 Cleaned invalid token for user: ${doc.id}`);
          }
        }
      }
    }

    res.status(200).json({
      success: true,
      message: `Cleaned ${cleanedCount} invalid tokens`,
      cleanedCount: cleanedCount,
    });
  } catch (error) {
    logger.error("❌ Token cleanup error:", error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

// --------------------------
// 🗑️ Deactivate Expired Dishes
// --------------------------
exports.deactivateExpiredDishes = onSchedule(
  'every 1 hours',
  async (event) => {
    try {
      const now = new Date();
      const expiredSnapshot = await admin
          .firestore()
          .collection('dishes')
          .where('isAvailable', '==', true)
          .where('expirationDate', '<', now)
          .get();

      if (expiredSnapshot.empty) {
        logger.info('No expired dishes found to deactivate');
        return;
      }

      const batch = admin.firestore().batch();
      expiredSnapshot.docs.forEach((doc) => {
        batch.update(doc.ref, {
          isAvailable: false,
          autoDeactivatedAt: now,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      await batch.commit();
      logger.info(`✅ Deactivated ${expiredSnapshot.docs.length} expired dishes`);
    } catch (error) {
      logger.error('❌ Error deactivating expired dishes:', error);
    }
  },
);

// --------------------------
// 🗺️ Location Data Migration - Phase 2A
// --------------------------

// --------------------------
// 🔄 Daily Quantity Refresh for Dishes
// Resets availableStock to dailyQuantity for dishes with isDaily == true
// Runs once per day at midnight UTC
// --------------------------
exports.refreshDailyDishes = onSchedule(
  'every day 00:00',
  async (event) => {
    try {
      const now = admin.firestore.Timestamp.now();
      const today = new Date().toISOString().slice(0, 10); // yyyy-MM-dd

      const dailyDishesSnapshot = await admin
          .firestore()
          .collection('dishes')
          .where('isDaily', '==', true)
          .where('isAvailable', '==', true)
          .get();

      if (dailyDishesSnapshot.empty) {
        logger.info('🔄 No daily dishes found to refresh');
        return;
      }

      const batch = admin.firestore().batch();
      let refreshed = 0;

      dailyDishesSnapshot.docs.forEach((doc) => {
        const data = doc.data();
        const dailyQuantity = data.dailyQuantity || 0;
        const lastRefreshDate = data.lastRefreshDate || '';

        // Skip if already refreshed today
        if (lastRefreshDate === today || dailyQuantity <= 0) return;

        // Check if not expired
        if (data.expirationDate && data.expirationDate.toDate() < new Date()) {
          return;
        }

        batch.update(doc.ref, {
          availableStock: dailyQuantity,
          stock: dailyQuantity,
          reservedCount: 0,
          isAvailable: true,
          lastRefreshDate: today,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        refreshed++;
      });

      if (refreshed > 0) {
        await batch.commit();
        logger.info(`🔄 ✅ Refreshed stock for ${refreshed} daily dishes`);
      } else {
        logger.info('🔄 All daily dishes already refreshed today');
      }
    } catch (error) {
      logger.error('🔄 ❌ Error refreshing daily dishes:', error);
    }
  },
);

// --------------------------
// 🗺️ Location Data Migration - Phase 2A
// --------------------------
exports.migrateLocationData = onRequest(async (req, res) => {
  try {
    logger.info("🚀 Starting location data migration...");

    let usersMigrated = 0;
    let usersSkipped = 0;
    let usersFailed = 0;
    let dishesMigrated = 0;
    let dishesSkipped = 0;
    let dishesFailed = 0;

    // Migrate Users Collection
    logger.info("📍 Migrating users collection...");
    // Support optional limit query param for dry-runs: ?limit=10
    const limitParam =
      parseInt(req.query.limit || req.body?.limit || "0", 10) || 0;
    const usersQuery =
      limitParam > 0 ?
        admin.firestore().collection("users").limit(limitParam) :
        admin.firestore().collection("users");
    const usersSnapshot = await usersQuery.get();

    for (const doc of usersSnapshot.docs) {
      try {
        const userData = doc.data();

        // Check if already migrated
        if (userData.city && userData.latitude && userData.longitude) {
          usersSkipped++;
          continue;
        }

        // Check if has old location data
        if (
          userData.location &&
          userData.location._latitude &&
          userData.location._longitude
        ) {
          // Old format: location: GeoPoint
          const updateData = {
            latitude: userData.location._latitude,
            longitude: userData.location._longitude,
            // Try to get city/postal from other fields if they exist
            ...(userData.cityName && { city: userData.cityName }),
            ...(userData.postalCode && { postalCode: userData.postalCode }),
            ...(userData.country && { country: userData.country }),
            // Keep old location field for 30 days for backwards compatibility
            locationMigrated: true,
            locationMigratedAt: new Date().toISOString(),
          };

          await doc.ref.update(updateData);
          usersMigrated++;
          logger.info(`✅ Migrated user: ${doc.id}`);
        } else {
          usersSkipped++;
        }
      } catch (error) {
        usersFailed++;
        logger.error(`❌ Failed to migrate user ${doc.id}:`, error);
      }
    }

    // Migrate Dishes Collection
    logger.info("🍽️ Migrating dishes collection...");
    const dishesQuery =
      limitParam > 0 ?
        admin.firestore().collection("dishes").limit(limitParam) :
        admin.firestore().collection("dishes");
    const dishesSnapshot = await dishesQuery.get();

    for (const doc of dishesSnapshot.docs) {
      try {
        const dishData = doc.data();

        // Check if already migrated
        if (dishData.city && dishData.latitude && dishData.longitude) {
          dishesSkipped++;
          continue;
        }

        // Check if has old location data
        if (
          dishData.location &&
          dishData.location._latitude &&
          dishData.location._longitude
        ) {
          const updateData = {
            latitude: dishData.location._latitude,
            longitude: dishData.location._longitude,
            ...(dishData.cityName && { city: dishData.cityName }),
            ...(dishData.postalCode && { postalCode: dishData.postalCode }),
            ...(dishData.country && { country: dishData.country }),
            locationMigrated: true,
            locationMigratedAt: new Date().toISOString(),
          };

          await doc.ref.update(updateData);
          dishesMigrated++;
          logger.info(`✅ Migrated dish: ${doc.id}`);
        } else {
          dishesSkipped++;
        }
      } catch (error) {
        dishesFailed++;
        logger.error(`❌ Failed to migrate dish ${doc.id}:`, error);
      }
    }

    const summary = {
      success: true,
      timestamp: new Date().toISOString(),
      users: {
        total: usersSnapshot.size,
        migrated: usersMigrated,
        skipped: usersSkipped,
        failed: usersFailed,
      },
      dishes: {
        total: dishesSnapshot.size,
        migrated: dishesMigrated,
        skipped: dishesSkipped,
        failed: dishesFailed,
      },
    };

    logger.info("✅ Location migration completed", summary);
    res.status(200).json(summary);
  } catch (error) {
    logger.error("❌ Location migration error:", error);
    res.status(500).json({
      success: false,
      error: error.message,
      timestamp: new Date().toISOString(),
    });
  }
});

// --------------------------
// 🧹 Cleanup Old Location Fields - Run after 30 days
// --------------------------
exports.cleanupOldLocationFields = onRequest(async (req, res) => {
  try {
    logger.info("🧹 Starting old location field cleanup...");

    let usersCleanedCount = 0;
    let dishesCleanedCount = 0;

    // Only cleanup documents migrated more than 30 days ago
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    // Cleanup Users
    const usersSnapshot = await admin
        .firestore()
        .collection("users")
        .where("locationMigrated", "==", true)
        .get();

    for (const doc of usersSnapshot.docs) {
      const userData = doc.data();
      if (userData.locationMigratedAt) {
        const migratedDate = new Date(userData.locationMigratedAt);
        if (migratedDate < thirtyDaysAgo) {
          await doc.ref.update({
            location: admin.firestore.FieldValue.delete(),
          });
          usersCleanedCount++;
        }
      }
    }

    // Cleanup Dishes
    const dishesSnapshot = await admin
        .firestore()
        .collection("dishes")
        .where("locationMigrated", "==", true)
        .get();

    for (const doc of dishesSnapshot.docs) {
      const dishData = doc.data();
      if (dishData.locationMigratedAt) {
        const migratedDate = new Date(dishData.locationMigratedAt);
        if (migratedDate < thirtyDaysAgo) {
          await doc.ref.update({
            location: admin.firestore.FieldValue.delete(),
          });
          dishesCleanedCount++;
        }
      }
    }

    const summary = {
      success: true,
      timestamp: new Date().toISOString(),
      usersCleanedCount,
      dishesCleanedCount,
    };

    logger.info("✅ Old location fields cleaned up", summary);
    res.status(200).json(summary);
  } catch (error) {
    logger.error("❌ Cleanup error:", error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

// --------------------------
// 📍 PHASE 2B: ORDER LOCATION CREATION
// --------------------------
// Automatically creates OrderLocation document when order is confirmed
// Calculates distance and travel time between buyer and chef
exports.createOrderLocation = onDocumentWritten(
    "orders/{orderId}",
    async (event) => {
      const orderData = event.data?.after?.data();
      const previousData = event.data?.before?.data();

      // Only trigger on order confirmation
      if (!orderData || orderData.status !== "confirmed") {
        return null;
      }

      // Prevent duplicate execution
      if (previousData && previousData.status === "confirmed") {
        logger.info("Order already confirmed, skipping");
        return null;
      }

      const orderId = event.params.orderId;
      logger.info(`📍 Creating OrderLocation for order: ${orderId}`);

      try {
      // Get buyer's address
        const buyerDoc = await admin
            .firestore()
            .collection("users")
            .doc(orderData.customerId)
            .get();

        if (!buyerDoc.exists) {
          logger.error(`❌ Buyer not found: ${orderData.customerId}`);
          return null;
        }

        const buyerData = buyerDoc.data();
        const buyerAddress =
        buyerData.exactLocation ||
        buyerData.defaultAddress ||
        buyerData.location;

        if (!buyerAddress) {
          logger.error(
              `❌ Buyer address not found for user: ${orderData.customerId}`,
          );
          return null;
        }

        // Get chef's address from dish
        const dishDoc = await admin
            .firestore()
            .collection("dishes")
            .doc(orderData.dishId)
            .get();

        if (!dishDoc.exists) {
          logger.error(`❌ Dish not found: ${orderData.dishId}`);
          return null;
        }

        const dishData = dishDoc.data();
        const chefAddress = dishData.exactLocation || dishData.location;

        if (!chefAddress) {
          logger.error(`❌ Chef address not found for dish: ${orderData.dishId}`);
          return null;
        }

        // Calculate distance using Haversine formula
        const distance = calculateDistance(
            buyerAddress.coordinates || buyerAddress,
            chefAddress.coordinates || chefAddress,
        );

        // Estimate travel time (assume 30 km/h urban speed)
        const travelTimeMinutes = (distance / 30) * 60;

        // Create OrderLocation document
        const orderLocation = {
          orderId: orderId,
          buyerId: orderData.customerId,
          chefId: orderData.chefId || dishData.chefId,
          buyerAddress: normalizeAddress(buyerAddress),
          buyerPhone: buyerData.phone || null,
          buyerDeliveryInstructions: buyerAddress.additionalInfo || null,
          chefAddress: normalizeAddress(chefAddress),
          chefPhone: buyerData.phone || null,
          chefLocationInstructions: chefAddress.additionalInfo || null,
          distanceKm: distance,
          estimatedTravelTimeMinutes: travelTimeMinutes,
          deliveryMethod: orderData.deliveryMethod || "delivery",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          status: "pending",
          buyerLocationShared: true,
          chefLocationShared: true,
          locationSharedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        await admin
            .firestore()
            .collection("orderLocations")
            .doc(orderId)
            .set(orderLocation);

        logger.info(
            `✅ OrderLocation created for order: ${orderId}, distance: ${distance.toFixed(
                2,
            )}km`,
        );
        return orderLocation;
      } catch (error) {
        logger.error(`❌ Error creating OrderLocation: ${error.message}`);
        return null;
      }
    },
);

// --------------------------
// 📍 VALIDATE DELIVERY FEASIBILITY
// --------------------------
// Callable function to check if delivery is feasible before order placement
exports.validateDeliveryFeasibility = onCall(async (request) => {
  const { dishId, userId } = request.data;

  if (!dishId || !userId) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "dishId and userId are required",
    );
  }

  try {
    // Get buyer's location
    const userDoc = await admin
        .firestore()
        .collection("users")
        .doc(userId)
        .get();

    if (!userDoc.exists) {
      throw new functions.https.HttpsError("not-found", "User not found");
    }

    const userData = userDoc.data();
    const buyerLocation =
      userData.exactLocation || userData.defaultAddress || userData.location;

    if (!buyerLocation) {
      throw new functions.https.HttpsError(
          "failed-precondition",
          "User location not set",
      );
    }

    // Get dish location
    const dishDoc = await admin
        .firestore()
        .collection("dishes")
        .doc(dishId)
        .get();

    if (!dishDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Dish not found");
    }

    const dishData = dishDoc.data();
    const dishLocation = dishData.exactLocation || dishData.location;

    if (!dishLocation) {
      throw new functions.https.HttpsError(
          "failed-precondition",
          "Dish location not set",
      );
    }

    // Calculate distance
    const distance = calculateDistance(
        buyerLocation.coordinates || buyerLocation,
        dishLocation.coordinates || dishLocation,
    );

    // Define feasibility thresholds
    const maxDeliveryDistance = 50; // km
    const optimalDistance = 10; // km

    let isFeasible = true;
    let message = "";
    let category = "";

    if (distance <= optimalDistance) {
      message = "Great! This dish is nearby";
      category = "optimal";
    } else if (distance <= maxDeliveryDistance) {
      message = "Delivery available (longer distance)";
      category = "acceptable";
    } else {
      isFeasible = false;
      message = `Too far for delivery (${distance.toFixed(1)} km)`;
      category = "too_far";
    }

    const travelTimeMinutes = (distance / 30) * 60;

    return {
      isFeasible,
      message,
      category,
      distanceKm: distance,
      estimatedTravelTimeMinutes: travelTimeMinutes,
      distanceFormatted:
        distance < 1 ?
          `${(distance * 1000).toFixed(0)} m` :
          `${distance.toFixed(1)} km`,
      travelTimeFormatted:
        travelTimeMinutes < 60 ?
          `${travelTimeMinutes.toFixed(0)} min` :
          `${(travelTimeMinutes / 60).toFixed(1)} h`,
    };
  } catch (error) {
    logger.error(`❌ Error validating delivery: ${error.message}`);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

// --------------------------
// 🛠️ HELPER FUNCTIONS
// --------------------------

/**
 * Calculate distance between two points using Haversine formula
 * @param {Object} point1 - {latitude, longitude} or GeoPoint
 * @param {Object} point2 - {latitude, longitude} or GeoPoint
 * @return {number} Distance in kilometers
 */
function calculateDistance(point1, point2) {
  // Extract coordinates
  const lat1 = point1.latitude || point1._latitude || point1.lat || 0;
  const lng1 = point1.longitude || point1._longitude || point1.lng || 0;
  const lat2 = point2.latitude || point2._latitude || point2.lat || 0;
  const lng2 = point2.longitude || point2._longitude || point2.lng || 0;

  const earthRadiusKm = 6371;

  const dLat = degreesToRadians(lat2 - lat1);
  const dLng = degreesToRadians(lng2 - lng1);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(degreesToRadians(lat1)) *
      Math.cos(degreesToRadians(lat2)) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return earthRadiusKm * c;
}

/**
 * Convert degrees to radians
 * @param {number} degrees
 * @return {number} radians
 */
function degreesToRadians(degrees) {
  return degrees * (Math.PI / 180);
}

/**
 * Normalize address object for storage
 * @param {Object} address - Address data
 * @return {Object} Normalized address
 */
function normalizeAddress(address) {
  if (!address) return null;

  // If it's already a structured address
  if (address.city && address.streetName) {
    return address;
  }

  // If it's a GeoPoint or coordinates object
  if (address.latitude || address._latitude) {
    return {
      coordinates: new admin.firestore.GeoPoint(
          address.latitude || address._latitude || 0,
          address.longitude || address._longitude || 0,
      ),
      city: address.city || "",
      streetName: address.street || address.streetName || "",
      buildingNumber: address.buildingNumber || "",
      formattedAddress:
        address.formattedAddress || address.formatted || "Address",
    };
  }

  // Fallback
  return address;
}

// ---------------------------------------------------
// 📊 Update Chef Order Statistics (Exclude Cancelled Orders)
/**
 * Update chef statistics when order status changes
 * Ensures cancelled orders don't count toward completion stats
 */
// ---------------------------------------------------
// 📊 Update Chef Order Statistics (Exclude Cancelled Orders)
// ---------------------------------------------------

/**
 * Recalculates statistics for a given chef
 * @param {string} chefId - The ID of the chef to update
 */
async function recalculateChefStats(chefId) {
  if (!chefId) {
    logger.warn("Order has no chefId, skipping stats update");
    return;
  }

  try {
    // Query all orders for this chef
    const ordersSnapshot = await admin
        .firestore()
        .collection("orders")
        .where("chefId", "==", chefId)
        .get();

    let totalOrders = 0;
    let completedOrders = 0;
    let pendingOrders = 0;
    let preparingOrders = 0;
    let readyOrders = 0;

    ordersSnapshot.forEach((doc) => {
      const orderData = doc.data();
      const status = orderData.status;

      // Don't count cancelled, declined, or expired orders in the total
      if (!["cancelled", "declined", "expired"].includes(status)) {
        totalOrders++;

        switch (status) {
          case "completed":
            completedOrders++;
            break;
          case "pending":
          case "paid": // Count paid as pending for stats
            pendingOrders++;
            break;
          case "preparing":
            preparingOrders++;
            break;
          case "ready":
            readyOrders++;
            break;
        }
      }
    });

    // Calculate completion rate (only from non-cancelled orders)
    const completionRate =
      totalOrders > 0 ? Math.round((completedOrders / totalOrders) * 100) : 0;

    // Update chef user document
    await admin.firestore().collection("users").doc(chefId).update({
      totalOrders: totalOrders,
      completedOrders: completedOrders,
      pendingOrders: pendingOrders,
      preparingOrders: preparingOrders,
      readyOrders: readyOrders,
      completionRate: completionRate,
      statsLastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info(
        `✅ Updated stats for chef ${chefId}: ` +
        `Total: ${totalOrders}, Completed: ${completedOrders}, ` +
        `Completion Rate: ${completionRate}%`,
    );
  } catch (error) {
    logger.error(`Error updating chef stats: ${error}`);
  }
}

/**
 * Recalculates total earnings for a given chef
 * @param {string} chefId - The ID of the chef to update
 */
async function recalculateChefEarnings(chefId) {
  if (!chefId) return;
  try {
    const completedOrdersSnapshot = await admin.firestore()
        .collection("orders")
        .where("chefId", "==", chefId)
        .where("status", "==", "completed")
        .get();

    let totalEarnings = 0;
    completedOrdersSnapshot.forEach((doc) => {
      totalEarnings += (doc.data().totalPrice || 0);
    });

    await admin.firestore().collection("users").doc(chefId).update({
      totalEarnings: totalEarnings,
      earningsLastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info(`✅ Updated earnings for chef ${chefId}: ${totalEarnings}`);
  } catch (error) {
    logger.error(`❌ Error recalculating chef earnings: ${error}`);
  }
}

/**
 * Trigger update on order update
 */
exports.updateChefOrderStatsOnUpdate = onDocumentUpdated(
    "orders/{orderId}",
    async (event) => {
      const beforeData = event.data.before.data();
      const afterData = event.data.after.data();

      // Only proceed if status changed
      if (!beforeData || !afterData || beforeData.status === afterData.status) {
        return null;
      }

      await recalculateChefStats(afterData.chefId);
      return null;
    },
);

/**
 * Trigger update on order creation
 */
exports.updateChefOrderStatsOnCreate = onDocumentCreated(
    "orders/{orderId}",
    async (event) => {
      const orderData = event.data.data();
      if (!orderData) return null;

      await recalculateChefStats(orderData.chefId);
      return null;
    },
);

// ---------------------------------------------------
// ⭐️ Ratings & Reviews Aggregation
// ---------------------------------------------------

/**
 * Recalculates the average rating for a dish.
 * @param {string} dishId - The ID of the dish to recalculate rating for
 */
async function recalculateDishRating(dishId) {
  if (!dishId) return;
  try {
    const reviewsSnapshot = await admin.firestore()
        .collection("reviews")
        .where("dishId", "==", dishId)
        .get();

    let totalRating = 0;
    const reviewCount = reviewsSnapshot.size;

    reviewsSnapshot.forEach((doc) => {
      totalRating += (doc.data().rating || 0);
    });

    const averageRating = reviewCount > 0 ? (totalRating / reviewCount) : 0;

    await admin.firestore().collection("dishes").doc(dishId).update({
      ratingsCount: reviewCount,
      ratingsAverage: averageRating,
    });

    logger.info(`✅ Aggregated rating for dish ${dishId}: ${averageRating} (${reviewCount} reviews)`);
  } catch (error) {
    logger.error(`❌ Error recalculating dish rating: ${error}`);
  }
}

/**
 * Recalculates the average rating for a chef.
 * @param {string} chefId - The ID of the chef to recalculate rating for
 */
async function recalculateChefRating(chefId) {
  if (!chefId) return;
  try {
    const reviewsSnapshot = await admin.firestore()
        .collection("reviews")
        .where("chefId", "==", chefId)
        .get();

    let totalRating = 0;
    const reviewCount = reviewsSnapshot.size;

    reviewsSnapshot.forEach((doc) => {
      totalRating += (doc.data().rating || 0);
    });

    const averageRating = reviewCount > 0 ? (totalRating / reviewCount) : 0;

    await admin.firestore().collection("users").doc(chefId).update({
      reviewCount: reviewCount,
      rating: averageRating,
    });

    logger.info(`✅ Aggregated rating for chef ${chefId}: ${averageRating} (${reviewCount} reviews)`);
  } catch (error) {
    logger.error(`❌ Error recalculating chef rating: ${error}`);
  }
}

/**
 * Trigger aggregation when a new review is created.
 */
exports.onReviewCreated = onDocumentCreated(
    "reviews/{reviewId}",
    async (event) => {
      const reviewData = event.data.data();
      if (!reviewData) return null;

      const { dishId, chefId } = reviewData;

      await Promise.all([
        recalculateDishRating(dishId),
        recalculateChefRating(chefId),
      ]);

      return null;
    },
);

// ========================================
// 🗑️ AUTO-DELETE EXPIRED DISHES
// ========================================

/**
 * Scheduled function to automatically delete expired dishes.
 * Runs every hour to clean up dishes that have passed their expiration date.
 * Schedule: every 1 hour
 */
exports.deleteExpiredDishes = onSchedule("every 60 minutes", async (event) => {
  try {
    logger.info("🗑️ Starting expired dishes cleanup...");

    const now = admin.firestore.Timestamp.now();

    // Query for dishes where expirationDate has passed
    const expiredDishesSnapshot = await admin.firestore()
        .collection("dishes")
        .where("expirationDate", "<=", now)
        .where("status", "==", "active") // Only delete active dishes
        .get();

    if (expiredDishesSnapshot.empty) {
      logger.info("✅ No expired dishes found");
      return null;
    }

    const batch = admin.firestore().batch();
    let deletedCount = 0;

    expiredDishesSnapshot.forEach((doc) => {
      const dishData = doc.data();
      logger.info(`🗑️ Deleting expired dish: ${doc.id} - ${dishData.title || "Unknown"}`);

      // Update status to 'expired' instead of hard deleting
      // This preserves dish data for order history
      batch.update(doc.ref, {
        status: "expired",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      deletedCount++;
    });

    await batch.commit();
    logger.info(`✅ Successfully marked ${deletedCount} dishes as expired`);

    return null;
  } catch (error) {
    logger.error(`❌ Error deleting expired dishes: ${error.message}`);
    throw error;
  }
});

/**
 * Manual callable function to delete a specific expired dish
 */
exports.deleteExpiredDish = onCall(async (request) => {
  try {
    const { dishId } = request.data;

    if (!dishId) {
      throw new Error("Dish ID is required");
    }

    const dishDoc = await admin.firestore()
        .collection("dishes")
        .doc(dishId)
        .get();

    if (!dishDoc.exists) {
      throw new Error("Dish not found");
    }

    const dishData = dishDoc.data();
    const now = admin.firestore.Timestamp.now();

    // Check if dish is actually expired
    if (dishData.expirationDate && dishData.expirationDate <= now) {
      await dishDoc.ref.update({
        status: "expired",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      logger.info(`✅ Marked dish ${dishId} as expired`);
      return { success: true, message: "Dish marked as expired" };
    } else {
      throw new Error("Dish has not expired yet");
    }
  } catch (error) {
    logger.error(`❌ Error in deleteExpiredDish: ${error.message}`);
    throw new Error(error.message);
  }
});

// --------------------------
// 🍽 RESERVATION STOCK VALIDATION - SERVER-SIDE SAFEGUARD
// --------------------------
/**
 * Triggered when a reservation is created.
 * Double-checks that dish stock is consistent and rolls back if stock would go negative.
 * This is a server-side safeguard to prevent race conditions and data corruption.
 */
exports.onReservationCreate = onDocumentCreated(
    "reservations/{reservationId}",
    async (event) => {
      try {
        const reservationData = event.data.data();
        const reservationId = event.params.reservationId;

        if (!reservationData) {
          logger.log("❌ No reservation data exists");
          return null;
        }

        const { dishId, quantity, status } = reservationData;

        // Only process pending reservations (ignore cancelled/declined ones)
        if (status !== "pending") {
          logger.log(`⏭️ Skipping non-pending reservation: ${status}`);
          return null;
        }

        if (!dishId || !quantity) {
          logger.log("❌ Missing dishId or quantity in reservation");
          return null;
        }

        logger.info(`🔍 Validating stock for reservation ${reservationId}, dish ${dishId}`);

        // Get dish document
        const dishDoc = await admin.firestore().collection("dishes").doc(dishId).get();
        if (!dishDoc.exists) {
          logger.error(`❌ Dish ${dishId} not found for reservation ${reservationId}`);
          // Could roll back reservation here if needed
          return null;
        }

        const dishData = dishDoc.data();
        
        // CRITICAL: Handle missing availableStock field by falling back to stock
        // This ensures compatibility with older dish documents
        let currentStock = 0;
        if (dishData.availableStock !== undefined && dishData.availableStock !== null) {
          currentStock = dishData.availableStock;
        } else if (dishData.stock !== undefined && dishData.stock !== null) {
          currentStock = dishData.stock;
        } else if (dishData.quantityAvailable !== undefined && dishData.quantityAvailable !== null) {
          currentStock = dishData.quantityAvailable;
        } else {
          logger.warn(`⚠️ Dish ${dishId} has no stock field, skipping validation`);
          return null;
        }

        // Check if stock went negative (shouldn't happen with transaction, but catch edge cases)
        if (currentStock < 0) {
          logger.error(`❌ Stock negative for dish ${dishId}: ${currentStock}`);
          
          // Roll back: Delete the reservation and restore stock
          try {
            await admin.firestore().collection("reservations").doc(reservationId).delete();
            logger.info(`🗑️ Deleted invalid reservation ${reservationId}`);
            
            // Restore stock to previous value (we need to calculate what it was before)
            // Since we don't have the old value, we'll increment by the reserved quantity
            await admin.firestore().collection("dishes").doc(dishId).update({
              availableStock: admin.firestore.FieldValue.increment(quantity),
              stock: admin.firestore.FieldValue.increment(quantity),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            logger.info(`✅ Restored stock for dish ${dishId} (+${quantity})`);
          } catch (rollbackError) {
            logger.error(`❌ Failed to roll back invalid reservation ${reservationId}:`, rollbackError);
          }
          
          return null;
        }

        // Additional check: ensure stock is reasonable (not too low compared to quantity)
        // This helps detect partial updates or race conditions
        if (currentStock < quantity) {
          logger.warn(`⚠️ Stock ${currentStock} less than reserved quantity ${quantity} for dish ${dishId}`);
          
          // This could happen if multiple reservations were created simultaneously
          // We should cancel this reservation to prevent overselling
          try {
            await admin.firestore().collection("reservations").doc(reservationId).delete();
            logger.info(`🗑️ Deleted overbooked reservation ${reservationId} (stock: ${currentStock}, quantity: ${quantity})`);
            
            // Restore stock (in case it was already decremented)
            await admin.firestore().collection("dishes").doc(dishId).update({
              availableStock: admin.firestore.FieldValue.increment(quantity),
              stock: admin.firestore.FieldValue.increment(quantity),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            logger.info(`✅ Restored stock for dish ${dishId} (+${quantity})`);
          } catch (rollbackError) {
            logger.error(`❌ Failed to roll back overbooked reservation ${reservationId}:`, rollbackError);
          }
          
          return null;
        }

        logger.info(`✅ Stock validation passed for reservation ${reservationId}`);
        return null;
      } catch (error) {
        logger.error(`❌ onReservationCreate error:`, error);
        // Don't throw - allow the reservation to exist even if validation fails
        // The error is logged for investigation
        return null;
      }
    },
);

/**
 * Triggered when a reservation status is updated to 'cancelled'.
 * Verifies stock consistency and sends notification to the other party.
 */
exports.onReservationCancelled = onDocumentUpdated(
    "reservations/{reservationId}",
    async (event) => {
      try {
        const reservationData = event.data.after.data();
        const reservationId = event.params.reservationId;
        
        if (!reservationData) {
          logger.log("❌ No reservation data after update");
          return null;
        }
        
        const { status, dishId, quantity, cancelledBy, cancellationReason, chefId, customerId, dishName, customerName, chefName } = reservationData;
        
        // Only process if status changed to 'cancelled'
        if (status !== "cancelled") {
          logger.log(`⏭️ Skipping non-cancelled status: ${status}`);
          return null;
        }
        
        if (!dishId || !quantity) {
          logger.log("❌ Missing dishId or quantity in cancelled reservation");
          return null;
        }
        
        logger.info(`🔍 Processing cancellation for reservation ${reservationId}, dish ${dishId}`);
        
        // Double-check stock consistency: verify dish.availableStock >= 0 after restoration
        try {
          const dishDoc = await admin.firestore().collection("dishes").doc(dishId).get();
          if (dishDoc.exists) {
            const dishData = dishDoc.data();
            let currentStock = 0;
            
            if (dishData.availableStock !== undefined && dishData.availableStock !== null) {
              currentStock = dishData.availableStock;
            } else if (dishData.stock !== undefined && dishData.stock !== null) {
              currentStock = dishData.stock;
            } else if (dishData.quantityAvailable !== undefined && dishData.quantityAvailable !== null) {
              currentStock = dishData.quantityAvailable;
            }
            
            if (currentStock < 0) {
              logger.error(`❌ Stock negative after cancellation for dish ${dishId}: ${currentStock}`);
              
              // Attempt to fix: restore the quantity again
              await admin.firestore().collection("dishes").doc(dishId).update({
                availableStock: admin.firestore.FieldValue.increment(quantity),
                stock: admin.firestore.FieldValue.increment(quantity),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              });
              logger.info(`✅ Fixed stock for dish ${dishId} (+${quantity})`);
            } else {
              logger.info(`✅ Stock consistency verified for dish ${dishId}: ${currentStock}`);
            }
          } else {
            logger.warn(`⚠️ Dish ${dishId} not found after cancellation`);
          }
        } catch (stockCheckError) {
          logger.error(`❌ Stock check failed for dish ${dishId}:`, stockCheckError);
        }
        
        // Send push notification to the other party
        let recipientId = null;
        let notificationType = null;
        let reasonText = cancellationReason || "";
        
        if (cancelledBy === "chef" && customerId) {
          // Chef cancelled, notify consumer
          recipientId = customerId;
          notificationType = "order_cancelled_by_chef";
        } else if (cancelledBy === "consumer" && chefId) {
          // Consumer cancelled, notify chef
          recipientId = chefId;
          notificationType = "order_cancelled_by_customer";
        }
        
        if (recipientId && notificationType) {
          try {
            // Get recipient's FCM token
            const userDoc = await admin.firestore().collection("users").doc(recipientId).get();
            if (userDoc.exists) {
              const userData = userDoc.data();
              const fcmToken = userData.fcmToken;
              
              if (fcmToken) {
                // Build notification message
                const title = "order_cancelled_title".tr();
                const body = cancelledBy === "chef"
                  ? `order_cancelled_chef_body`.tr({ dishName, reason: reasonText })
                  : `order_cancelled_consumer_body`.tr({ dishName, reason: reasonText });
                
                const message = {
                  token: fcmToken,
                  notification: {
                    title: title,
                    body: body,
                  },
                  data: {
                    notificationType: notificationType,
                    reservationId: reservationId,
                    dishId: dishId,
                    cancelledBy: cancelledBy,
                    click_action: "FLUTTER_NOTIFICATION_CLICK",
                  },
                  android: {
                    priority: "high",
                    notification: {
                      channelId: "odlua_channel",
                      sound: "default",
                      clickAction: "FLUTTER_NOTIFICATION_CLICK",
                      icon: "ic_notification",
                      color: "#FF6B35",
                    },
                  },
                  apns: {
                    payload: {
                      aps: {
                        alert: {
                          title: title,
                          body: body,
                        },
                        sound: "default",
                        badge: 1,
                      },
                    },
                  },
                };
                
                const response = await admin.messaging().send(message);
                logger.info(`✅ Cancellation notification sent to ${recipientId}: ${response}`);
              } else {
                logger.warn(`⚠️ No FCM token for user ${recipientId}`);
              }
            } else {
              logger.warn(`⚠️ User document not found for ${recipientId}`);
            }
          } catch (notificationError) {
            logger.error(`❌ Failed to send cancellation notification:`, notificationError);
          }
        } else {
          logger.warn(`⚠️ Could not determine notification recipient for cancellation`);
        }
        
        return null;
      } catch (error) {
        logger.error(`❌ onReservationCancelled error:`, error);
        return null;
      }
    },
);
