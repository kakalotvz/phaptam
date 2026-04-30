import React, { FormEvent, useEffect, useMemo, useState } from 'react';
import { createRoot } from 'react-dom/client';
import '@fontsource/noto-sans/400.css';
import '@fontsource/noto-sans/500.css';
import '@fontsource/noto-sans/600.css';
import '@fontsource/noto-sans/700.css';
import '@fontsource/noto-sans/800.css';
import '@fontsource/noto-serif/600.css';
import '@fontsource/noto-serif/700.css';
import '@fontsource/noto-serif/800.css';
import {
  BarChart3,
  BookAudio,
  Clapperboard,
  FileText,
  Image,
  LayoutDashboard,
  MessageSquareText,
  Newspaper,
  ShieldCheck,
  Quote,
  RefreshCcw,
  Save,
  Settings,
  Trash2,
  Upload,
} from 'lucide-react';

import {
  api,
  AdminUser,
  Audio,
  AudioCategory,
  Banner,
  Feedback,
  getApiBaseUrl,
  Quote as QuoteRecord,
  RssSource,
  setApiBaseUrl,
  uploadToR2,
  Video,
  VideoCategory,
} from './lib/api';
import './styles.css';

type Section = 'overview' | 'audio' | 'video' | 'rss' | 'quote' | 'banner' | 'users' | 'feedback' | 'settings';

type DataState = {
  overview: Record<string, number>;
  audioCategories: AudioCategory[];
  videoCategories: VideoCategory[];
  audios: Audio[];
  videos: Video[];
  rss: RssSource[];
  quotes: QuoteRecord[];
  banners: Banner[];
  feedback: Feedback[];
  users: AdminUser[];
};

const emptyData: DataState = {
  overview: {},
  audioCategories: [],
  videoCategories: [],
  audios: [],
  videos: [],
  rss: [],
  quotes: [],
  banners: [],
  feedback: [],
  users: [],
};

const nav = [
  { id: 'overview', label: 'Tổng quan', icon: LayoutDashboard },
  { id: 'audio', label: 'Kinh audio', icon: BookAudio },
  { id: 'video', label: 'Video giảng', icon: Clapperboard },
  { id: 'rss', label: 'Nguồn RSS', icon: Newspaper },
  { id: 'quote', label: 'Lời nhắc', icon: Quote },
  { id: 'banner', label: 'Banner', icon: Image },
  { id: 'users', label: 'Tài khoản', icon: ShieldCheck },
  { id: 'feedback', label: 'Góp ý', icon: MessageSquareText },
  { id: 'settings', label: 'Cấu hình', icon: Settings },
] as const;

function App() {
  const [section, setSection] = useState<Section>('overview');
  const [data, setData] = useState<DataState>(emptyData);
  const [loading, setLoading] = useState(true);
  const [notice, setNotice] = useState('');
  const [error, setError] = useState('');

  async function load() {
    setLoading(true);
    setError('');
    try {
      const [
        overview,
        audioCategories,
        videoCategories,
        audios,
        videos,
        rss,
        quotes,
        banners,
        feedback,
        users,
      ] = await Promise.all([
        api.overview(),
        api.audioCategories(),
        api.videoCategories(),
        api.audios(),
        api.videos(),
        api.rss(),
        api.quotes(),
        api.banners(),
        api.feedback(),
        api.users(),
      ]);
      setData({ overview, audioCategories, videoCategories, audios, videos, rss, quotes, banners, feedback, users });
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Không tải được dữ liệu');
    } finally {
      setLoading(false);
    }
  }

  async function run(action: () => Promise<unknown>, message: string) {
    setError('');
    setNotice('');
    try {
      await action();
      setNotice(message);
      await load();
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Thao tác thất bại');
    }
  }

  useEffect(() => {
    void load();
  }, []);

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="brand">
          <span className="brand-mark">PT</span>
          <div>
            <strong>Pháp Tâm</strong>
            <small>Bảng quản trị</small>
          </div>
        </div>
        <nav>
          {nav.map((item) => {
            const Icon = item.icon;
            return (
              <button
                key={item.id}
                className={section === item.id ? 'active' : ''}
                onClick={() => setSection(item.id as Section)}
              >
                <Icon size={18} />
                {item.label}
              </button>
            );
          })}
        </nav>
      </aside>

      <main>
        <header className="topbar">
          <div>
            <p>Bảng điều khiển nội dung</p>
            <h1>{nav.find((item) => item.id === section)?.label}</h1>
          </div>
          <button className="ghost" onClick={() => void load()}>
            <RefreshCcw size={16} />
            Tải lại
          </button>
        </header>

        {notice && <div className="notice">{notice}</div>}
        {error && <div className="error">{error}</div>}
        {loading ? <div className="loading">Đang tải dữ liệu...</div> : null}

        {!loading && (
          <>
            {section === 'overview' && <Overview data={data} />}
            {section === 'audio' && <AudioManager data={data} run={run} />}
            {section === 'video' && <VideoManager data={data} run={run} />}
            {section === 'rss' && <RssManager data={data} run={run} />}
            {section === 'quote' && <QuoteManager data={data} run={run} />}
            {section === 'banner' && <BannerManager data={data} run={run} />}
            {section === 'users' && <UserManager data={data} run={run} />}
            {section === 'feedback' && <FeedbackManager data={data} run={run} />}
            {section === 'settings' && <SettingsPanel onSaved={load} />}
          </>
        )}
      </main>
    </div>
  );
}

