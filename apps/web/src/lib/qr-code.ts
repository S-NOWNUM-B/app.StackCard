// Минимальный QR encoder (ISO/IEC 18004): byte mode, уровень коррекции M, версии 1–10.
// Нужен только для визитки с короткой публичной ссылкой; без новых npm-зависимостей.
const maxVersion = 10;
// Уровень M: ECC codewords на блок и число блоков для версий 1–10.
const eccPerBlock = [0, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26];
const blockCount = [0, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5];

export type QrMatrix = { size: number; modules: boolean[][] };

function rawDataModules(version: number): number {
  let result = (16 * version + 128) * version + 64;
  if (version >= 2) {
    const align = Math.floor(version / 7) + 2;
    result -= (25 * align - 10) * align - 55;
    if (version >= 7) result -= 36;
  }
  return result;
}
const dataCodewords = (version: number) =>
  Math.floor(rawDataModules(version) / 8) - eccPerBlock[version] * blockCount[version];

function alignmentPositions(version: number): number[] {
  if (version === 1) return [];
  const count = Math.floor(version / 7) + 2,
    size = version * 4 + 17,
    step = Math.ceil((version * 4 + 4) / (count * 2 - 2)) * 2;
  const result = [6];
  for (let position = size - 7; result.length < count; position -= step)
    result.splice(1, 0, position);
  return result;
}

// Умножение в GF(2^8) с примитивным многочленом 0x11D.
function multiply(x: number, y: number): number {
  let z = 0;
  for (let i = 7; i >= 0; i--) {
    z = (z << 1) ^ ((z >>> 7) * 0x11d);
    z ^= ((y >>> i) & 1) * x;
  }
  return z;
}
function divisor(degree: number): number[] {
  const result = new Array<number>(degree).fill(0);
  result[degree - 1] = 1;
  let root = 1;
  for (let i = 0; i < degree; i++) {
    for (let j = 0; j < degree; j++) {
      result[j] = multiply(result[j], root);
      if (j + 1 < degree) result[j] ^= result[j + 1];
    }
    root = multiply(root, 0x02);
  }
  return result;
}
function remainder(data: number[], generator: number[]): number[] {
  const result = new Array<number>(generator.length).fill(0);
  for (const byte of data) {
    const factor = byte ^ (result.shift() as number);
    result.push(0);
    generator.forEach((coefficient, i) => (result[i] ^= multiply(coefficient, factor)));
  }
  return result;
}

function interleave(version: number, data: number[]): number[] {
  const blocks = blockCount[version],
    ecc = eccPerBlock[version],
    raw = Math.floor(rawDataModules(version) / 8),
    shortBlocks = blocks - (raw % blocks),
    shortLength = Math.floor(raw / blocks),
    generator = divisor(ecc);
  const parts: number[][] = [];
  for (let i = 0, offset = 0; i < blocks; i++) {
    const block = data.slice(offset, offset + shortLength - ecc + (i < shortBlocks ? 0 : 1));
    offset += block.length;
    const check = remainder(block, generator);
    if (i < shortBlocks) block.push(0);
    parts.push([...block, ...check]);
  }
  const result: number[] = [];
  for (let i = 0; i < parts[0].length; i++)
    parts.forEach((block, j) => {
      if (i !== shortLength - ecc || j >= shortBlocks) result.push(block[i]);
    });
  return result;
}

const masks: ((x: number, y: number) => boolean)[] = [
  (x, y) => (x + y) % 2 === 0,
  (_x, y) => y % 2 === 0,
  (x) => x % 3 === 0,
  (x, y) => (x + y) % 3 === 0,
  (x, y) => (Math.floor(x / 3) + Math.floor(y / 2)) % 2 === 0,
  (x, y) => ((x * y) % 2) + ((x * y) % 3) === 0,
  (x, y) => (((x * y) % 2) + ((x * y) % 3)) % 2 === 0,
  (x, y) => (((x + y) % 2) + ((x * y) % 3)) % 2 === 0,
];

// Штраф выбора маски: длинные ряды, блоки 2×2, ложные finder-узоры и баланс тёмных модулей.
function penalty(modules: boolean[][]): number {
  const size = modules.length;
  let score = 0,
    dark = 0;
  const line = (get: (i: number) => boolean) => {
    let run = 1;
    for (let i = 1; i <= size; i++) {
      if (i < size && get(i) === get(i - 1)) run++;
      else {
        if (run >= 5) score += run - 2;
        run = 1;
      }
    }
    const pattern = [true, false, true, true, true, false, true];
    for (let i = 0; i + 7 <= size; i++) {
      if (!pattern.every((value, k) => get(i + k) === value)) continue;
      const before = i >= 4 && [1, 2, 3, 4].every((k) => !get(i - k)),
        after = i + 11 <= size && [7, 8, 9, 10].every((k) => !get(i + k));
      if (before || after) score += 40;
    }
  };
  for (let y = 0; y < size; y++) {
    line((x) => modules[y][x]);
    line((x) => modules[x][y]);
    for (let x = 0; x < size; x++) {
      if (modules[y][x]) dark++;
      if (
        x + 1 < size &&
        y + 1 < size &&
        modules[y][x] === modules[y][x + 1] &&
        modules[y][x] === modules[y + 1][x] &&
        modules[y][x] === modules[y + 1][x + 1]
      )
        score += 3;
    }
  }
  score += Math.floor(Math.abs((dark * 20) / (size * size) - 10)) * 10;
  return score;
}

