import { after, before, beforeEach, test } from 'node:test';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import assert from 'node:assert/strict';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { collection, doc, getDoc, getDocs, serverTimestamp, setDoc, updateDoc, deleteDoc, writeBatch } from 'firebase/firestore';
import * as firestore from 'firebase/firestore';
const require = createRequire(import.meta.url);
const makeLoader = require('./load-ts.cjs');
function services(d, uid = 'editor') {
  return makeLoader({ 'firebase/firestore': firestore, '../firebase': { db: d, deviceUid: async () => uid } })('src/lib/session.ts');
}

let env;
const code = 'ABC234';
const session = (ownerId = 'owner') => ({
  ownerId, closed: false, createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  buildings: [{ name: 'A', startFloor: 1, endFloor: 1, defaultUnits: 1, isHorizontal: false }],
  states: [{ units: [], hiddenFloors: [], floorLabels: {} }], personnelStats: [{ selfEvac: 0, rescued: 0, notFound: 0 }],
});
const db = (uid) => uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();
const ref = (d, ...path) => doc(d, 'sessions', code, ...path);
before(async () => {
  env = await initializeTestEnvironment({ projectId: 'demo-safecheckboard', firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') } });
});
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (c) => {
    const d = c.firestore();
    await setDoc(ref(d), session());
    for (const [uid, role] of [['owner', 'owner'], ['editor', 'editor'], ['viewer', 'viewer']]) {
      await setDoc(ref(d, 'members', uid), { role, name: uid, joinedAt: serverTimestamp() });
    }
  });
});
after(async () => { await env?.cleanup(); });
test('unauthenticated clients cannot read or edit sessions', async () => {
  await assertFails(getDoc(ref(db())));
  await assertFails(updateDoc(ref(db()), { title: 'bad' }));
});
test('authenticated nonmembers cannot read sessions or enumerate them', async () => {
  await assertFails(getDoc(ref(db('stranger'))));
  await assertFails(getDocs(collection(db('stranger'), 'sessions')));
  await assertFails(getDocs(collection(db('stranger'), 'sessions', code, 'logs')));
});
test('code holders can join only as viewers', async () => {
  const d = db('new');
  await assertFails(setDoc(ref(d, 'members', 'new'), { role: 'editor', name: '', joinedAt: serverTimestamp() }));
  await assertSucceeds(setDoc(ref(d, 'members', 'new'), { role: 'viewer', name: '', joinedAt: serverTimestamp() }));
  await assertSucceeds(getDoc(ref(d)));
  await assertFails(updateDoc(ref(d, 'members', 'new'), { role: 'editor' }));
});
test('viewer can read but cannot change session or map or briefing', async () => {
  const d = db('viewer');
  await assertSucceeds(getDoc(ref(d)));
  await assertFails(updateDoc(ref(d), { title: 'bad' }));
  await assertFails(setDoc(ref(d, 'secondary', 'map'), { items: [], lines: [] }));
  await assertFails(setDoc(ref(d, 'briefings', 'one'), { title: '', tabType: 0, fields: {} }));
});
test('owner can grant editor access but cannot transfer ownership via membership', async () => {
  const d = db('owner');
  await assertSucceeds(updateDoc(ref(d, 'members', 'viewer'), { role: 'editor' }));
  await assertFails(updateDoc(ref(d, 'members', 'viewer'), { role: 'owner' }));
});
test('editor can update valid state but cannot change owner or close session', async () => {
  const d = db('editor');
  await assertSucceeds(updateDoc(ref(d), { title: 'new', updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(ref(d), { ownerId: 'editor' }));
  await assertFails(updateDoc(ref(d), { closed: true }));
  await assertFails(updateDoc(ref(d), { states: [] }));
});
test('closed sessions reject edits, logs, maps and new memberships; owner can reopen', async () => {
  await assertSucceeds(updateDoc(ref(db('owner')), { closed: true, updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(ref(db('editor')), { title: 'bad' }));
  await assertFails(updateDoc(ref(db('owner')), { title: 'bad' }));
  await assertFails(setDoc(ref(db('editor'), 'secondary', 'map'), { items: [], lines: [] }));
  await assertFails(setDoc(ref(db('new'), 'members', 'new'), { role: 'viewer', name: '', joinedAt: serverTimestamp() }));
  await assertSucceeds(updateDoc(ref(db('owner')), { closed: false, updatedAt: serverTimestamp() }));
});
test('audit records enforce authenticated actor and are append-only', async () => {
  const d = db('editor');
  const log = { at: serverTimestamp(), atMs: Date.now(), actor: {}, actorUid: 'editor', category: 'test', text: 'changed' };
  await assertSucceeds(setDoc(ref(d, 'logs', 'ok'), log));
  await assertFails(setDoc(ref(d, 'logs', 'bad'), { ...log, actorUid: 'owner' }));
  await assertFails(updateDoc(ref(d, 'logs', 'ok'), { text: 'changed again' }));
  await assertFails(deleteDoc(ref(d, 'logs', 'ok')));
});
test('legacy top-level briefings are inaccessible', async () => {
  await assertFails(getDoc(doc(db('editor'), 'briefings', 'legacy')));
});
test('only Google-signed-in users can open a new session', async () => {
  const anon = env.authenticatedContext('anon-1', { firebase: { sign_in_provider: 'anonymous', identities: {} } }).firestore();
  await assertFails(setDoc(doc(anon, 'sessions', 'ANON23'), session('anon-1')));
  // 익명 기기에 Google 을 연결한 경우도 된다
  const linked = env.authenticatedContext('linked-1', { firebase: { sign_in_provider: 'anonymous', identities: { 'google.com': ['123'] } } }).firestore();
  await assertSucceeds(setDoc(doc(linked, 'sessions', 'LINK23'), session('linked-1')));
});
test('new session and owner membership can be created together', async () => {
  const d = env.authenticatedContext('new-owner', { firebase: { sign_in_provider: 'google.com', identities: { 'google.com': ['456'] } } }).firestore();
  const batch = writeBatch(d);
  batch.set(doc(d, 'sessions', 'NEW234'), session('new-owner'));
  batch.set(doc(d, 'sessions', 'NEW234', 'members', 'new-owner'), { role: 'owner', name: '', joinedAt: serverTimestamp() });
  await assertSucceeds(batch.commit());
  await assertSucceeds(getDoc(doc(d, 'sessions', 'NEW234')));
});
test('migrated owner can recover access on another PC before creating membership', async () => {
  await env.withSecurityRulesDisabled((c) => deleteDoc(ref(c.firestore(), 'members', 'owner')));
  const d = db('owner');
  await assertSucceeds(getDoc(ref(d)));
  await assertSucceeds(setDoc(ref(d, 'members', 'owner'), { role: 'owner', name: '', joinedAt: serverTimestamp() }));
  await assertSucceeds(updateDoc(ref(d), { title: 'recovered' }));
});
test('unconfigured legacy sessions remain readable and are preserved', async () => {
  await env.withSecurityRulesDisabled((c) => updateDoc(ref(c.firestore()), { buildings: [], states: [], personnelStats: [] }));
  const d = db('owner');
  await assertSucceeds(getDoc(ref(d)));
  await assertSucceeds(updateDoc(ref(d), { closed: true, updatedAt: serverTimestamp() }));
});
test('editor cannot delete briefings', async () => {
  const d = db('editor');
  await assertSucceeds(setDoc(ref(d, 'briefings', 'one'), { title: 'test', tabType: 0, fields: {} }));
  await assertFails(deleteDoc(ref(d, 'briefings', 'one')));
  await assertSucceeds(deleteDoc(ref(db('owner'), 'briefings', 'one')));
});
test('concurrent report saves preserve independent changes and produce audit records', async () => {
  const d = db('editor');
  const a = services(d);
  const b = services(db('editor'));
  await a.saveField(code, 'incident', { location: 'A', cause: '' }, {});
  await Promise.all([
    a.saveField(code, 'incident', { location: 'B', cause: '' }, { location: 'A', cause: '' }),
    b.saveField(code, 'incident', { location: 'A', cause: 'fire' }, { location: 'A', cause: '' }),
  ]);
  const saved = (await getDoc(ref(d))).data();
  if (saved.incident.location !== 'B' || saved.incident.cause !== 'fire') throw new Error('Concurrent edits lost');
  const logs = await getDocs(collection(d, 'sessions', code, 'logs'));
  if (logs.size !== 3) throw new Error('Missing transactional report audits');
});
test('same report cell conflict leaves committed value intact', async () => {
  const d = db('editor'); const api = services(d);
  await api.saveField(code, 'incident', { location: 'A' }, {});
  await api.saveField(code, 'incident', { location: 'B' }, { location: 'A' });
  await assert.rejects(api.saveField(code, 'incident', { location: 'C' }, { location: 'A' }), /다른 기기/);
  if ((await getDoc(ref(d))).data().incident.location !== 'B') throw new Error('Conflict overwrote value');
});
test('map item additions from independent clients merge transactionally', async () => {
  const d = db('editor'); const api = services(d);
  await Promise.all([
    api.saveMap(code, { items: [{ id: 'a', type: 'text', x: 1, y: 1 }] }, api.EMPTY_MAP),
    services(db('editor')).saveMap(code, { items: [{ id: 'b', type: 'text', x: 2, y: 2 }] }, api.EMPTY_MAP),
  ]);
  const map = (await getDoc(ref(d, 'secondary', 'map'))).data();
  if (map.items.length !== 2) throw new Error('Map addition lost');
});
test('map objects: only the placer and the owner can change or delete them', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    await setDoc(ref(c.firestore(), 'members', 'editor2'), { role: 'editor', name: 'editor2', joinedAt: serverTimestamp() });
  });
  const mine = services(db('editor'));
  await mine.addMapObject(code, 'geo', 'item', { id: 'p1', type: 'pumpTruck', lat: 1, lng: 2 }, '추가');
  const obj = (d) => ref(d, 'mapObjects', 'p1');
  if ((await getDoc(obj(db('editor')))).data().by !== 'editor') throw new Error('placer not recorded');
  // 다른 편집자는 옮기거나 지울 수 없다
  await assertFails(updateDoc(obj(db('editor2')), { lat: 5 }));
  await assertFails(deleteDoc(obj(db('editor2'))));
  // 남의 이름으로 놓을 수도 없다
  await assertFails(setDoc(ref(db('editor2'), 'mapObjects', 'p2'), { space: 'geo', kind: 'item', type: 'x', lat: 1, lng: 1, by: 'editor' }));
  // 놓은 사람이 주인을 바꿀 수 없다
  await assertFails(updateDoc(obj(db('editor')), { by: 'editor2' }));
  // 본인과 관리자는 된다
  await assertSucceeds(updateDoc(obj(db('editor')), { lat: 3 }));
  await assertSucceeds(updateDoc(obj(db('owner')), { lat: 4 }));
  await assertSucceeds(deleteDoc(obj(db('owner'))));
  // 열람자는 아무것도 놓을 수 없다
  await assertFails(setDoc(ref(db('viewer'), 'mapObjects', 'v1'), { space: 'geo', kind: 'item', type: 'x', lat: 1, lng: 1, by: 'viewer' }));
});
test('map objects: board-following auto objects can be kept up to date by any editor', async () => {
  await services(db('editor')).saveMapObjects(code, 'geo', 'item', [{ id: 'auto:fire', type: 'fire', lat: 1, lng: 1, by: null }], [], '따라가기');
  await assertSucceeds(setDoc(ref(db('editor'), 'mapObjects', 'auto:fire'), { space: 'geo', kind: 'item', type: 'fire', lat: 2, lng: 2, by: null }));
  await assertSucceeds(deleteDoc(ref(db('editor'), 'mapObjects', 'auto:fire')));
  // auto 가 아닌데 주인 없는 표시물은 관리자만 만든다 (예전 작전도 옮기기)
  await assertFails(setDoc(ref(db('editor'), 'mapObjects', 'x1'), { space: 'geo', kind: 'item', type: 'x', lat: 1, lng: 1, by: null }));
  await assertSucceeds(setDoc(ref(db('owner'), 'mapObjects', 'x1'), { space: 'geo', kind: 'item', type: 'x', lat: 1, lng: 1, by: null }));
});
test('map background is stored separately and only as a picture', async () => {
  await assertSucceeds(setDoc(ref(db('editor'), 'secondary', 'mapBg'), { bg: 'data:image/jpeg;base64,AAAA' }));
  await assertFails(setDoc(ref(db('editor'), 'secondary', 'mapBg'), { bg: 'x', other: 1 }));
  await assertFails(setDoc(ref(db('viewer'), 'secondary', 'mapBg'), { bg: null }));
  await assertFails(setDoc(ref(db('editor'), 'secondary', 'other'), { items: [], lines: [] }));
});
test('status change and its audit are committed together', async () => {
  const d = db('editor'); const api = services(d);
  await api.mutateSession(code, (s) => { s.title = 'updated'; }, { actor: { agency: 'test', dept: '', role: '' }, category: 'test', text: 'changed', at: Date.now() });
  if ((await getDoc(ref(d))).data().title !== 'updated') throw new Error('State not committed');
  const logs = await getDocs(collection(d, 'sessions', code, 'logs'));
  if (logs.size !== 1 || logs.docs[0].data().actorUid !== 'editor') throw new Error('Audit not committed');
});
