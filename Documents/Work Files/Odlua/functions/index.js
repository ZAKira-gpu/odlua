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
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

// --------------------
// 🔔 HTTP Notification - PRODUCTION READY
// --------------------
exports.sendNotification = onRequest(async (req, res) => {
  // Enhanced CORS handling
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Requested-With");

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
          icon: "ic_notification",
          color: "#FF6B35",
          tag: data?.type || "general",
          ...(imageUrl && { image: imageUrl }),
        },
      },
      apns: {
        payload: {
          aps: {
            "alert": {
              title: title,
              body: body,
            },
            "sound": "default",
            "badge": 1,
            "mutable-content": 1,
          },
        },
        fcmOptions: {
          imageUrl: imageUrl,
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

    if (error.code === "messaging/invalid-registration-token" ||
        error.code === "messaging/registration-token-not-registered") {
      statusCode = 400;
      errorMessage = "Invalid or unregistered FCM token";

      // Optional: Clean up invalid token from user documents
      try {
        const usersSnapshot = await admin.firestore()
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
        const chatDoc = await admin.firestore().collection("chats").doc(chatId).get();
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
        const senderDoc = await admin.firestore()
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
        const recipientDoc = await admin.firestore()
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
        const truncatedBody = messageText.length > 100 ?
        `${messageText.substring(0, 100)}...` : messageText;

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
              icon: "ic_notification",
              color: "#FF6B35",
              tag: `chat_${chatId}`,
            },
          },
          apns: {
            payload: {
              aps: {
                alert: {
                  title: `💬 ${senderName}`,
                  body: truncatedBody,
                },
                sound: "default",
                badge: 1,
                threadId: `chat_${chatId}`,
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
        const recipientDoc = await admin.firestore()
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
          logger.log("⏭️ Skipping: Recipient has reservation notifications disabled");
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
              icon: "ic_notification",
              color: "#FF6B35",
              tag: `reservation_${event.params.reservationId}`,
            },
          },
          apns: {
            payload: {
              aps: {
                alert: {
                  title: `${emoji} ${title}`,
                  body: body,
                },
                sound: "default",
                badge: 1,
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
// 📦 Order Update Trigger - NEW FOR ORDERS
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
          case "reserved":
          case "created":
            recipientId = chefId;
            title = "New Order Received";
            body = `New order for "${dishName}"`;
            notificationType = "order_created";
            emoji = "📦";
            break;

          case "confirmed":
            recipientId = customerId;
            title = "Order Confirmed";
            body = `Your order for "${dishName}" has been confirmed`;
            notificationType = "order_confirmed";
            emoji = "✅";
            break;

          case "ready":
            recipientId = customerId;
            title = "Order Ready for Pickup";
            body = `Your order for "${dishName}" is ready`;
            notificationType = "order_ready";
            emoji = "🎯";
            break;

          case "completed":
            recipientId = chefId;
            title = "Order Completed";
            body = `Order for "${dishName}" has been completed`;
            notificationType = "order_completed";
            emoji = "🎉";
            break;

          case "cancelled": {
            const cancelledBy = afterData.cancelledBy;
            if (cancelledBy === "customer") {
              recipientId = chefId;
              title = "Order Cancelled";
              body = `Customer cancelled order for "${dishName}"`;
            } else {
              recipientId = customerId;
              title = "Order Cancelled";
              body = `Chef cancelled order for "${dishName}"`;
            }
            notificationType = "order_cancelled";
            emoji = "❌";
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
        const recipientDoc = await admin.firestore()
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
              icon: "ic_notification",
              color: "#FF6B35",
              tag: `order_${event.params.orderId}`,
            },
          },
          apns: {
            payload: {
              aps: {
                alert: {
                  title: `${emoji} ${title}`,
                  body: body,
                },
                sound: "default",
                badge: 1,
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
    const usersSnapshot = await admin.firestore()
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
          await admin.messaging().send({
            token: fcmToken,
            data: { type: "token_validation" },
          }, true); // dryRun mode - doesn't actually send
        } catch (error) {
          if (error.code === "messaging/invalid-registration-token" ||
              error.code === "messaging/registration-token-not-registered") {
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
