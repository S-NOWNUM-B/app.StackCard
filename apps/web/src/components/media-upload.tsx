'use client';
import type { User } from 'firebase/auth';
import { useState, useEffect, useRef } from 'react';
import { firebaseServices } from '@/lib/firebase';
import { safeHttpUrl } from '@/lib/model';
import {
  portfolioMediaRepository,
  prepareAvatar,
  readAvatarBytes,
} from '@/lib/portfolio-media-repository';
import { Button, Icon, Notice } from './ui';

function useAvatar(user: User, path: string) {
  const [image, setImage] = useState({ url: '', uid: '', path: '' }),
    [error, setError] = useState(''),
    [retry, setRetry] = useState(0);
  useEffect(() => {
    let cancelled = false,
      current = '';
    setImage({ url: '', uid: user.uid, path });
    setError('');
    if (!path) return;
    void readAvatarBytes(user, path)
      .then((bytes) => {
        if (cancelled || firebaseServices().auth.currentUser?.uid !== user.uid) return;
        current = URL.createObjectURL(new Blob([bytes.slice().buffer], { type: 'image/jpeg' }));
        setImage({ url: current, uid: user.uid, path });
      })
      .catch(() => {
        if (!cancelled && firebaseServices().auth.currentUser?.uid === user.uid)
          setError('Фотография недоступна. Повторите попытку.');
      });
    return () => {
      cancelled = true;
      if (current) URL.revokeObjectURL(current);
    };
  }, [user.uid, path, retry]);
  return {
    url: image.uid === user.uid && image.path === path ? image.url : '',
    error,
    retry: () => setRetry((value) => value + 1),
  };
}

export function AvatarEditor({
  user,
  path,
  onChange,
  onBusyChanged,
  disabled = false,
  externalUrl = '',
}: {
  user: User;
  path: string;
  onChange: (path: string) => void;
  onBusyChanged?: (busy: boolean) => void;
  disabled?: boolean;
  externalUrl?: string;
}) {
  const image = useAvatar(user, path),
    gallery = useRef<HTMLInputElement>(null),
    camera = useRef<HTMLInputElement>(null);
  const [menu, setMenu] = useState(false),
    [busy, setBusy] = useState(false),
    [error, setError] = useState('');
  const generation = useRef(0),
    alive = useRef(true),
    current = useRef({ uid: user.uid, path, disabled, externalUrl });
  current.current = { uid: user.uid, path, disabled, externalUrl };
  const busyCallback = useRef(onBusyChanged);
  busyCallback.current = onBusyChanged;
  useEffect(() => {
    alive.current = true;
    return () => {
      alive.current = false;
      generation.current++;
    };
  }, []);
  useEffect(() => {
    generation.current++;
    setBusy(false);
    setMenu(false);
    setError('');
    busyCallback.current?.(false);
  }, [user.uid, path, externalUrl]);

  async function upload(file: File) {
    if (busy || disabled) return;
    const owner = user.uid,
      previousPath = path,
      operation = ++generation.current;
    const valid = () =>
      alive.current &&
      generation.current === operation &&
      current.current.uid === owner &&
      current.current.path === previousPath &&
      current.current.externalUrl === externalUrl &&
      firebaseServices().auth.currentUser?.uid === owner;
    setBusy(true);
    setMenu(false);
    setError('');
    busyCallback.current?.(true);
    try {
      const bytes = await prepareAvatar(file);
      if (!valid()) return;
      const repository = portfolioMediaRepository(user),
        uploaded = await repository.upload(bytes);
      if (!valid() || current.current.disabled) {
        // Only this new immutable object is eligible for cleanup.
        void repository.delete(uploaded).catch(() => {});
        return;
      }
      setBusy(false);
      busyCallback.current?.(false);
      onChange(uploaded);
    } catch (failure) {
      if (valid())
        setError(
          failure instanceof Error
            ? failure.message
            : 'Не удалось загрузить фотографию. Повторите попытку.',
        );
    } finally {
      if (alive.current && generation.current === operation) {
        setBusy(false);
        busyCallback.current?.(false);
      }
    }
  }

  return (
    <div className="avatar-editor">
      <button
        type="button"
        className="avatar-trigger"
        aria-label={path || externalUrl ? 'Изменить фотографию' : 'Добавить фотографию'}
        aria-expanded={menu}
        disabled={busy || disabled}
        onClick={() => setMenu((value) => !value)}
      >
        {image.url || (!path && externalUrl && safeHttpUrl(externalUrl)) ? (
          <img
            className="avatar-photo"
            src={image.url || externalUrl}
            alt="Фото профиля"
            width={128}
            height={128}
          />
        ) : (
          <Icon name="user-round" size={40} />
        )}
        <span className="avatar-pencil" aria-hidden="true">
          <Icon name="pencil" size={22} />
        </span>
      </button>
      {menu && (
        <div className="avatar-menu" aria-label="Действия с фотографией">
          <Button variant="quiet" onClick={() => gallery.current?.click()}>
            <Icon name="image" />
            Выбрать из галереи
          </Button>
          <Button variant="quiet" onClick={() => camera.current?.click()}>
            <Icon name="camera" />
            Сделать фото
          </Button>
          {(path || externalUrl) && (
            <Button
              variant="danger"
              onClick={() => {
                setMenu(false);
                setError('');
                onChange('');
              }}
            >
              Удалить фото
            </Button>
          )}
        </div>
      )}
      <input
        ref={gallery}
        className="avatar-file"
        type="file"
        hidden
        accept="image/jpeg,image/png,image/webp"
        disabled={busy || disabled}
        onChange={(event) => {
          const file = event.target.files?.[0];
          if (file) void upload(file);
          event.target.value = '';
        }}
      />
      <input
        ref={camera}
        className="avatar-file"
        type="file"
        hidden
        accept="image/jpeg,image/png,image/webp"
        capture="user"
        disabled={busy || disabled}
        onChange={(event) => {
          const file = event.target.files?.[0];
          if (file) void upload(file);
          event.target.value = '';
        }}
      />
      {busy && (
        <p className="avatar-status muted" role="status">
          Загружаем фотографию…
        </p>
      )}
      {error && <Notice error>{error}</Notice>}
      {image.error && !busy && (
        <>
          <Notice error>{image.error}</Notice>
          <Button variant="quiet" onClick={image.retry}>
            Повторить
          </Button>
        </>
      )}
    </div>
  );
}

/** Compatibility export; modern owner screens use one AvatarEditor. */
export function MediaUpload({
  user,
  onUploaded,
}: {
  user: User;
  onUploaded: (path: string) => void;
}) {
  return <AvatarEditor user={user} path="" onChange={onUploaded} />;
}

export function PrivateImage({
  user,
  path,
  alt = 'Фото профиля',
}: {
  user: User;
  path: string;
  alt?: string;
}) {
  const image = useAvatar(user, path);
  if (!path) return null;
  return image.url ? (
    <img className="portrait" src={image.url} alt={alt} width={128} height={128} />
  ) : image.error ? (
    <Notice error>{image.error}</Notice>
  ) : (
    <span className="muted" role="status">
      Загружаем фотографию…
    </span>
  );
}
