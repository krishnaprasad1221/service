const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const CHAT_CHANNEL_ID = 'chat_messages';

exports.onChatMessageCreate = functions.firestore
  .document('chats/{chatId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    if (!message) return null;

    const chatId = context.params.chatId;
    const chatSnap = await admin.firestore().collection('chats').doc(chatId).get();
    if (!chatSnap.exists) return null;

    const chat = chatSnap.data() || {};
    const senderId = message.senderId;
    const customerId = chat.customerId;
    const providerId = chat.providerId;

    if (!senderId || !customerId || !providerId) return null;

    const recipientId = senderId === customerId ? providerId : customerId;
    if (!recipientId || recipientId === senderId) return null;

    const tokensSnap = await admin
      .firestore()
      .collection('users')
      .doc(recipientId)
      .collection('fcmTokens')
      .get();

    if (tokensSnap.empty) return null;

    const tokens = tokensSnap.docs.map((doc) => doc.id);

    let senderName = 'New message';
    try {
      const senderSnap = await admin.firestore().collection('users').doc(senderId).get();
      const sender = senderSnap.data() || {};
      if (sender.username && String(sender.username).trim().length > 0) {
        senderName = String(sender.username).trim();
      }
    } catch (_) {
      // ignore sender name failures
    }

    const text = (message.text || '').toString().trim();
    const body = text.length > 0 ? text : (message.imageUrl ? 'Photo' : 'New message');

    const payload = {
      notification: {
        title: senderName,
        body,
      },
      data: {
        chatId: chatId.toString(),
        senderId: senderId.toString(),
        type: (message.type || 'text').toString(),
        title: senderName.toString(),
        body: body.toString(),
      },
      android: {
        notification: {
          channelId: CHAT_CHANNEL_ID,
        },
      },
    };

    const response = await admin.messaging().sendEachForMulticast({
      tokens,
      ...payload,
    });

    const invalidTokens = [];
    response.responses.forEach((res, idx) => {
      if (res.success) return;
      const code = res.error && res.error.code;
      if (code === 'messaging/registration-token-not-registered' ||
          code === 'messaging/invalid-registration-token') {
        invalidTokens.push(tokens[idx]);
      }
    });

    if (invalidTokens.length > 0) {
      await Promise.all(
        invalidTokens.map((token) =>
          admin.firestore()
            .collection('users')
            .doc(recipientId)
            .collection('fcmTokens')
            .doc(token)
            .delete()
        )
      );
    }

    return null;
  });