function Overview({ data }: { data: DataState }) {
  const cards = [
    ['Danh mục audio', data.overview.audioCategoryCount ?? 0, BookAudio],
    ['Bài kinh audio', data.overview.audioCount ?? 0, FileText],
    ['Video', data.overview.videoCount ?? 0, Clapperboard],
    ['Nguồn RSS', data.overview.rssCount ?? 0, Newspaper],
    ['Tài khoản', data.overview.userCount ?? 0, ShieldCheck],
    ['Góp ý', data.overview.feedbackCount ?? 0, MessageSquareText],
  ];

  return (
    <section className="grid metrics">
      {cards.map(([label, value, Icon]) => (
        <article className="metric-card" key={label as string}>
          {React.createElement(Icon as typeof BookAudio, { size: 22 })}
          <span>{label as string}</span>
          <strong>{value as number}</strong>
        </article>
      ))}
      <article className="wide-card">
        <BarChart3 size={22} />
        <div>
          <h2>Trang quản trị đã sẵn sàng</h2>
          <p>Quản lý danh mục, audio, video, RSS, banner, lời nhắc và góp ý. Media được upload trực tiếp lên Cloudflare R2 bằng URL ký tạm thời từ backend.</p>
        </div>
      </article>
    </section>
  );
}

function AudioManager({ data, run }: { data: DataState; run: RunAction }) {
  return (
    <div className="two-column">
      <Panel title="Tạo danh mục audio">
        <SmartForm
          fields={[['name', 'Tên danh mục'], ['description', 'Mô tả']]}
          onSubmit={(values) => run(() => api.create('/admin/audio-category', values), 'Đã tạo danh mục audio')}
        />
      </Panel>
      <Panel title="Thêm kinh audio">
        <SmartForm
          fields={[
            ['title', 'Tiêu đề'],
            ['description', 'Mô tả'],
            ['audioUrl', 'Tệp audio MP3', 'upload:audio'],
            ['thumbnailUrl', 'Ảnh đại diện', 'upload:images/audio'],
            ['duration', 'Thời lượng giây', 'number'],
            ['categoryId', 'Danh mục', 'select', data.audioCategories.map((item) => [item.id, item.name])],
          ]}
          onSubmit={(values) => run(() => api.create('/admin/audio', { ...values, duration: Number(values.duration || 0) }), 'Đã thêm audio')}
        />
      </Panel>
      <Panel title="Danh mục audio" className="span">
        <Table
          rows={data.audioCategories}
          columns={[
            ['name', 'Tên'],
            ['description', 'Mô tả'],
            [(row: AudioCategory) => row._count?.audios ?? 0, 'Số audio'],
          ]}
          onDelete={(row) => run(() => api.remove(`/admin/audio-category/${row.id}`), 'Đã xóa danh mục')}
        />
      </Panel>
      <Panel title="Danh sách audio" className="span">
        <Table
          rows={data.audios}
          columns={[
            ['thumbnailUrl', 'Ảnh'],
            ['title', 'Tiêu đề'],
            [(row: Audio) => row.category?.name ?? '-', 'Danh mục'],
            [(row: Audio) => `${row.duration}s`, 'Thời lượng'],
            ['audioUrl', 'Audio URL'],
          ]}
          onDelete={(row) => run(() => api.remove(`/admin/audio/${row.id}`), 'Đã xóa audio')}
        />
      </Panel>
    </div>
  );
}

