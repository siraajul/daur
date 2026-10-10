// Firestore rules checks for coaching (invites, helpers, summary, notes, diet chart, workout, cooking):
// who may read and write what. Runs against the local emulator, not the live database.
//
//   d=$(mktemp -d) && cp test/firestore_rules.test.mjs $d/ && (cd $d && npm i -s @firebase/rules-unit-testing@4 firebase@11)
//   echo '{"emulators":{"firestore":{"host":"127.0.0.1","port":8085},"ui":{"enabled":false}}}' > $d/firebase.json
//   (cd $d && RULES=$OLDPWD/firestore.rules npx -y firebase-tools@latest emulators:exec --only firestore \
//      --project daur-rules-test "node firestore_rules.test.mjs")
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, getDocs, collection, addDoc, deleteDoc, serverTimestamp } from 'firebase/firestore';

const env = await initializeTestEnvironment({
  projectId: 'daur-rules-test',
  firestore: { rules: readFileSync(process.env.RULES ?? 'firestore.rules', 'utf8'), host: '127.0.0.1', port: 8085 },
});
const owner = env.authenticatedContext('owner').firestore();
const mom = env.authenticatedContext('mom').firestore();
const trainer = env.authenticatedContext('trainer').firestore();
const stranger = env.authenticatedContext('stranger').firestore();
const now = serverTimestamp();
let pass = 0, fail = 0;
async function t(name, p) { try { await p; pass++; console.log('ok  ', name); } catch (e) { fail++; console.log('FAIL', name, e.message?.slice(0, 120)); } }

await t('owner makes a diet code', assertSucceeds(setDoc(doc(owner, 'invites/DDDDDDDD'), { ownerUid: 'owner', role: 'diet', createdAt: now })));
await t('owner makes a trainer code', assertSucceeds(setDoc(doc(owner, 'invites/TTTTTTTT'), { ownerUid: 'owner', role: 'trainer', createdAt: now })));
await t('stranger cannot make a code in owner\'s name', assertFails(setDoc(doc(stranger, 'invites/SSSSSSSS'), { ownerUid: 'owner', role: 'diet', createdAt: now })));
await t('stranger code for themselves', assertSucceeds(setDoc(doc(stranger, 'invites/XXXXXXXX'), { ownerUid: 'stranger', role: 'trainer', createdAt: now })));
await t('anyone signed in can get a code by id', assertSucceeds(getDoc(doc(mom, 'invites/DDDDDDDD'))));
await t('nobody can list codes', assertFails(getDocs(collection(mom, 'invites'))));
await t('a bad role is refused', assertFails(setDoc(doc(owner, 'invites/BBBBBBBB'), { ownerUid: 'owner', role: 'admin', createdAt: now })));

await t('owner publishes summary', assertSucceeds(setDoc(doc(owner, 'coaching/owner'), { ownerUid: 'owner', name: 'Siraj', data: '{"kcal":1800}', updatedAt: now })));
await t('stranger cannot read the summary', assertFails(getDoc(doc(stranger, 'coaching/owner'))));
await t('mom cannot read before joining', assertFails(getDoc(doc(mom, 'coaching/owner'))));

const join = (db, uid, code, role) => setDoc(doc(db, `coaching/owner/helpers/${uid}`), { name: uid, role, code, joinedAt: now });
await t('mom joins with the diet code', assertSucceeds(join(mom, 'mom', 'DDDDDDDD', 'diet')));
await t('mom cannot claim trainer with the diet code', assertFails(join(mom, 'mom', 'DDDDDDDD', 'trainer')));
await t('trainer cannot join with someone else\'s code', assertFails(join(trainer, 'trainer', 'XXXXXXXX', 'trainer')));
await t('trainer cannot join as someone else', assertFails(join(trainer, 'mom', 'TTTTTTTT', 'trainer')));
await t('trainer joins with the trainer code', assertSucceeds(join(trainer, 'trainer', 'TTTTTTTT', 'trainer')));
await t('a made-up code is refused', assertFails(join(stranger, 'stranger', 'ZZZZZZZZ', 'diet')));

await t('mom reads the summary', assertSucceeds(getDoc(doc(mom, 'coaching/owner'))));
await t('mom cannot overwrite the summary', assertFails(setDoc(doc(mom, 'coaching/owner'), { ownerUid: 'owner', name: 'x', data: '{}', updatedAt: now })));
await t('owner lists helpers', assertSucceeds(getDocs(collection(owner, 'coaching/owner/helpers'))));
await t('mom cannot list helpers', assertFails(getDocs(collection(mom, 'coaching/owner/helpers'))));

