export type AudioCategory = {
  id: string;
  name: string;
  description?: string;
  createdAt?: string;
  _count?: { audios: number };
};

export type VideoCategory = {
  id: string;
  name: string;
  description?: string;
  createdAt?: string;
  _count?: { videos: number };
};

export type Audio = {
  id: string;
  title: string;
  description?: string;
  audioUrl: string;
  thumbnailUrl?: string;
  categoryId: string;
  duration: number;
  category?: AudioCategory;
};

export type ScriptureLine = {
  id?: string;
  content: string;
  startTime?: number;
  start_time?: number;
  orderIndex?: number;
};

export type Scripture = {
  id: string;
  title: string;
  description?: string;
  backgroundImageUrl?: string;
  categoryId?: string;
  category?: AudioCategory;
  lines: ScriptureLine[];
  _count?: { lines: number };
};

export type Video = {
  id: string;
  title: string;
  description?: string;
  videoUrl: string;
  thumbnailUrl?: string;
  categoryId: string;
  teacher?: string;
  category?: VideoCategory;
};

export type RssSource = {
  id: string;
  name: string;
  url: string;
  active: boolean;
};

export type NewsCategory = {
  id: string;
  name: string;
  description?: string;
  _count?: { items: number };
};

export type NewsItem = {
  id: string;
  title: string;
  summary?: string;
  content?: string;
  imageUrl?: string;
  link?: string;
  categoryId?: string;
  category?: NewsCategory;
  sourceName?: string;
  sourceType: 'RSS' | 'MANUAL';
  shareEnabled: boolean;
  publishedAt: string;
};

export type ScriptureReminder = {
  id: string;
  title: string;
  scriptureId: string;
  scripture?: Pick<Scripture, 'id' | 'title'>;
  userId?: string;
  user?: Pick<AdminUser, 'id' | 'email' | 'username' | 'name'>;
  timeOfDay: string;
  weekdays: number[];
  resumeMode: 'RESUME' | 'RESTART';
  active: boolean;
  lastLineIndex: number;
};

export type Quote = {
  id: string;
  content: string;
  imageUrl?: string;
  active: boolean;
};

export type Banner = {
  id: string;
  imageUrl: string;
  link?: string;
  active: boolean;
};

export type MeditationProgram = {
  id: string;
  title: string;
  description?: string;
  duration: number;
  audioUrl?: string;
  imageUrl?: string;
  active: boolean;
};

export type Feedback = {
  id: string;
  content: string;
  type: 'FEEDBACK' | 'REPORT';
  createdAt: string;
  user?: Pick<AdminUser, 'id' | 'email' | 'username' | 'name'>;
};

export type AdminUser = {
  id: string;
  email: string;
  username?: string;
  name?: string;
  birthDate?: string;
  active: boolean;
  role: 'USER' | 'ADMIN';
  createdAt: string;
  _count?: {
    playlists: number;
    favorites: number;
    feedback: number;
  };
};

export type UploadKind =
  | 'audio'
  | 'audio/library'
  | 'audio/meditation'
  | 'video'
  | 'video/dharma'
  | 'images/audio'
  | 'images/video'
  | 'images/banner'
  | 'images/quote'
  | 'images/news'
  | 'images/scripture'
  | 'images/meditation';

export type PresignedUpload = {
  key: string;
  uploadUrl: string;
  publicUrl: string;
};

const configuredBaseUrl = import.meta.env.VITE_API_BASE_URL as string | undefined;

export function defaultApiBaseUrl() {
  if (configuredBaseUrl) return configuredBaseUrl.replace(/\/$/, '');
  if (window.location.port === '8002') return '/api';
  const { protocol, hostname } = window.location;
  return `${protocol}//${hostname}:8001/api`;
}

export function getApiBaseUrl() {
  return (localStorage.getItem('phaptam_api_base_url') || defaultApiBaseUrl()).replace(/\/$/, '');
}

export function setApiBaseUrl(value: string) {
  localStorage.setItem('phaptam_api_base_url', value.replace(/\/$/, ''));
}