function VideoManager({ data, run }: { data: DataState; run: RunAction }) {
  return (
    <div className="two-column">
      <Panel title="Tạo danh mục video">
        <SmartForm
          fields={[['name', 'Tên danh mục'], ['description', 'Mô tả']]}
          onSubmit={(values) => run(() => api.create('/admin/video-category', values), 'Đã tạo danh mục video')}
        />
      </Panel>
      <Panel title="Thêm video giảng">
        <SmartForm
          fields={[
            ['title', 'Tiêu đề'],
            ['teacher', 'Giảng sư'],
            ['description', 'Mô tả'],
            ['videoUrl', 'Tệp video MP4 hoặc URL YouTube', 'upload:video'],
            ['thumbnailUrl', 'Ảnh đại diện', 'upload:images/video'],
            ['categoryId', 'Danh mục', 'select', data.videoCategories.map((item) => [item.id, item.name])],
          ]}
          onSubmit={(values) => run(() => api.create('/admin/video', values), 'Đã thêm video')}
        />
      </Panel>
      <Panel title="Danh mục video" className="span">
        <Table
          rows={data.videoCategories}
          columns={[
            ['name', 'Tên'],
            ['description', 'Mô tả'],
            [(row: VideoCategory) => row._count?.videos ?? 0, 'Số video'],
          ]}
          onDelete={(row) => run(() => api.remove(`/admin/video-category/${row.id}`), 'Đã xóa danh mục')}
        />
      </Panel>
      <Panel title="Danh sách video" className="span">
        <Table
          rows={data.videos}
          columns={[
            ['thumbnailUrl', 'Ảnh'],
            ['title', 'Tiêu đề'],
            ['teacher', 'Giảng sư'],
            [(row: Video) => row.category?.name ?? '-', 'Danh mục'],
            ['videoUrl', 'Video URL'],
          ]}
          onDelete={(row) => run(() => api.remove(`/admin/video/${row.id}`), 'Đã xóa video')}
        />
      </Panel>
    </div>
  );
}

function RssManager({ data, run }: { data: DataState; run: RunAction }) {
  return (
    <div className="single-column">
      <Panel title="Thêm nguồn RSS">
        <SmartForm
          fields={[['name', 'Tên website'], ['url', 'RSS URL']]}
          onSubmit={(values) => run(() => api.create('/admin/rss', { ...values, active: true }), 'Đã thêm RSS')}
        />
      </Panel>
      <Panel title="Nguồn RSS đang quản lý">
        <Table
          rows={data.rss}
          columns={[
            ['name', 'Tên'],
            ['url', 'URL'],
            [(row: RssSource) => (row.active ? 'Đang bật' : 'Tắt'), 'Trạng thái'],
          ]}
          onDelete={(row) => run(() => api.remove(`/admin/rss/${row.id}`), 'Đã xóa RSS')}
        />
      </Panel>
    </div>
  );
}

function QuoteManager({ data, run }: { data: DataState; run: RunAction }) {
  return (
    <div className="single-column">
      <Panel title="Tạo lời nhắc hằng ngày">
        <SmartForm
          fields={[['content', 'Nội dung'], ['imageUrl', 'Ảnh minh họa', 'upload:images/quote']]}
          onSubmit={(values) => run(() => api.create('/admin/quote', values), 'Đã tạo lời nhắc')}
        />
      </Panel>
      <Panel title="Lời nhắc">
        <Table
          rows={data.quotes}
          columns={[
            ['imageUrl', 'Ảnh'],
            ['content', 'Nội dung'],
            [(row: QuoteRecord) => (row.active ? 'Đang bật' : 'Tắt'), 'Trạng thái'],
          ]}
          onDelete={(row) => run(() => api.remove(`/admin/quote/${row.id}`), 'Đã xóa lời nhắc')}
        />
      </Panel>
    </div>
  );
}