const note = (db, from, role, text = 'Less rice tonight') => addDoc(collection(db, 'coaching/owner/notes'), { fromUid: from, name: from, role, text, at: now });
await t('mom writes a note as diet helper', assertSucceeds(note(mom, 'mom', 'diet')));
await t('mom cannot write as trainer', assertFails(note(mom, 'mom', 'trainer')));
await t('mom cannot write as the owner', assertFails(note(mom, 'mom', 'owner')));
await t('mom cannot write in trainer\'s name', assertFails(note(mom, 'trainer', 'diet')));
await t('stranger cannot write a note', assertFails(note(stranger, 'stranger', 'diet')));
await t('owner writes a note', assertSucceeds(note(owner, 'owner', 'owner', 'Thanks Ma')));
await t('an empty note is refused', assertFails(note(owner, 'owner', 'owner', '')));
await t('trainer reads notes', assertSucceeds(getDocs(collection(trainer, 'coaching/owner/notes'))));
await t('stranger cannot read notes', assertFails(getDocs(collection(stranger, 'coaching/owner/notes'))));

const diet = (db, by, extra = {}) => setDoc(doc(db, 'coaching/owner/plan/diet'), { data: '[{"id":"m1"}]', changes: ['Lunch: Beef + rice'], byUid: by, byName: by, at: now, ...extra });
const cook = (db, by, picks = { m4: 1 }, extra = {}) => setDoc(doc(db, 'coaching/owner/plan/cook'), { picks, day: '2026-10-10', byUid: by, byName: by, at: now, ...extra });
await t('trainer writes the diet chart', assertSucceeds(diet(trainer, 'trainer')));
await t('mom cannot write the diet chart', assertFails(diet(mom, 'mom')));
await t('owner writes their own chart', assertSucceeds(diet(owner, 'owner')));
await t('stranger cannot write the chart', assertFails(diet(stranger, 'stranger')));
await t('trainer cannot sign the chart as someone else', assertFails(diet(trainer, 'owner')));
await t('a chart with extra fields is refused', assertFails(diet(trainer, 'trainer', { role: 'admin' })));
await t('mom reads the chart', assertSucceeds(getDoc(doc(mom, 'coaching/owner/plan/diet'))));
await t('stranger cannot read the chart', assertFails(getDoc(doc(stranger, 'coaching/owner/plan/diet'))));
const gym = (db, by, extra = {}) => setDoc(doc(db, 'coaching/owner/plan/gym'), { data: '{"Push":[]}', changes: ['Push: Dips added'], byUid: by, byName: by, at: now, ...extra });
await t('trainer writes the workout', assertSucceeds(gym(trainer, 'trainer')));
await t('mom cannot write the workout', assertFails(gym(mom, 'mom')));
await t('owner writes their own workout', assertSucceeds(gym(owner, 'owner')));
await t('stranger cannot write the workout', assertFails(gym(stranger, 'stranger')));
await t('a workout with extra fields is refused', assertFails(gym(trainer, 'trainer', { role: 'admin' })));
await t('stranger cannot read the workout', assertFails(getDoc(doc(stranger, 'coaching/owner/plan/gym'))));
await t('trainer cannot write an unknown plan doc', assertFails(setDoc(doc(trainer, 'coaching/owner/plan/other'), { data: '{}', changes: [], byUid: 'trainer', byName: 'trainer', at: now })));
await t('mom picks dinner to cook', assertSucceeds(cook(mom, 'mom')));
await t('trainer may pick too', assertSucceeds(cook(trainer, 'trainer', { m2: 0 })));
await t('stranger cannot pick', assertFails(cook(stranger, 'stranger')));
await t('a pick for a meal that does not exist is refused', assertFails(cook(mom, 'mom', { m9: 1 })));
await t('a silly option number is refused', assertFails(cook(mom, 'mom', { m1: 99 })));
await t('mom cannot delete the chart', assertFails(deleteDoc(doc(mom, 'coaching/owner/plan/diet'))));
let notes = [];
await env.withSecurityRulesDisabled(async (c) => { notes = (await getDocs(collection(c.firestore(), 'coaching/owner/notes'))).docs; });
const momNote = notes.find((d) => d.data().fromUid === 'mom').id, ownerNote = notes.find((d) => d.data().fromUid === 'owner').id;
await t('trainer cannot delete mom\'s note', assertFails(deleteDoc(doc(trainer, `coaching/owner/notes/${momNote}`))));
await t('mom cannot delete owner\'s note', assertFails(deleteDoc(doc(mom, `coaching/owner/notes/${ownerNote}`))));
await t('owner deletes mom\'s note', assertSucceeds(deleteDoc(doc(owner, `coaching/owner/notes/${momNote}`))));

await t('owner removes the trainer', assertSucceeds(deleteDoc(doc(owner, 'coaching/owner/helpers/trainer'))));
await t('removed trainer can no longer read', assertFails(getDoc(doc(trainer, 'coaching/owner'))));
await t('mom leaves herself', assertSucceeds(deleteDoc(doc(mom, 'coaching/owner/helpers/mom'))));
await t('stranger cannot delete owner\'s code', assertFails(deleteDoc(doc(stranger, 'invites/DDDDDDDD'))));
await t('owner revokes the code', assertSucceeds(deleteDoc(doc(owner, 'invites/DDDDDDDD'))));
await t('a revoked code no longer lets anyone join', assertFails(join(mom, 'mom', 'DDDDDDDD', 'diet')));

console.log(`\n${pass} passed, ${fail} failed`);
await env.cleanup();
process.exit(fail ? 1 : 0);
