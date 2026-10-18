'use strict';

/** Admin-only cleanup. No caller-supplied UID or document paths are accepted. */
async function deleteAccountData(db, uid, fieldValue) {
  const owner = db.collection('coaching').doc(uid);
  const invites = await db.collection('invites').where('ownerUid', '==', uid).get();
  for (const invite of invites.docs) await invite.ref.delete();

  // Legacy helper records do not contain a helperUid field. An Admin scan is necessary
  // to find forgotten relationships on other people's plans without exposing them to clients.
  // Check the exact path so unrelated collections also named "helpers" are untouched.
  const helpers = await db.collectionGroup('helpers').get();
  for (const helper of helpers.docs) {
    const path = helper.ref.path.split('/');
    if (path.length === 4 && path[0] === 'coaching' && path[3] === uid) {
      await helper.ref.delete();
    }
  }
  const notes = await db.collectionGroup('notes').where('fromUid', '==', uid).get();
  for (const note of notes.docs) {
    const path = note.ref.path.split('/');
    if (path.length === 4 && path[0] === 'coaching') await note.ref.delete();
  }

  const memberBoards = await db.collection('families').where('members', 'array-contains', uid).get();
  const ownedBoards = await db.collection('families').where('ownerUid', '==', uid).get();
  const boards = new Map([...memberBoards.docs, ...ownedBoards.docs].map((board) => [board.ref.path, board]));
  for (const board of boards.values()) {
    await board.ref.collection('board').doc(uid).delete();
    // Transaction preserves simultaneous membership changes and transfers ownership
    // when the departing person created a board that other members still use.
    await db.runTransaction(async (tx) => {
      const latest = await tx.get(board.ref);
      if (!latest.exists) return;
      const data = latest.data();
      const members = data.members.filter((member) => member !== uid);
      if (members.length === 0) tx.delete(board.ref);
      else tx.update(board.ref, {
        members,
        ...(data.ownerUid === uid ? { ownerUid: members[0] } : {}),
        updatedAt: fieldValue.serverTimestamp(),
      });
    });
  }
  await db.recursiveDelete(owner);
  await db.recursiveDelete(db.collection('users').doc(uid));
}

module.exports = { deleteAccountData };
