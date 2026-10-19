import { collection, doc, getDoc, onSnapshot, runTransaction, serverTimestamp, updateDoc } from 'firebase/firestore';
import { db, deviceUid } from '../firebase';
import { trackedSave } from './save-status';

export type AccessRole = 'owner' | 'editor' | 'viewer';
export interface Member { uid: string; role: AccessRole; name: string }
export async function joinSession(code: string, name = '') {
  const uid = await deviceUid();
  const ref = doc(db, 'sessions', code, 'members', uid);
  // Ownership is verified by rules; other code holders join as viewers.
  let isOwner = false;
  try { isOwner = (await getDoc(doc(db, 'sessions', code))).data()?.ownerId === uid; }
  catch (e) { if ((e as { code?: string }).code !== 'permission-denied') throw e; }
  await runTransaction(db, async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists()) tx.set(ref, { role: isOwner ? 'owner' : 'viewer', name: name.slice(0, 100), joinedAt: serverTimestamp() });
  });
  return uid;
}
export function subscribeAccess(code: string, cb: (role: AccessRole) => void, error: (e: Error) => void) {
  let cancel = false;
  let stop = () => {};
  deviceUid().then((uid) => {
    if (!cancel) stop = onSnapshot(doc(db, 'sessions', code, 'members', uid), (s) => cb(s.data()?.role ?? 'viewer'), error);
  }).catch(error);
  return () => { cancel = true; stop(); };
}
export function subscribeMembers(code: string, cb: (members: Member[]) => void, error: (e: Error) => void) {
  return onSnapshot(collection(db, 'sessions', code, 'members'), (s) => cb(s.docs.map((d) => ({ uid: d.id, role: d.data().role, name: d.data().name ?? '' }))), error);
}
export async function setMemberRole(code: string, uid: string, role: 'editor' | 'viewer') {
  await trackedSave(() => updateDoc(doc(db, 'sessions', code, 'members', uid), { role }));
}
export async function setSessionClosed(code: string, closed: boolean) {
  await trackedSave(() => updateDoc(doc(db, 'sessions', code), { closed, updatedAt: serverTimestamp() }));
}