function BannerManager({ data, run }: { data: DataState; run: RunAction }) {
  return (
    <div className="single-column">
      <Panel title="Tạo banner">
        <SmartForm
          fields={[['imageUrl', 'Ảnh banner', 'upload:images/banner'], ['link', 'Liên kết']]}
          onSubmit={(values) => run(() => api.create('/admin/banner', values), 'Đã tạo banner')}
        />
      </Panel>
      <Panel title="Banner">
        <Table
          rows={data.banners}
          columns={[
            ['imageUrl', 'Ảnh'],
            ['link', 'Liên kết'],
            [(row: Banner) => (row.active ? 'Đang bật' : 'Tắt'), 'Trạng thái'],
          ]}
          onDelete={(row) => run(() => api.remove(`/admin/banner/${row.id}`), 'Đã xóa banner')}
        />
      </Panel>
    </div>
  );
}

function UserManager({ data, run }: { data: DataState; run: RunAction }) {
  return (
    <div className="single-column">
      <Panel title="Tạo tài khoản">
        <SmartForm
          fields={[
            ['name', 'Họ tên'],
            ['email', 'Email'],
            ['password', 'Mật khẩu', 'password'],
            [
              'role',
              'Vai trò',
              'select',
              [
                ['USER', 'Người dùng'],
                ['ADMIN', 'Quản trị viên'],
              ],
            ],
          ]}
          onSubmit={(values) =>
            run(
              () =>
                api.create('/admin/users', {
                  ...values,
                  role: values.role || 'USER',
                }),
              'Đã tạo tài khoản',
            )
          }
        />
      </Panel>
      <Panel title="Danh sách tài khoản">
        <Table
          rows={data.users}
          columns={[
            ['name', 'Họ tên'],
            ['email', 'Email'],
            [(row: AdminUser) => (row.role === 'ADMIN' ? 'Quản trị viên' : 'Người dùng'), 'Vai trò'],
            [(row: AdminUser) => row._count?.playlists ?? 0, 'Playlist'],
            [(row: AdminUser) => row._count?.favorites ?? 0, 'Yêu thích'],
            [(row: AdminUser) => new Date(row.createdAt).toLocaleDateString('vi-VN'), 'Ngày tạo'],
          ]}
          onDelete={(row) => run(() => api.remove(`/admin/users/${row.id}`), 'Đã xóa tài khoản')}
        />
      </Panel>
    </div>
  );
}

function FeedbackManager({ data, run }: { data: DataState; run: RunAction }) {
  return (
    <Panel title="Góp ý và báo lỗi từ người dùng">
      <Table
        rows={data.feedback}
        columns={[
          ['type', 'Loại'],
          ['content', 'Nội dung'],
          [(row: Feedback) => new Date(row.createdAt).toLocaleString('vi-VN'), 'Thời gian'],
        ]}
        onDelete={(row) => run(() => api.remove(`/admin/feedback/${row.id}`), 'Đã xóa góp ý')}
      />
    </Panel>
  );
}

function SettingsPanel({ onSaved }: { onSaved: () => void }) {
  const [value, setValue] = useState(getApiBaseUrl());
  return (
    <Panel title="Cấu hình kết nối API">
      <form
        className="form"
        onSubmit={(event) => {
          event.preventDefault();
          setApiBaseUrl(value);
          void onSaved();
        }}
      >
        <label>
          API Base URL
          <input value={value} onChange={(event) => setValue(event.target.value)} />
        </label>
        <button className="primary" type="submit">
          <Save size={16} />
          Lưu cấu hình
        </button>
      </form>
    </Panel>
  );
}

type RunAction = (action: () => Promise<unknown>, message: string) => Promise<void>;
type Field = [name: string, label: string, type?: string, options?: string[][]];