async function request<T>(path: string, options?: RequestInit): Promise<T> {
  const response = await fetch(`${getApiBaseUrl()}${path}`, {
    headers: { 'Content-Type': 'application/json', ...options?.headers },
    ...options,
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(text || `Request failed: ${response.status}`);
  }

  if (response.status === 204) return undefined as T;
  return response.json() as Promise<T>;
}

export const api = {
  overview: () => request<Record<string, number>>('/admin/overview'),
  audioCategories: () => request<AudioCategory[]>('/admin/audio-category'),
  videoCategories: () => request<VideoCategory[]>('/admin/video-category'),
  audios: () => request<Audio[]>('/admin/audio'),
  scriptures: () => request<Scripture[]>('/admin/scripture'),
  generateScriptureTiming: (data: { lines: string[]; audioDuration?: number }) =>
    request<Array<{ content: string; start_time: number }>>('/admin/scripture/generate-timing', {
      method: 'POST',
      body: JSON.stringify(data),
    }),
  videos: () => request<Video[]>('/admin/video'),
  rss: () => request<RssSource[]>('/admin/rss'),
  newsCategories: () => request<NewsCategory[]>('/admin/news-category'),
  news: () => request<NewsItem[]>('/admin/news'),
  scriptureReminders: async () => {
    try {
      return await request<ScriptureReminder[]>('/admin/scripture-reminder');
    } catch (error) {
      if (error instanceof Error && error.message.includes('404')) {
        try {
          return await request<ScriptureReminder[]>('/admin/scripture-reminders');
        } catch (fallbackError) {
          if (fallbackError instanceof Error && fallbackError.message.includes('404')) return [];
          throw fallbackError;
        }
      }
      throw error;
    }
  },
  quotes: () => request<Quote[]>('/admin/quote'),
  banners: () => request<Banner[]>('/admin/banner'),
  meditationPrograms: () => request<MeditationProgram[]>('/admin/meditation'),
  feedback: () => request<Feedback[]>('/admin/feedback'),
  users: () => request<AdminUser[]>('/admin/users'),
  presignedUrl: (data: { kind: UploadKind; contentType: string }) =>
    request<PresignedUpload>('/upload/presigned-url', {
      method: 'POST',
      body: JSON.stringify(data),
    }),

  create: <T>(path: string, data: unknown) =>
    request<T>(path, { method: 'POST', body: JSON.stringify(data) }),
  update: <T>(path: string, data: unknown) =>
    request<T>(path, { method: 'PATCH', body: JSON.stringify(data) }),
  remove: (path: string) => request<void>(path, { method: 'DELETE' }),
};

export async function uploadToR2(file: File, kind: UploadKind): Promise<string> {
  const normalized = kind.startsWith('images/') ? await convertImageToWebp(file, kind) : file;
  const { uploadUrl, publicUrl } = await api.presignedUrl({
    kind,
    contentType: normalized.type,
  });

  const response = await fetch(uploadUrl, {
    method: 'PUT',
    headers: { 'Content-Type': normalized.type },
    body: normalized,
  });

  if (!response.ok) {
    throw new Error(`Upload thất bại: ${response.status}`);
  }

  return publicUrl;
}

async function convertImageToWebp(file: File, kind: UploadKind): Promise<File> {
  if (file.type === 'image/webp') return file;

  const image = await createImageBitmap(file);
  const canvas = document.createElement('canvas');
  const maxEdge = kind === 'images/scripture' ? 1600 : file.name.toLowerCase().includes('banner') ? 1200 : 600;
  const scale = Math.min(1, maxEdge / Math.max(image.width, image.height));
  canvas.width = Math.max(1, Math.round(image.width * scale));
  canvas.height = Math.max(1, Math.round(image.height * scale));

  const context = canvas.getContext('2d');
  if (!context) throw new Error('Không thể tối ưu ảnh trên trình duyệt này');

  context.drawImage(image, 0, 0, canvas.width, canvas.height);
  const blob = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, 'image/webp', 0.82));
  if (!blob) throw new Error('Không thể chuyển ảnh sang WebP');

  return new File([blob], file.name.replace(/\.[^.]+$/, '.webp'), { type: 'image/webp' });
}
