import React, { FormEvent, useEffect, useMemo, useState } from 'react';
import { createRoot } from 'react-dom/client';
import {
  BarChart3,
  BookAudio,
  Clapperboard,
  FileText,
  Image,
  LayoutDashboard,
  MessageSquareText,
  Newspaper,
  Quote,
  RefreshCcw,
  Save,
  Settings,
  Trash2,
} from 'lucide-react';

import {
  api,
  Audio,
  AudioCategory,
  Banner,
  Feedback,
  getApiBaseUrl,
  Quote as QuoteRecord,
  RssSource,
  setApiBaseUrl,
  Video,
  VideoCategory,
} from './lib/api';
import './styles.css';

type Section = 'overview' | 'audio' | 'video' | 'rss' | 'quote' | 'banner' | 'feedback' | 'settings';

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
};

const nav = [
  { id: 'overview', label: 'Tong quan', icon: LayoutDashboard },
  { id: 'audio', label: 'Kinh audio', icon: BookAudio },
  { id: 'video', label: 'Video giang', icon: Clapperboard },
  { id: 'rss', label: 'Nguon RSS', icon: Newspaper },
  { id: 'quote', label: 'Loi nhac', icon: Quote },
  { id: 'banner', label: 'Banner', icon: Image },
  { id: 'feedback', label: 'Gop y', icon: MessageSquareText },
  { id: 'settings', label: 'Cau hinh', icon: Settings },
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
      ]);
      setData({ overview, audioCategories, videoCategories, audios, videos, rss, quotes, banners, feedback });
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Khong tai duoc du lieu');
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
      setError(caught instanceof Error ? caught.message : 'Thao tac that bai');
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
            <strong>Phap Tam</strong>
            <small>Admin Console</small>
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
            <p>Bang dieu khien noi dung</p>
            <h1>{nav.find((item) => item.id === section)?.label}</h1>
          </div>
          <button className="ghost" onClick={() => void load()}>
            <RefreshCcw size={16} />
            Tai lai
          </button>
        </header>

        {notice && <div className="notice">{notice}</div>}
        {error && <div className="error">{error}</div>}
        {loading ? <div className="loading">Dang tai du lieu...</div> : null}

        {!loading && (
          <>
            {section === 'overview' && <Overview data={data} />}
            {section === 'audio' && <AudioManager data={data} run={run} />}
            {section === 'video' && <VideoManager data={data} run={run} />}
            {section === 'rss' && <RssManager data={data} run={run} />}
            {section === 'quote' && <QuoteManager data={data} run={run} />}
            {section === 'banner' && <BannerManager data={data} run={run} />}
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
    ['Danh muc audio', data.overview.audioCategoryCount ?? 0, BookAudio],
    ['Bai kinh audio', data.overview.audioCount ?? 0, FileText],
    ['Video', data.overview.videoCount ?? 0, Clapperboard],
    ['Nguon RSS', data.overview.rssCount ?? 0, Newspaper],
    ['Gop y', data.overview.feedbackCount ?? 0, MessageSquareText],
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
          <h2>Trang quan tri da san sang</h2>
          <p>Quan ly danh muc, audio, video, RSS, banner, loi nhac va gop y. Upload media se hoat dong sau khi cau hinh Cloudflare R2 trong backend.</p>
        </div>
      </article>
    </section>
  );
}

function AudioManager({ data, run }: { data: DataState; run: RunAction }) {
  return (
    <div className="two-column">
      <Panel title="Tao danh muc audio">
        <SmartForm
          fields={[['name', 'Ten danh muc'], ['description', 'Mo ta']]}
          onSubmit={(values) => run(() => api.create('/admin/audio-category', values), 'Da tao danh muc audio')}
        />
      </Panel>
      <Panel title="Them kinh audio">
        <SmartForm
          fields={[
            ['title', 'Tieu de'],
            ['description', 'Mo ta'],
            ['audioUrl', 'URL file audio'],
            ['thumbnailUrl', 'URL anh dai dien'],
            ['duration', 'Thoi luong giay', 'number'],
            ['categoryId', 'Danh muc', 'select', data.audioCategories.map((item) => [item.id, item.name])],
          ]}
          onSubmit={(values) => run(() => api.create('/admin/audio', { ...values, duration: Number(values.duration || 0) }), 'Da them audio')}
        />
      </Panel>
      <Panel title="Danh muc audio" className="span">
        <Table
          rows={data.audioCategories}
          columns={[
            ['name', 'Ten'],
            ['description', 'Mo ta'],
            [(row: AudioCategory) => row._count?.audios ?? 0, 'So audio'],
          ]}
          onDelete={(row) => run(() => api.remove(`/admin/audio-category/${row.id}`), 'Da xoa danh muc')}
        />
      </Panel>
      <Panel title="Danh sach audio" className="span">
        <Table
          rows={data.audios}
          columns={[
            ['title', 'Tieu de'],
            [(row: Audio) => row.category?.name ?? '-', 'Danh muc'],
            [(row: Audio) => `${row.duration}s`, 'Thoi luong'],
            ['audioUrl', 'Audio URL'],
          ]}
          onDelete={(row) => run(() => api.remove(`/admin/audio/${row.id}`), 'Da xoa audio')}
        />
      </Panel>
    </div>
  );
}

