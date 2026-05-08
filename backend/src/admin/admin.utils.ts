export const quoteRotationKey = 'quoteRotation';
export const quoteBackgroundKey = 'quoteBackgrounds';

export type QuoteRotationSettings = {
  enabled: boolean;
  paused: boolean;
  quoteIds: string[];
  startDate: string;
  offset: number;
};

export type QuoteBackground = {
  id: string;
  imageUrl: string;
  name: string;
  sizeBytes?: number;
  width?: number;
  height?: number;
  active: boolean;
  createdAt: string;
};

export type QuoteBackgroundSettings = QuoteBackground[];

export function extractUrls(value?: string | null) {
  if (!value) return [];
  return Array.from(value.matchAll(/https?:\/\/[^\s"'<>]+/g)).map((match) => match[0]);
}

export function removedR2Urls(previous?: string | null, next?: string | null) {
  const nextUrls = new Set(extractUrls(next));
  return extractUrls(previous).filter((url) => !nextUrls.has(url));
}

export function defaultQuoteRotationSettings(): QuoteRotationSettings {
  return { enabled: false, paused: false, quoteIds: [], startDate: vietnamDateKey(new Date()), offset: 0 };
}

export function quoteLines(value: string) {
  return value
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);
}

export function uniqueStrings(values: unknown[]) {
  return Array.from(new Set(values.filter((value): value is string => typeof value === 'string' && value.trim().length > 0)));
}

export function normalizeQuoteBackground(value: unknown): QuoteBackground | null {
  if (!value || typeof value !== 'object') return null;
  const item = value as Partial<QuoteBackground>;
  if (typeof item.id !== 'string' || typeof item.imageUrl !== 'string' || !item.imageUrl.trim()) return null;
  return {
    id: item.id,
    imageUrl: item.imageUrl.trim(),
    name: typeof item.name === 'string' && item.name.trim() ? item.name.trim() : 'Ảnh nền trích dẫn',
    sizeBytes: normalizePositiveNumber(item.sizeBytes),
    width: normalizePositiveNumber(item.width),
    height: normalizePositiveNumber(item.height),
    active: item.active !== false,
    createdAt: typeof item.createdAt === 'string' ? item.createdAt : new Date().toISOString(),
  };
}

export function normalizePositiveNumber(value: unknown) {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? Math.round(parsed) : undefined;
}

export function vietnamDateKey(date: Date) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Ho_Chi_Minh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(date);
}

export function quoteRotationIndex(settings: QuoteRotationSettings, length: number) {
  const start = Date.parse(`${settings.startDate}T00:00:00+07:00`);
  const today = Date.parse(`${vietnamDateKey(new Date())}T00:00:00+07:00`);
  const days = Number.isFinite(start) && Number.isFinite(today)
    ? Math.max(0, Math.floor((today - start) / 86_400_000))
    : 0;
  return positiveModulo(days + settings.offset, length);
}

function positiveModulo(value: number, length: number) {
  return ((value % length) + length) % length;
}
