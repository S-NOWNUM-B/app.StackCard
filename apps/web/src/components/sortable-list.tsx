'use client';
import {
  useId,
  useLayoutEffect,
  useRef,
  useState,
  type KeyboardEvent,
  type PointerEvent,
  type ReactNode,
} from 'react';
import { InlineIcon } from './inline-icon';

// Перестановка внутри одного списка: pointer events (мышь, touch, перо) за точки,
// стрелки на клавиатуре и видимые «Вверх/Вниз» для точного указателя.
export function moveItem<T>(items: T[], from: number, to: number): T[] {
  if (from === to || from < 0 || to < 0 || from >= items.length || to >= items.length) return items;
  const next = [...items];
  next.splice(to, 0, next.splice(from, 1)[0]);
  return next;
}

function reducedMotion(element: Element) {
  return (
    !!element.closest('[data-reduced-motion="true"]') ||
    window.matchMedia?.('(prefers-reduced-motion: reduce)').matches
  );
}

export function SortableList<T>({
  items,
  itemKey,
  itemLabel,
  label,
  onMove,
  renderItem,
  className = '',
  disabled = false,
}: {
  items: T[];
  itemKey: (item: T) => string;
  itemLabel: (item: T) => string;
  label: string;
  onMove?: (from: number, to: number) => void;
  renderItem: (item: T, index: number) => ReactNode;
  className?: string;
  disabled?: boolean;
}) {
  const list = useRef<HTMLUListElement>(null),
    hintId = useId(),
    keys = items.map(itemKey);
  const keysRef = useRef(keys);
  keysRef.current = keys;
  const drag = useRef<{ key: string; pointerId: number; originY: number; locked: boolean } | null>(
    null,
  );
  const positions = useRef(new Map<string, number>()),
    focusKey = useRef<string | null>(null);
  const [dragging, setDragging] = useState<{ key: string; offset: number } | null>(null),
    [announcement, setAnnouncement] = useState('');
  const sortable = !!onMove && items.length > 1 && !disabled;
  const elements = () =>
    Array.from(list.current?.querySelectorAll<HTMLElement>(':scope > .sortable-item') ?? []);

  // FLIP: соседние строки плавно занимают новое место; перетаскиваемая следует за указателем.
  useLayoutEffect(() => {
    const current = list.current;
    if (!current) return;
    const motion = !reducedMotion(current);
    for (const element of elements()) {
      const key = element.dataset.key!,
        top = element.offsetTop,
        previous = positions.current.get(key);
      if (
        motion &&
        previous !== undefined &&
        previous !== top &&
        key !== drag.current?.key &&
        typeof element.animate === 'function'
      )
        element.animate(
          [{ transform: `translateY(${previous - top}px)` }, { transform: 'translateY(0)' }],
          { duration: 180, easing: 'cubic-bezier(0.2, 0, 0, 1)' },
        );
      positions.current.set(key, top);
    }
    if (drag.current) drag.current.locked = false;
    if (focusKey.current) {
      list.current
        ?.querySelector<HTMLButtonElement>(`[data-handle="${CSS.escape(focusKey.current)}"]`)
        ?.focus();
      focusKey.current = null;
    }
  }, [keys.join('\u0000')]);

  function move(from: number, to: number, focus?: string) {
    if (!onMove || to < 0 || to >= keysRef.current.length) return;
    focusKey.current = focus ?? null;
    onMove(from, to);
    setAnnouncement(`${itemLabel(items[from])}: позиция ${to + 1} из ${items.length}`);
  }
  function keyDown(event: KeyboardEvent<HTMLButtonElement>, index: number, key: string) {
    if (event.key !== 'ArrowUp' && event.key !== 'ArrowDown') return;
    event.preventDefault();
    move(index, index + (event.key === 'ArrowUp' ? -1 : 1), key);
  }
  function pointerDown(event: PointerEvent<HTMLButtonElement>, key: string) {
    if (!sortable || (event.pointerType === 'mouse' && event.button !== 0)) return;
    event.preventDefault();
    try {
      event.currentTarget.setPointerCapture(event.pointerId);
    } catch {
      // Захват недоступен (синтетический указатель): перетаскивание работает без него.
    }
    drag.current = { key, pointerId: event.pointerId, originY: event.clientY, locked: false };
    setDragging({ key, offset: 0 });
  }
  function pointerMove(event: PointerEvent<HTMLButtonElement>) {
    const state = drag.current;
    if (!state || state.pointerId !== event.pointerId || !list.current) return;
    const rows = elements(),
      index = keysRef.current.indexOf(state.key),
      row = rows[index];
    if (!row) return;
    if (!state.locked) {
      const y = event.clientY - list.current.getBoundingClientRect().top,
        previous = rows[index - 1],
        next = rows[index + 1];
      if (previous && y < previous.offsetTop + previous.offsetHeight / 2) {
        state.originY -= row.offsetTop - previous.offsetTop;
        state.locked = true;
        move(index, index - 1);
      } else if (next && y > next.offsetTop + next.offsetHeight / 2) {
        state.originY += next.offsetTop + next.offsetHeight - (row.offsetTop + row.offsetHeight);
        state.locked = true;
        move(index, index + 1);
      }
    }
    setDragging({ key: state.key, offset: event.clientY - state.originY });
  }
  function pointerEnd(event: PointerEvent<HTMLButtonElement>) {
    const state = drag.current;
    if (!state || state.pointerId !== event.pointerId) return;
    const row = elements()[keysRef.current.indexOf(state.key)],
      offset = event.clientY - state.originY;
    drag.current = null;
    setDragging(null);
    if (row && offset && !reducedMotion(row) && typeof row.animate === 'function')
      row.animate([{ transform: `translateY(${offset}px)` }, { transform: 'translateY(0)' }], {
        duration: 180,
        easing: 'cubic-bezier(0.2, 0, 0, 1)',
      });
  }

  return (
    <>
      <ul
        ref={list}
        className={`sortable-list ${className}`}
        aria-label={label}
        aria-describedby={sortable ? hintId : undefined}
      >
        {items.map((item, index) => {
          const key = keys[index],
            name = itemLabel(item),
            active = dragging?.key === key;
          return (
            <li
              key={key}
              data-key={key}
              className={`sortable-item${active ? ' is-dragging' : ''}`}
              style={active ? { transform: `translateY(${dragging.offset}px)` } : undefined}
            >
              {sortable && (
                <button
                  type="button"
                  className="sortable-handle"
                  data-handle={key}
                  aria-label={`Изменить порядок: ${name}`}
                  title="Перетащите, чтобы изменить порядок"
                  onPointerDown={(event) => pointerDown(event, key)}
                  onPointerMove={pointerMove}
                  onPointerUp={pointerEnd}
                  onPointerCancel={pointerEnd}
                  onKeyDown={(event) => keyDown(event, index, key)}
                >
                  <InlineIcon name="grip-vertical" size={20} />
                </button>
              )}
              <div className="sortable-content">{renderItem(item, index)}</div>
              {sortable && (
                <span className="sortable-steps">
                  <button
                    type="button"
                    className="sortable-step"
                    aria-label={`Переместить вверх: ${name}`}
                    title="Вверх"
                    disabled={index === 0}
                    onClick={() => move(index, index - 1)}
                  >
                    <InlineIcon name="arrow-up" size={18} />
                  </button>
                  <button
                    type="button"
                    className="sortable-step"
                    aria-label={`Переместить вниз: ${name}`}
                    title="Вниз"
                    disabled={index === items.length - 1}
                    onClick={() => move(index, index + 1)}
                  >
                    <InlineIcon name="arrow-down" size={18} />
                  </button>
                </span>
              )}
            </li>
          );
        })}
      </ul>
      {sortable && (
        <span id={hintId} className="visually-hidden">
          Перетащите точки или нажимайте стрелки вверх и вниз, чтобы изменить порядок
        </span>
      )}
      <span className="visually-hidden" aria-live="polite">
        {announcement}
      </span>
    </>
  );
}
