'use client';
import { doc, getDocFromServer, runTransaction, serverTimestamp } from 'firebase/firestore';
import type { User } from 'firebase/auth';
import { firebaseServices } from './firebase';
import {
  assertWriteBasis,
  decodeDraft,
  validateWorkspace,
  type DraftEnvelope,
  type WorkspaceContent,
} from './model';
function ownerRef(user: User) {
  const { auth, firestore } = firebaseServices();
  if (auth.currentUser?.uid !== user.uid)
    throw new Error('Аккаунт изменился. Откройте кабинет заново.');
  return doc(firestore, 'accounts', user.uid, 'drafts', 'current');
}
export async function loadDraft(user: User): Promise<DraftEnvelope | null> {
  const snapshot = await getDocFromServer(ownerRef(user));
  if (firebaseServices().auth.currentUser?.uid !== user.uid) throw new Error('Аккаунт изменился.');
  return snapshot.exists() ? decodeDraft(snapshot.data(), user.uid) : null;
}
export async function saveDraft(
  user: User,
  basis: DraftEnvelope | null,
  content: WorkspaceContent,
  notes: string,
  mutationId: string,
): Promise<DraftEnvelope> {
  const checked = validateWorkspace(content, user.uid);
  const ref = ownerRef(user);
  const { firestore } = firebaseServices();
  await runTransaction(firestore, async (transaction) => {
    const snapshot = await transaction.get(ref);
    const current = snapshot.exists() ? decodeDraft(snapshot.data(), user.uid) : null;
    // Потерянный ACK разрешает retry только той же операции с тем же содержимым.
    if (current?.mutationId === mutationId) {
      if (JSON.stringify(current.content) !== JSON.stringify(checked) || current.notes !== notes)
        throw new Error('ID операции уже использован.');
      return;
    }
    assertWriteBasis(current, basis);
    ownerRef(user);
    transaction.set(ref, {
      schemaVersion: 6,
      ownerUid: user.uid,
      mutationId,
      localRevision: (basis?.localRevision ?? 0) + 1,
      notes,
      content: checked,
      updatedAt: serverTimestamp(),
    });
  });
  const saved = await loadDraft(user);
  if (saved?.mutationId !== mutationId)
    throw new Error('Серверная версия изменилась после Save. Перезагрузите её перед публикацией.');
  return saved;
}