function VideoManager({ data, run }: { data: DataState; run: RunAction }) {
  return (
    <div className="two-column">
      <Panel title="Tao danh muc video">
        <SmartForm
          fields={[['name', 'Ten danh muc'], ['description', 'Mo ta']]}
          onSubmit={(values) => run(() => api.create('/admin/video-category', values), 'Da tao danh muc video')}
        />
      </Panel>
      <Panel title="Them video giang">
        <SmartForm
          fields={[
            ['title', 'Tieu de'],
            ['teacher', 'Giang su'],
            ['description', 'Mo ta'],
            ['videoUrl', 'URL video / YouTube'],
            ['thumbnailUrl', 'URL anh dai dien'],
            ['categoryId', 'Danh muc', 'select', data.videoCategories.map((item) => [item.id, item.name])],
          ]}
          onSubmit={(values) => run(() => api.create('/admin/video', values), 'Da them video')}
        />
      </Panel>
      <Panel title="Danh muc video" className="span">
        <Table
          rows={data.videoCategories}
          columns={[
            ['name', 'Ten'],
            ['description', 'Mo ta'],
            [(row: VideoCategory) => row._count?.videos ?? 0, 'So video'],
          ]}
          onDelete={(row) => run(() => api.remove(`/admin/video-category/${row.id}`), 'Da xoa danh muc')}
        />
      </Panel>
      <Panel title="Danh sach video" className="span">
        <Table
          rows={data.videos}
          columns={[
            ['title', 'Tieu de'],
            ['teacher', 'Giang su'],
            [(row: Video) => row.category?.name ?? '-', 'Danh muc'],
            ['videoUrl', 'Video URL'],
          ]}
          onDelete={(row) => run(() => api.remove(`/admin/video/${row.id}`), 'Da xoa video')}
        />
      </Panel>
    </div>
  );
}

function RssManager({ data, run }: { data: DataState; run: RunAction }) {
  return (
    <div className="single-column">
      <Panel title="Them nguon RSS">
        <SmartForm
          fields={[['name', 'Ten website'], ['url', 'RSS URL']]}
          onSubmit={(values) => run(() => api.create('/admin/rss', { ...values, active: true }), 'Da them RSS')}
        />
      </Panel>
      <Panel title="Nguon RSS dang quan ly">
        <Table
          rows={data.rss}
          columns={[
            ['name', 'Ten'],
            ['url', 'URL'],
            [(row: RssSource) => (row.active ? 'Dang bat' : 'Tat'), 'Trang thai'],
          ]}
          onDelete={(row) => run(() => api.remove(`/admin/rss/${row.id}`), 'Da xoa RSS')}
        />
      </Panel>
    </div>
  );
}

function QuoteManager({ data, run }: { data: DataState; run: RunAction }) {
  return (
    <div className="single-column">
      <Panel title="Tao loi nhac hang ngay">
        <SmartForm
          fields={[['content', 'Noi dung'], ['imageUrl', 'URL anh']]}
          onSubmit={(values) => run(() => api.create('/admin/quote', values), 'Da tao loi nhac')}
        />
      </Panel>
      <Panel title="Loi nhac">
        <Table
          rows={data.quotes}
          columns={[
            ['content', 'Noi dung'],
            ['imageUrl', 'Anh'],
            [(row: QuoteRecord) => (row.active ? 'Dang bat' : 'Tat'), 'Trang thai'],
          ]}
          onDelete={(row) => run(() => api.remove(`/admin/quote/${row.id}`), 'Da xoa loi nhac')}
        />
      </Panel>
    </div>
  );
}

function BannerManager({ data, run }: { data: DataState; run: RunAction }) {
  return (
    <div className="single-column">
      <Panel title="Tao banner">
        <SmartForm
          fields={[['imageUrl', 'URL anh banner'], ['link', 'Lien ket']]}
          onSubmit={(values) => run(() => api.create('/admin/banner', values), 'Da tao banner')}
        />
      </Panel>
      <Panel title="Banner">
        <Table
          rows={data.banners}
          columns={[
            ['imageUrl', 'Anh'],
            ['link', 'Lien ket'],
            [(row: Banner) => (row.active ? 'Dang bat' : 'Tat'), 'Trang thai'],
          ]}
          onDelete={(row) => run(() => api.remove(`/admin/banner/${row.id}`), 'Da xoa banner')}
        />
      </Panel>
    </div>
  );
}

function FeedbackManager({ data, run }: { data: DataState; run: RunAction }) {
  return (
    <Panel title="Gop y va bao loi tu nguoi dung">
      <Table
        rows={data.feedback}
        columns={[
          ['type', 'Loai'],
          ['content', 'Noi dung'],
          [(row: Feedback) => new Date(row.createdAt).toLocaleString('vi-VN'), 'Thoi gian'],
        ]}
        onDelete={(row) => run(() => api.remove(`/admin/feedback/${row.id}`), 'Da xoa gop y')}
      />
    </Panel>
  );
}

function SettingsPanel({ onSaved }: { onSaved: () => void }) {
  const [value, setValue] = useState(getApiBaseUrl());
  return (
    <Panel title="Cau hinh ket noi API">
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
          Luu cau hinh
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
              <option value="">Chon...</option>
              {options?.map(([value, optionLabel]) => (
                <option key={value} value={value}>
                  {optionLabel}
                </option>
              ))}
            </select>
          ) : label === 'Mo ta' || label === 'Noi dung' ? (
            <textarea value={values[name]} onChange={(event) => setValues({ ...values, [name]: event.target.value })} />
          ) : (
            <input type={type} value={values[name]} onChange={(event) => setValues({ ...values, [name]: event.target.value })} required={['name', 'title', 'url', 'audioUrl', 'videoUrl', 'imageUrl', 'content'].includes(name)} />
          )}
        </label>
      ))}
      <button className="primary" type="submit">
        <Save size={16} />
        Luu
      </button>
    </form>
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
  if (rows.length === 0) return <div className="empty">Chua co du lieu.</div>;

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
                return <td key={label}>{value || '-'}</td>;
              })}
              {onDelete && (
                <td className="actions">
                  <button className="danger" onClick={() => onDelete(row)}>
                    <Trash2 size={15} />
                    Xoa
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
