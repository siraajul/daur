'use strict';

const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { deleteAccountData } = require('./cleanup');
initializeApp();

exports.deleteAccountData = onCall({
  region: 'us-central1',
  timeoutSeconds: 540,
  enforceAppCheck: true,
}, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in before deleting your data.');
  const authenticatedAt = Number(request.auth.token.auth_time);
  const age = Date.now() / 1000 - authenticatedAt;
  if (!Number.isFinite(age) || age < -60 || age > 300) {
    throw new HttpsError('failed-precondition', 'Verify your identity again before deletion.');
  }
  try {
    const db = getFirestore('daur');
    // Retained after deletion: immediately block old tokens and other devices from
    // republishing data during cleanup or after an interrupted request.
    await db.collection('accountDeletions').doc(request.auth.uid).set({
      requestedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    await deleteAccountData(db, request.auth.uid, FieldValue);
    try {
      await getAuth().deleteUser(request.auth.uid);
    } catch (error) {
      if (error.code !== 'auth/user-not-found') throw error;
    }
    return { deleted: true };
  } catch (error) {
    console.error('Account cleanup failed', { uid: request.auth.uid, message: error.message });
    throw new HttpsError('internal', 'Data deletion is incomplete. Stay signed in and retry.');
  }
});
