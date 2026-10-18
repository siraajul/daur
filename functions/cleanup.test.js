'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { deleteAccountData } = require('./cleanup');

function fixture({ failDelete = false } = {}) {
  const removed = [];
  const recursive = [];
  const updates = [];
  const ref = (path) => ({
    path,
    collection: (name) => ({ doc: (id) => ref(`${path}/${name}/${id}`) }),
    delete: async () => {
      if (failDelete) throw new Error('offline');
      removed.push(path);
    },
  });
  const snapshot = (paths) => ({ docs: paths.map((path) => ({ ref: ref(path) })) });
  const db = {
    collection(name) {
      return {
        doc: (id) => ref(`${name}/${id}`),
        where: () => ({ get: async () => name === 'invites'
          ? snapshot(['invites/OWNCODE'])
          : snapshot(['families/shared', 'families/alone']) }),
      };
    },
    collectionGroup(name) {
      if (name === 'helpers') return { get: async () => snapshot([
        'coaching/person/helpers/deleting',
        'coaching/person/helpers/other',
        'unrelated/person/helpers/deleting',
      ]) };
      return { where: () => ({ get: async () => snapshot([
        'coaching/person/notes/written-by-deleting',
        'unrelated/person/notes/note',
      ]) }) };
    },
    async runTransaction(fn) {
      await fn({
        get: async (reference) => ({ exists: true, data: () => ({
          ownerUid: 'deleting',
          members: reference.path.endsWith('shared') ? ['deleting', 'remaining'] : ['deleting'],
        }) }),
        delete: (reference) => removed.push(reference.path),
        update: (reference, value) => updates.push([reference.path, value]),
      });
    },
    recursiveDelete: async (reference) => recursive.push(reference.path),
  };
  return { db, removed, recursive, updates };
}

test('cleanup removes legacy relationships and authored notes, preserving other accounts', async () => {
  const f = fixture();
  await deleteAccountData(f.db, 'deleting', { serverTimestamp: () => 'server-time' });
  assert.deepEqual(f.removed, [
    'invites/OWNCODE',
    'coaching/person/helpers/deleting',
    'coaching/person/notes/written-by-deleting',
    'families/shared/board/deleting',
    'families/alone/board/deleting',
    'families/alone',
  ]);
  assert.deepEqual(f.recursive, ['coaching/deleting', 'users/deleting']);
  assert.deepEqual(f.updates, [['families/shared', {
    members: ['remaining'], ownerUid: 'remaining', updatedAt: 'server-time',
  }]]);
});

test('cleanup propagates failure so the caller cannot report successful deletion', async () => {
  const f = fixture({ failDelete: true });
  await assert.rejects(deleteAccountData(f.db, 'deleting', {}), /offline/);
  assert.deepEqual(f.recursive, []);
});

test('cleanup can be retried without relying on local account state', async () => {
  const f = fixture();
  const fieldValue = { serverTimestamp: () => 'server-time' };
  await deleteAccountData(f.db, 'deleting', fieldValue);
  await deleteAccountData(f.db, 'deleting', fieldValue);
  assert.equal(f.recursive.filter((path) => path === 'users/deleting').length, 2);
});
