'use client';
import type { User } from 'firebase/auth';
import { ref, uploadBytes, getBytes } from 'firebase/storage';
import { useState, useEffect, useRef } from 'react';
import { firebaseServices } from '@/lib/firebase';
import { uid } from '@/lib/model';
import { Notice } from './ui';
export function MediaUpload({
  user,
  onUploaded,
}: {
  user: User;
  onUploaded: (path: string) => void;
}) {
  const alive = useRef(true);
  useEffect(() => {
    alive.current = true;
    return () => {
      alive.current = false;
    };
  }, []);
  const [busy, setBusy] = useState(false),
    [error, setError] = useState('');
  async function upload(file: File) {
    setBusy(true);
    setError('');
    try {
      if (!file.type.startsWith('image/')) throw new Error('Выберите изображение.');
      const bitmap = await createImageBitmap(file, {
        imageOrientation: 'from-image',
      });
      const size = Math.min(1, 2048 / Math.max(bitmap.width, bitmap.height));
      const canvas = document.createElement('canvas');
      canvas.width = Math.max(1, Math.round(bitmap.width * size));
      canvas.height = Math.max(1, Math.round(bitmap.height * size));
      const ctx = canvas.getContext('2d');
      if (!ctx) throw new Error('Не удалось обработать фото.');
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.drawImage(bitmap, 0, 0, canvas.width, canvas.height);
      bitmap.close();
      const jpeg = await new Promise<Blob>((resolve, reject) =>
        canvas.toBlob(
          (b) => (b ? resolve(b) : reject(new Error('Не удалось обработать фото.'))),
          'image/jpeg',
          0.85,
        ),
      );
      if (jpeg.size > 2 * 1024 * 1024)
        throw new Error('Изображение слишком большое. Выберите другое фото.');
      const { auth, storage } = firebaseServices();
      if (auth.currentUser?.uid !== user.uid) throw new Error('Аккаунт изменился.');
      const path = `accounts/${user.uid}/media/${uid()}.jpg`;
      await uploadBytes(ref(storage, path), jpeg, {
        contentType: 'image/jpeg',
      });
      if (!alive.current || auth.currentUser?.uid !== user.uid) return;
      onUploaded(path);
    } catch (e) {
      if (alive.current) setError(e instanceof Error ? e.message : 'Не удалось загрузить фото.');
    } finally {
      if (alive.current) setBusy(false);
    }
  }
  return (
    <div className="stack">
      <label className="field">
        <span>{busy ? 'Загружаем изображение…' : 'Выбрать приватное изображение'}</span>
        <input
          type="file"
          accept="image/*"
          disabled={busy}
          onChange={(e) => {
            const file = e.target.files?.[0];
            if (file) void upload(file);
            e.target.value = '';
          }}
        />
      </label>
      <small className="muted">
        Фото нормализуется в JPEG без EXIF. Публичная копия создаётся только при Publish.
      </small>
      {error && <Notice error>{error}</Notice>}
    </div>
  );
}
export function PrivateImage({
  user,
  path,
  alt = 'Фото',
}: {
  user: User;
  path: string;
  alt?: string;
}) {
  const [url, setUrl] = useState('');
  useEffect(() => {
    let cancelled = false,
      current = '';
    setUrl('');
    if (!path || !path.startsWith(`accounts/${user.uid}/media/`)) return;
    void getBytes(ref(firebaseServices().storage, path), 2 * 1024 * 1024)
      .then((bytes) => {
        if (cancelled || firebaseServices().auth.currentUser?.uid !== user.uid) return;
        current = URL.createObjectURL(new Blob([bytes], { type: 'image/jpeg' }));
        setUrl(current);
      })
      .catch(() => {});
    return () => {
      cancelled = true;
      if (current) URL.revokeObjectURL(current);
    };
  }, [user, path]);
  return url ? <img className="portrait" src={url} alt={alt} width={80} height={80} /> : null;
}
