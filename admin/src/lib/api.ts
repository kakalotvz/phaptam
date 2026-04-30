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

export type Feedback = {
  id: string;
  content: string;
  type: 'FEEDBACK' | 'REPORT';
  createdAt: string;
};

export type AdminUser = {
  id: string;
  email: string;
  name?: string;
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
  | 'video'
  | 'images/audio'
  | 'images/video'
  | 'images/banner'
  | 'images/quote'
  | 'images/news';

export type PresignedUpload = {
  key: string;
  uploadUrl: string;
  publicUrl: string;
};

const configuredBaseUrl = import.meta.env.VITE_API_BASE_URL as string | undefined;

export function defaultApiBaseUrl() {
  if (configuredBaseUrl) return configuredBaseUrl.replace(/\/$/, '');
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
  videos: () => request<Video[]>('/admin/video'),
  rss: () => request<RssSource[]>('/admin/rss'),
  quotes: () => request<Quote[]>('/admin/quote'),
  banners: () => request<Banner[]>('/admin/banner'),
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
  const normalized = kind.startsWith('images/') ? await convertImageToWebp(file) : file;
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

async function convertImageToWebp(file: File): Promise<File> {
  if (file.type === 'image/webp') return file;

  const image = await createImageBitmap(file);
  const canvas = document.createElement('canvas');
  const maxEdge = file.name.toLowerCase().includes('banner') ? 1200 : 600;
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
