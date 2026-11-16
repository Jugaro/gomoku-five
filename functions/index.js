'use strict';

const {initializeApp} = require('firebase-admin/app');
const {FieldValue, getFirestore} = require('firebase-admin/firestore');
const {getMessaging} = require('firebase-admin/messaging');
const {logger} = require('firebase-functions');
const {onDocumentCreated} = require('firebase-functions/v2/firestore');

initializeApp();

const db = getFirestore();
const messaging = getMessaging();
const invalidTokenCodes = new Set([
  'messaging/invalid-registration-token',
  'messaging/registration-token-not-registered',
]);

async function removeRegistrationIds(playerRef, registrationIds) {
  if (registrationIds.length === 0) return;
  await playerRef.update({
    fcmRegistrationIds: FieldValue.arrayRemove(...registrationIds),
  });
}

exports.notifyInvitationCreated = onDocumentCreated(
  {
    document: 'invitations/{invitationId}',
    region: 'europe-west1',
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      logger.warn('Invitation-created event has no document snapshot');
      return;
    }

    const invitation = snapshot.data() || {};
    const invitationId = event.params.invitationId;
    const toUid = invitation.toUid;
    if (typeof toUid !== 'string' || toUid.length === 0) {
      logger.warn('Invitation has no valid recipient', {invitationId});
      return;
    }

    const playerRef = db.collection('players').doc(toUid);
    const playerSnapshot = await playerRef.get();
    if (!playerSnapshot.exists) {
      logger.warn('Invitation recipient has no private player document', {
        invitationId,
      });
      return;
    }

    const storedIds = playerSnapshot.get('fcmRegistrationIds');
    if (storedIds == null) {
      logger.info('Invitation recipient has no FCM registrations', {
        invitationId,
      });
      return;
    }
    if (!Array.isArray(storedIds)) {
      logger.warn('FCM registrations are not an array', {invitationId});
      return;
    }

    const malformedIds = [];
    const tokens = [];
    const originalIdByToken = new Map();
    for (const storedId of storedIds) {
      if (typeof storedId !== 'string' || storedId.trim().length === 0) {
        malformedIds.push(storedId);
        continue;
      }
      const token = storedId.trim();
      if (!originalIdByToken.has(token)) {
        originalIdByToken.set(token, storedId);
        tokens.push(token);
      }
    }

    const fromNickname =
      typeof invitation.fromNickname === 'string' &&
      invitation.fromNickname.trim().length > 0
        ? invitation.fromNickname.trim()
        : 'Игрок';
    const fromUid =
      typeof invitation.fromUid === 'string' ? invitation.fromUid : '';
    const staleIds = [...malformedIds];
    const failures = new Map();

    for (let offset = 0; offset < tokens.length; offset += 500) {
      const batch = tokens.slice(offset, offset + 500);
      const response = await messaging.sendEachForMulticast({
        tokens: batch,
        notification: {
          title: 'Приглашение в игру',
          body: `${fromNickname} приглашает вас сыграть в «Пять в ряд»`,
        },
        data: {
          type: 'invitation',
          invitationId,
          fromUid,
          fromNickname,
        },
        android: {priority: 'HIGH'},
      });

      response.responses.forEach((result, index) => {
        if (result.success || !result.error) return;
        const code = result.error.code || 'unknown';
        failures.set(code, (failures.get(code) || 0) + 1);
        if (invalidTokenCodes.has(code)) {
          staleIds.push(originalIdByToken.get(batch[index]));
        }
      });

      logger.info('Invitation notification batch processed', {
        invitationId,
        delivered: response.successCount,
        failed: response.failureCount,
      });
    }

    for (const [code, count] of failures) {
      if (!invalidTokenCodes.has(code)) {
        logger.warn('FCM delivery failed', {invitationId, code, count});
      }
    }

    await removeRegistrationIds(playerRef, [...new Set(staleIds)]);
    if (tokens.length === 0) {
      logger.info('Invitation recipient has no usable FCM registrations', {
        invitationId,
      });
    }
  },
);