function SmartForm({ fields, onSubmit }: { fields: Field[]; onSubmit: (values: Record<string, string>) => void }) {
  const initial = useMemo(() => Object.fromEntries(fields.map(([name]) => [name, ''])), [fields]);
  const [values, setValues] = useState<Record<string, string>>(initial);

  function submit(event: FormEvent) {
    event.preventDefault();
    onSubmit(values);
    setValues(initial);
  }

  return (
    <form className="form" onSubmit={submit}>
      {fields.map(([name, label, type = 'text', options]) => (
        <label key={name}>
          {label}
          {type === 'select' ? (
            <select value={values[name]} onChange={(event) => setValues({ ...values, [name]: event.target.value })} required>
              <option value="">Chọn...</option>
              {options?.map(([value, optionLabel]) => (
                <option key={value} value={value}>
                  {optionLabel}
                </option>
              ))}
            </select>
          ) : type.startsWith('upload:') ? (
            <UploadField
              kind={type.replace('upload:', '') as never}
              value={values[name]}
              onUploaded={(url) => setValues({ ...values, [name]: url })}
            />
          ) : label === 'Mô tả' || label === 'Nội dung' ? (
            <textarea value={values[name]} onChange={(event) => setValues({ ...values, [name]: event.target.value })} />
          ) : (
            <input type={type} value={values[name]} onChange={(event) => setValues({ ...values, [name]: event.target.value })} required={['name', 'title', 'url', 'audioUrl', 'videoUrl', 'imageUrl', 'content'].includes(name)} />
          )}
        </label>
      ))}
      <button className="primary" type="submit">
        <Save size={16} />
        Lưu
      </button>
    </form>
  );
}

function UploadField({
  kind,
  value,
  onUploaded,
}: {
  kind: Parameters<typeof uploadToR2>[1];
  value: string;
  onUploaded: (url: string) => void;
}) {
  const [uploading, setUploading] = useState(false);
  const accept = kind === 'audio' ? 'audio/mpeg,.mp3' : kind === 'video' ? 'video/mp4,.mp4' : 'image/*';

  async function onFileSelected(file?: File) {
    if (!file) return;
    setUploading(true);
    try {
      onUploaded(await uploadToR2(file, kind));
    } finally {
      setUploading(false);
    }
  }

  return (
    <div className="upload-field">
      <label className="upload-button">
        <Upload size={16} />
        {uploading ? 'Đang upload...' : 'Chọn tệp'}
        <input type="file" accept={accept} onChange={(event) => void onFileSelected(event.target.files?.[0])} />
      </label>
      <input value={value} onChange={(event) => onUploaded(event.target.value)} placeholder="Hoặc dán URL có sẵn" />
      {value && kind.startsWith('images/') && <img className="preview-image" src={value} alt="Xem trước" />}
    </div>
  );
}

function Panel({ title, children, className = '' }: { title: string; children: React.ReactNode; className?: string }) {
  return (
    <section className={`panel ${className}`}>
      <h2>{title}</h2>
      {children}
    </section>
  );
}

function Table<T extends { id: string }>({
  rows,
  columns,
  onDelete,
}: {
  rows: T[];
  columns: Array<[keyof T | ((row: T) => React.ReactNode), string]>;
  onDelete?: (row: T) => void;
}) {
  if (rows.length === 0) return <div className="empty">Chưa có dữ liệu.</div>;

  return (
    <div className="table-wrap">
      <table>
        <thead>
          <tr>
            {columns.map(([, label]) => (
              <th key={label}>{label}</th>
            ))}
            {onDelete && <th />}
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <tr key={row.id}>
              {columns.map(([field, label]) => {
                const value = typeof field === 'function' ? field(row) : (row[field] as React.ReactNode);
                const isImage = typeof value === 'string' && /^https?:\/\//.test(value) && label === 'Ảnh';
                return (
                  <td key={label}>
                    {isImage ? <img className="table-image" src={value} alt="" /> : value || '-'}
                  </td>
                );
              })}
              {onDelete && (
                <td className="actions">
                  <button className="danger" onClick={() => onDelete(row)}>
                    <Trash2 size={15} />
                    Xóa
                  </button>
                </td>
              )}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

createRoot(document.getElementById('root')!).render(<App />);
