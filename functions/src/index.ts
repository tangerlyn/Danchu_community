import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

admin.initializeApp();

// 댓글 알림
export const sendCommentNotification = functions.https.onCall(async (request) => {
  const { postAuthorUid, commenterNickname, postTitle, postId } = request.data;
  const token = await getToken(postAuthorUid);
  if (!token) return { success: false };
  return sendMessage(token, '새 댓글', `${commenterNickname}님이 "${postTitle}"에 댓글을 달았습니다.`, {
    type: 'comment',
    postId: postId,
  });
});

// 답글 알림
export const sendReplyNotification = functions.https.onCall(async (request) => {
  const { commentAuthorUid, replierNickname, postId } = request.data;
  const token = await getToken(commentAuthorUid);
  if (!token) return { success: false };
  return sendMessage(token, '새 답글', `${replierNickname}님이 내 댓글에 답글을 남겼습니다.`, {
    type: 'reply',
    postId: postId,
  });
});

// 스레드 답글 알림
export const sendThreadReplyNotification = functions.https.onCall(async (request) => {
  const { notifyUids, replierNickname, postId } = request.data;
  for (const uid of notifyUids) {
    const token = await getToken(uid);
    if (!token) continue;
    await sendMessage(token, '새 답글', `${replierNickname}님이 같은 댓글에 답글을 남겼습니다.`, {
      type: 'reply',
      postId: postId,
    });
  }
  return { success: true };
});

// 모임 참여 알림
export const sendMeetupJoinNotification = functions.https.onCall(async (request) => {
  const { postAuthorUid, joinerNickname, postTitle, postId } = request.data;
  const token = await getToken(postAuthorUid);
  if (!token) return { success: false };
  return sendMessage(token, '모임 참여', `${joinerNickname}님이 "${postTitle}"에 참여했습니다.`, {
    type: 'meetup',
    postId: postId,
  });
});

// 채팅 알림
export const sendChatNotification = functions.https.onCall(async (request) => {
  const { participantUids, senderNickname, message, mutedUids, postId } = request.data;
  for (const uid of participantUids) {
    if (mutedUids?.includes(uid)) continue;
    const token = await getToken(uid);
    if (!token) continue;
    await sendMessage(token, senderNickname, message, {
      type: 'chat',
      postId: postId,
    });
  }
  return { success: true };
});

// 친구 요청 알림
export const sendFriendRequestNotification = functions.https.onCall(async (request) => {
  const { toUid, fromNickname } = request.data;
  const token = await getToken(toUid);
  if (!token) return { success: false };
  return sendMessage(token, '친구 요청', `${fromNickname}님이 친구 요청을 보냈습니다 🐾`, {
    type: 'friend_request',
  });
});

// 친구 수락 알림
export const sendFriendAcceptedNotification = functions.https.onCall(async (request) => {
  const { toUid, fromNickname } = request.data;
  const token = await getToken(toUid);
  if (!token) return { success: false };
  return sendMessage(token, '친구 수락', `${fromNickname}님이 친구 요청을 수락했습니다 🎉`, {
    type: 'friend_accepted',
  });
});

// 1대1 채팅 알림
export const sendDirectChatNotification = functions.https.onCall(async (request) => {
  const { toUid, senderNickname, message } = request.data;
  const token = await getToken(toUid);
  if (!token) return { success: false };
  return sendMessage(token, senderNickname, message, {
    type: 'direct_chat',
  });
});

// 공통: Firestore에서 FCM 토큰 가져오기
async function getToken(uid: string): Promise<string | null> {
  const doc = await admin.firestore().collection('users').doc(uid).get();
  return doc.data()?.fcmToken ?? null;
}

// 공통: FCM 메시지 발송
async function sendMessage(token: string, title: string, body: string, data?: Record<string, string>) {
  try {
    await admin.messaging().send({
      token,
      notification: { title, body },
      data: data ?? {},
      apns: {
        payload: {
          aps: {
            sound: 'default',
          },
        },
      },
    });
    return { success: true };
  } catch (e) {
    console.error('FCM send error:', e);
    return { success: false };
  }
}