export function encodeQr(text: string): QrMatrix {
  const bytes = Array.from(new TextEncoder().encode(text));
  let version = 1;
  const countBits = (v: number) => (v < 10 ? 8 : 16);
  while (
    version <= maxVersion &&
    4 + countBits(version) + bytes.length * 8 > dataCodewords(version) * 8
  )
    version++;
  if (version > maxVersion) throw new Error('Ссылка слишком длинная для QR-кода');
  // Битовый поток: режим byte, длина, данные, терминатор и заполнители 0xEC/0x11.
  const bits: number[] = [];
  const append = (value: number, length: number) => {
    for (let i = length - 1; i >= 0; i--) bits.push((value >>> i) & 1);
  };
  append(0b0100, 4);
  append(bytes.length, countBits(version));
  bytes.forEach((byte) => append(byte, 8));
  const capacity = dataCodewords(version) * 8;
  append(0, Math.min(4, capacity - bits.length));
  append(0, (8 - (bits.length % 8)) % 8);
  for (let pad = 0xec; bits.length < capacity; pad ^= 0xec ^ 0x11) append(pad, 8);
  const data: number[] = [];
  for (let i = 0; i < bits.length; i += 8)
    data.push(bits.slice(i, i + 8).reduce((byte, bit) => (byte << 1) | bit, 0));
  const codewords = interleave(version, data);

  const size = version * 4 + 17;
  const modules = Array.from({ length: size }, () => new Array<boolean>(size).fill(false));
  const reserved = Array.from({ length: size }, () => new Array<boolean>(size).fill(false));
  const set = (x: number, y: number, dark: boolean) => {
    modules[y][x] = dark;
    reserved[y][x] = true;
  };
  for (let i = 0; i < size; i++) {
    set(6, i, i % 2 === 0);
    set(i, 6, i % 2 === 0);
  }
  for (const [cx, cy] of [
    [3, 3],
    [size - 4, 3],
    [3, size - 4],
  ])
    for (let dy = -4; dy <= 4; dy++)
      for (let dx = -4; dx <= 4; dx++) {
        const x = cx + dx,
          y = cy + dy,
          distance = Math.max(Math.abs(dx), Math.abs(dy));
        if (x >= 0 && x < size && y >= 0 && y < size) set(x, y, distance !== 2 && distance !== 4);
      }
  const align = alignmentPositions(version),
    last = align.length - 1;
  align.forEach((ax, i) =>
    align.forEach((ay, j) => {
      if ((i === 0 && j === 0) || (i === 0 && j === last) || (i === last && j === 0)) return;
      for (let dy = -2; dy <= 2; dy++)
        for (let dx = -2; dx <= 2; dx++)
          set(ax + dx, ay + dy, Math.max(Math.abs(dx), Math.abs(dy)) !== 1);
    }),
  );
  const drawFormat = (mask: number) => {
    // Уровень M кодируется битами 00.
    const value = mask;
    let rem = value;
    for (let i = 0; i < 10; i++) rem = (rem << 1) ^ ((rem >>> 9) * 0x537);
    const format = ((value << 10) | rem) ^ 0x5412;
    const bit = (i: number) => ((format >>> i) & 1) !== 0;
    for (let i = 0; i <= 5; i++) set(8, i, bit(i));
    set(8, 7, bit(6));
    set(8, 8, bit(7));
    set(7, 8, bit(8));
    for (let i = 9; i < 15; i++) set(14 - i, 8, bit(i));
    for (let i = 0; i < 8; i++) set(size - 1 - i, 8, bit(i));
    for (let i = 8; i < 15; i++) set(8, size - 15 + i, bit(i));
    set(8, size - 8, true);
  };
  drawFormat(0);
  if (version >= 7) {
    let rem = version;
    for (let i = 0; i < 12; i++) rem = (rem << 1) ^ ((rem >>> 11) * 0x1f25);
    const value = (version << 12) | rem;
    for (let i = 0; i < 18; i++) {
      const dark = ((value >>> i) & 1) !== 0,
        a = size - 11 + (i % 3),
        b = Math.floor(i / 3);
      set(a, b, dark);
      set(b, a, dark);
    }
  }
  // Данные укладываются зигзагом по парам столбцов снизу вверх и обратно.
  let index = 0;
  for (let right = size - 1; right >= 1; right -= 2) {
    if (right === 6) right = 5;
    for (let vertical = 0; vertical < size; vertical++)
      for (let j = 0; j < 2; j++) {
        const x = right - j,
          upward = ((right + 1) & 2) === 0,
          y = upward ? size - 1 - vertical : vertical;
        if (reserved[y][x] || index >= codewords.length * 8) continue;
        modules[y][x] = ((codewords[index >>> 3] >>> (7 - (index & 7))) & 1) !== 0;
        index++;
      }
  }
  const applyMask = (mask: number) => {
    for (let y = 0; y < size; y++)
      for (let x = 0; x < size; x++)
        if (!reserved[y][x] && masks[mask](x, y)) modules[y][x] = !modules[y][x];
  };
  let best = 0,
    bestScore = Infinity;
  for (let mask = 0; mask < 8; mask++) {
    applyMask(mask);
    drawFormat(mask);
    const score = penalty(modules);
    if (score < bestScore) {
      best = mask;
      bestScore = score;
    }
    applyMask(mask);
  }
  applyMask(best);
  drawFormat(best);
  return { size, modules };
}

// SVG path тёмных модулей с quiet zone 4 модуля; viewBox задаёт сам компонент.
export function qrPath({ size, modules }: QrMatrix, margin = 4): string {
  const parts: string[] = [];
  for (let y = 0; y < size; y++)
    for (let x = 0; x < size; x++)
      if (modules[y][x]) parts.push(`M${x + margin} ${y + margin}h1v1h-1z`);
  return parts.join('');
}
