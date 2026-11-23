/** Deterministic mulberry32 whose state lives in a plain number, so it is serialisable. */
export function nextRandom(box: { s: number }): number {
  box.s = (box.s + 0x6d2b79f5) >>> 0;
  let t = box.s;
  t = Math.imul(t ^ (t >>> 15), t | 1);
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}

export function shuffleInPlace<T>(arr: T[], box: { s: number }): void {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(nextRandom(box) * (i + 1));
    [arr[i], arr[j]] = [arr[j]!, arr[i]!];
  }
}
