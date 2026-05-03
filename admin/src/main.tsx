import React, { FormEvent, useEffect, useMemo, useRef, useState } from 'react';
import { createRoot } from 'react-dom/client';
import JSZip from 'jszip';
import { Node as TiptapNode, mergeAttributes } from '@tiptap/core';
import ImageExtension from '@tiptap/extension-image';
import LinkExtension from '@tiptap/extension-link';
import PlaceholderExtension from '@tiptap/extension-placeholder';
import TextAlignExtension from '@tiptap/extension-text-align';
import UnderlineExtension from '@tiptap/extension-underline';
import Superscript from '@tiptap/extension-superscript';
import { TextStyle } from '@tiptap/extension-text-style';
import { Color } from '@tiptap/extension-color';
import Highlight from '@tiptap/extension-highlight';
import { EditorContent, useEditor } from '@tiptap/react';
import StarterKit from '@tiptap/starter-kit';
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
  Bold,
  BookAudio,
  BookOpenText,
  CalendarClock,
  Clapperboard,
  Eraser,
  Download,
  FileText,
  Eye,
  Heading2,
  Heading3,
  Image,
  ImagePlus,
  Italic,
  AlignCenter,
  AlignJustify,
  AlignLeft,
  AlignRight,
  LayoutDashboard,
  Link2,
  List,
  ListOrdered,
  MessageSquareText,
  Newspaper,
  Pause,
  Pencil,
  Play,
  Plus,
  Power,
  ShieldCheck,
  Quote,
  RefreshCcw,
  Save,
  Settings,
  Share2,
  Strikethrough,
  Superscript as SuperscriptIcon,
  Baseline,
  Highlighter,
  Trash2,
  Underline,
  Unlink,
  Upload,
  Video as VideoIcon,
} from 'lucide-react';

import {
  api,
  AdminUser,
  AppSettings,
  Audio,
  AudioCategory,
  Banner,
  Feedback,
  getApiBaseUrl,
  MeditationProgram,
  NewsCategory,
  NewsItem,
  Quote as QuoteRecord,
  QuoteRotation,
  R2Usage,
  RssSource,
  setApiBaseUrl,
  Scripture,
  ScriptureLine,
  ScriptureReminder,
  uploadToR2,
  Video,
  VideoCategory,
} from './lib/api';
import './styles.css';

type EditableScriptureLine = { content: string; start_time: number };

const scriptureRawPlaceholder = 'Nam mô A Di Đà Phật\nNguyện đem công đức này\nHướng về khắp tất cả\nĐệ tử và chúng sanh';

const scriptureSampleJson = {
  title: 'Kinh A Di Đà - bản đọc mẫu',
  description: 'Mẫu JSON cho chức năng Đọc Kinh. Mỗi dòng cần có content và start_time tính bằng giây.',
  categoryId: '',
  lines: [
    { content: 'Nam mô Bổn Sư Thích Ca Mâu Ni Phật', start_time: 0 },
    { content: 'Như thị ngã văn.', start_time: 5.2 },
    { content: 'Một thời Đức Phật ở nước Xá Vệ, tại vườn Kỳ Thọ Cấp Cô Độc.', start_time: 9.8 },
    { content: 'Cùng với chúng đại Tỳ kheo, một ngàn hai trăm năm mươi vị.', start_time: 17.6 },
    { content: 'Lại có các vị Bồ Tát Ma Ha Tát cùng dự trong pháp hội.', start_time: 24.4 },
    { content: 'Bấy giờ Đức Phật bảo Trưởng lão Xá Lợi Phất rằng.', start_time: 31.2 },
    { content: 'Từ đây qua phương Tây, cách mười muôn ức cõi Phật.', start_time: 37.4 },
    { content: 'Có thế giới tên là Cực Lạc, trong cõi ấy có Đức Phật hiệu A Di Đà.', start_time: 44.6 },
  ],
};

function linesFromText(text: string): EditableScriptureLine[] {
  return text
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean)
    .map((content, index) => ({ content, start_time: index * 4 }));
}

function normalizeImportedLines(lines: ScriptureLine[]): EditableScriptureLine[] {
  return lines
    .map((line, index) => ({
      content: String(line.content ?? '').trim(),
      start_time: Number(line.start_time ?? line.startTime ?? index * 4),
    }))
    .filter((line) => line.content);
}

function scriptureDraftSnapshot(draft: {
  title: string;
  description: string;
  backgroundImageUrl: string;
  categoryId: string;
  rawText: string;
  lines: EditableScriptureLine[];
}) {
  return JSON.stringify({
    title: draft.title.trim(),
    description: draft.description.trim(),
    backgroundImageUrl: draft.backgroundImageUrl.trim(),
    categoryId: draft.categoryId,
    rawText: draft.rawText.trim(),
    lines: draft.lines.map((line) => ({
      content: line.content.trim(),
      start_time: Number(line.start_time || 0),
    })),
  });
}

function downloadScriptureSample() {
  const blob = new Blob([JSON.stringify(scriptureSampleJson, null, 2)], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement('a');
  anchor.href = url;
  anchor.download = 'mau-doc-kinh.json';
  anchor.click();
  URL.revokeObjectURL(url);
}

async function extractDocxText(file: File) {
  const zip = await JSZip.loadAsync(file);
  const documentXml = await zip.file('word/document.xml')?.async('string');
  if (!documentXml) throw new Error('Không tìm thấy nội dung word/document.xml trong tệp DOCX');

  const xml = new DOMParser().parseFromString(documentXml, 'application/xml');
  return Array.from(xml.getElementsByTagName('w:p'))
    .map((paragraph) =>
      Array.from(paragraph.getElementsByTagName('w:t'))
        .map((node) => node.textContent ?? '')
        .join('')
        .trim(),
    )
    .filter(Boolean)
    .join('\n');
}

type Section = 'overview' | 'audio' | 'scripture' | 'reminder' | 'video' | 'meditation' | 'news' | 'rss' | 'quote' | 'banner' | 'users' | 'feedback' | 'settings';

type DataState = {
  overview: Record<string, number>;
  settings: AppSettings;
  audioCategories: AudioCategory[];
  videoCategories: VideoCategory[];
  audios: Audio[];
  scriptures: Scripture[];
  scriptureReminders: ScriptureReminder[];
  videos: Video[];
  meditationPrograms: MeditationProgram[];
  rss: RssSource[];
  newsCategories: NewsCategory[];
  news: NewsItem[];
  quotes: QuoteRecord[];
  quoteRotation: QuoteRotation;
  banners: Banner[];
  feedback: Feedback[];
  users: AdminUser[];
};

const emptyData: DataState = {
  overview: {},
  settings: { contentPageSize: 10 },
  audioCategories: [],
  videoCategories: [],
  audios: [],
  scriptures: [],
  scriptureReminders: [],
  videos: [],
  meditationPrograms: [],
  rss: [],
  newsCategories: [],
  news: [],
  quotes: [],
  quoteRotation: { enabled: false, paused: false, quoteIds: [], startDate: '', offset: 0, currentQuoteId: null },
  banners: [],
  feedback: [],
  users: [],
};

const nav = [
  { id: 'overview', label: 'Tổng quan', icon: LayoutDashboard },
  { id: 'audio', label: 'Kinh audio', icon: BookAudio },
  { id: 'scripture', label: 'Đọc Kinh', icon: BookOpenText },
  { id: 'reminder', label: 'Lịch nhắc tụng kinh', icon: CalendarClock },
  { id: 'video', label: 'Video giảng', icon: Clapperboard },
  { id: 'meditation', label: 'Thiền', icon: Pause },
  { id: 'news', label: 'Tin tức', icon: Newspaper },
  { id: 'rss', label: 'Nguồn RSS', icon: Newspaper },
  { id: 'quote', label: 'Trích dẫn', icon: Quote },
  { id: 'banner', label: 'Banner', icon: Image },
  { id: 'users', label: 'Tài khoản', icon: ShieldCheck },
  { id: 'feedback', label: 'Góp ý', icon: MessageSquareText },
  { id: 'settings', label: 'Cấu hình', icon: Settings },
] as const;

const SettingsContext = React.createContext<AppSettings>({ contentPageSize: 10 });


function Login({ onLogin }: { onLogin: () => void }) {
  const [mode, setMode] = useState<'login' | 'forgot' | 'reset'>('login');
  const [identifier, setIdentifier] = useState('');
  const [password, setPassword] = useState('');
  const [otp, setOtp] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  const cardStyle: React.CSSProperties = { width: '100%', maxWidth: '400px', padding: '32px', background: '#fffcf0', borderRadius: '18px', boxShadow: '0 22px 60px rgba(72, 48, 38, .08)' };
  const inputStyle: React.CSSProperties = { width: '100%', padding: '10px 14px', borderRadius: '10px', border: '1px solid #d6c4a0', background: '#fdf8ef', boxSizing: 'border-box' };
  const btnPrimary: React.CSSProperties = { width: '100%', padding: '12px', background: '#8b5e3c', color: '#fff', border: 'none', borderRadius: '12px', cursor: 'pointer', fontWeight: 'bold', fontSize: '15px', marginTop: '8px' };
  const btnLink: React.CSSProperties = { background: 'none', border: 'none', color: '#8b5e3c', cursor: 'pointer', textDecoration: 'underline', fontSize: '13px', padding: 0 };
  const fieldStyle: React.CSSProperties = { display: 'grid', gap: '6px', marginBottom: '14px' };
  const labelStyle: React.CSSProperties = { fontSize: '13px', fontWeight: 600, color: '#6b4c30' };

  async function handleLogin(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true); setError('');
    try {
      const res = await api.login({ email: identifier, password });
      localStorage.setItem('phaptam_admin_token', res.accessToken);
      onLogin();
    } catch (err: any) { setError(err.message || 'Sai tài khoản hoặc mật khẩu'); }
    finally { setLoading(false); }
  }

  async function handleForgot(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true); setError(''); setSuccess('');
    try {
      await api.post('/auth/forgot-password', { identifier });
      setSuccess('Nếu tài khoản tồn tại, mã OTP đã được gửi đến Email. Kiểm tra hộp thư đến (và thư mục Spam).');
      setMode('reset');
    } catch (err: any) { setError(err.message || 'Không gửi được email'); }
    finally { setLoading(false); }
  }

  async function handleReset(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true); setError(''); setSuccess('');
    try {
      await api.post('/auth/reset-password', { identifier, otp, newPassword });
      setSuccess('Đặt lại mật khẩu thành công! Đang chuyển đến đăng nhập...');
      setTimeout(() => { setMode('login'); setSuccess(''); setOtp(''); setNewPassword(''); }, 2000);
    } catch (err: any) { setError(err.message || 'Mã OTP không đúng hoặc đã hết hạn'); }
    finally { setLoading(false); }
  }

  return (
    <div style={{ display: 'grid', placeItems: 'center', minHeight: '100vh', background: 'linear-gradient(135deg, #f6f0dd 0%, #e8d9b0 100%)' }}>
      <div style={cardStyle}>
        <h2 style={{ textAlign: 'center', fontFamily: '"Noto Serif", serif', color: '#8b5e3c', margin: '0 0 4px' }}>🙏 Pháp Tâm</h2>
        <p style={{ textAlign: 'center', color: '#9a7d5a', fontSize: '13px', margin: '0 0 24px' }}>
          {mode === 'login' ? 'Quản trị viên' : mode === 'forgot' ? 'Quên mật khẩu' : 'Đặt lại mật khẩu'}
        </p>

        {error && <div style={{ color: '#dc2626', background: '#fef2f2', border: '1px solid #fecaca', borderRadius: '8px', padding: '10px 14px', marginBottom: '16px', fontSize: '13px' }}>{error}</div>}
        {success && <div style={{ color: '#16a34a', background: '#f0fdf4', border: '1px solid #bbf7d0', borderRadius: '8px', padding: '10px 14px', marginBottom: '16px', fontSize: '13px' }}>{success}</div>}

        {mode === 'login' && (
          <form onSubmit={handleLogin}>
            <div style={fieldStyle}>
              <span style={labelStyle}>Tài khoản / Email</span>
              <input style={inputStyle} value={identifier} onChange={(e) => setIdentifier(e.target.value)} required placeholder="admin hoặc email@gmail.com" autoFocus />
            </div>
            <div style={fieldStyle}>
              <span style={labelStyle}>Mật khẩu</span>
              <input style={inputStyle} type="password" value={password} onChange={(e) => setPassword(e.target.value)} required placeholder="••••••••" />
            </div>
            <button style={btnPrimary} type="submit" disabled={loading}>{loading ? 'Đang xử lý...' : 'Đăng nhập'}</button>
            <div style={{ textAlign: 'center', marginTop: '16px' }}>
              <button type="button" style={btnLink} onClick={() => { setMode('forgot'); setError(''); setSuccess(''); }}>Quên mật khẩu?</button>
            </div>
          </form>
        )}

        {mode === 'forgot' && (
          <form onSubmit={handleForgot}>
            <p style={{ fontSize: '13px', color: '#6b7280', marginBottom: '16px' }}>Nhập Email hoặc Username của tài khoản. Hệ thống sẽ gửi mã OTP 6 số về Email đã đăng ký.</p>
            <div style={fieldStyle}>
              <span style={labelStyle}>Tài khoản / Email</span>
              <input style={inputStyle} value={identifier} onChange={(e) => setIdentifier(e.target.value)} required placeholder="admin hoặc email@gmail.com" autoFocus />
            </div>
            <button style={btnPrimary} type="submit" disabled={loading}>{loading ? 'Đang gửi...' : 'Gửi mã OTP'}</button>
            <div style={{ textAlign: 'center', marginTop: '12px' }}>
              <button type="button" style={btnLink} onClick={() => { setMode('login'); setError(''); setSuccess(''); }}>← Quay lại đăng nhập</button>
            </div>
          </form>
        )}

        {mode === 'reset' && (
          <form onSubmit={handleReset}>
            <p style={{ fontSize: '13px', color: '#6b7280', marginBottom: '16px' }}>Kiểm tra Email và nhập mã OTP 6 số cùng mật khẩu mới.</p>
            <div style={fieldStyle}>
              <span style={labelStyle}>Mã OTP (6 số)</span>
              <input style={inputStyle} value={otp} onChange={(e) => setOtp(e.target.value)} required placeholder="123456" maxLength={6} autoFocus />
            </div>
            <div style={fieldStyle}>
              <span style={labelStyle}>Mật khẩu mới (tối thiểu 8 ký tự)</span>
              <input style={inputStyle} type="password" value={newPassword} onChange={(e) => setNewPassword(e.target.value)} required minLength={8} placeholder="••••••••" />
            </div>
            <button style={btnPrimary} type="submit" disabled={loading}>{loading ? 'Đang xử lý...' : 'Đặt lại mật khẩu'}</button>
            <div style={{ textAlign: 'center', marginTop: '12px', display: 'flex', justifyContent: 'center', gap: '16px' }}>
              <button type="button" style={btnLink} onClick={() => { setMode('forgot'); setError(''); setSuccess(''); }}>Gửi lại mã OTP</button>
              <span style={{ color: '#d1d5db' }}>|</span>
              <button type="button" style={btnLink} onClick={() => { setMode('login'); setError(''); setSuccess(''); }}>← Đăng nhập</button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
}

function App() {
  const [isAuthenticated, setIsAuthenticated] = useState(Boolean(localStorage.getItem('phaptam_admin_token')));

  const getHashSection = (): Section => {
    const hash = window.location.hash.slice(1);
    const validSections: Section[] = ['overview', 'audio', 'video', 'scripture', 'reminder', 'news', 'quote', 'banner', 'meditation', 'rss', 'users', 'feedback', 'settings'];
    return validSections.includes(hash as Section) ? (hash as Section) : 'overview';
  };

  const [section, setSectionState] = useState<Section>(getHashSection());
  const [data, setData] = useState<DataState>(emptyData);
  const [loading, setLoading] = useState(true);
  const [notice, setNotice] = useState('');
  const [error, setError] = useState('');

  useEffect(() => {
    const onHashChange = () => setSectionState(getHashSection());
    window.addEventListener('hashchange', onHashChange);
    return () => window.removeEventListener('hashchange', onHashChange);
  }, []);

  const setSection = (s: Section) => {
    window.location.hash = s;
    setSectionState(s);
  };

  async function load() {
    setLoading(true);
    setError('');
    try {
      const safe = async <T,>(action: () => Promise<T>, fallback: T) => {
        try {
          return await action();
        } catch {
          return fallback;
        }
      };

      const [
        overview,
        settings,
        audioCategories,
        videoCategories,
        audios,
        scriptures,
        scriptureReminders,
        videos,
        meditationPrograms,
        rss,
        newsCategories,
        news,
        quotes,
        quoteRotation,
        banners,
        feedback,
        users,
      ] = await Promise.all([
        safe(() => api.overview(), {}),
        safe(() => api.settings(), { contentPageSize: 10 }),
        safe(() => api.audioCategories(), []),
        safe(() => api.videoCategories(), []),
        safe(() => api.audios(), []),
        safe(() => api.scriptures(), []),
        safe(() => api.scriptureReminders(), []),
        safe(() => api.videos(), []),
        safe(() => api.meditationPrograms(), []),
        safe(() => api.rss(), []),
        safe(() => api.newsCategories(), []),
        safe(() => api.news(), []),
        safe(() => api.quotes(), []),
        safe(() => api.quoteRotation(), { enabled: false, paused: false, quoteIds: [], startDate: '', offset: 0, currentQuoteId: null }),
        safe(() => api.banners(), []),
        safe(() => api.feedback(), []),
        safe(() => api.users(), []),
      ]);

      setData({
        overview,
        settings,
        audioCategories,
        videoCategories,
        audios,
        scriptures,
        scriptureReminders,
        videos,
        meditationPrograms,
        rss,
        newsCategories,
        news,
        quotes,
        quoteRotation,
        banners,
        feedback,
        users,
      });
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Tải dữ liệu thất bại');
      if (caught instanceof Error && (caught.message.includes('401') || caught.message.includes('Unauthorized') || caught.message.includes('403'))) {
        localStorage.removeItem('phaptam_admin_token');
        setIsAuthenticated(false);
      }
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    if (isAuthenticated) void load();
  }, [isAuthenticated]);

  async function run(action: () => Promise<unknown>, message: string): Promise<boolean> {
    setError('');
    setNotice('');
    try {
      await action();
      setNotice(message);
      void load();
      return true;
    } catch (caught) {
      const msg = caught instanceof Error ? caught.message : 'Thao tác thất bại';
      setError(msg);
      if (msg.includes('401') || msg.includes('Unauthorized') || msg.includes('403')) {
        localStorage.removeItem('phaptam_admin_token');
        setIsAuthenticated(false);
      }
      return false;
    }
  }

  useEffect(() => {
    if (notice) {
      const timer = window.setTimeout(() => setNotice(''), 3000);
      return () => window.clearTimeout(timer);
    }
  }, [notice]);

  function handleLogout() {
    localStorage.removeItem('phaptam_admin_token');
    setIsAuthenticated(false);
  }

  if (!isAuthenticated) return <Login onLogin={() => setIsAuthenticated(true)} />;

  const menu: [Section, string, React.ReactNode][] = [
    ['overview', 'Tổng quan', <BarChart3 size={16} />],
    ['audio', 'Audio', <BookAudio size={16} />],
    ['video', 'Video', <Clapperboard size={16} />],
    ['scripture', 'Kinh điển', <BookOpenText size={16} />],
    ['reminder', 'Lịch nhắc tụng kinh', <CalendarClock size={16} />],
    ['meditation', 'Chương trình thiền', <List size={16} />],
    ['news', 'Tin tức', <Newspaper size={16} />],
    ['quote', 'Trích dẫn', <Quote size={16} />],
    ['banner', 'Banner', <Image size={16} />],
    ['rss', 'RSS Nguồn', <RefreshCcw size={16} />],
    ['users', 'Người dùng', <FileText size={16} />],
    ['feedback', 'Phản hồi', <MessageSquareText size={16} />],
    ['settings', 'Cài đặt', <Settings size={16} />],
  ];

  return (
    <SettingsContext.Provider value={data.settings}>
      <div className="app-shell">
        <div className="sidebar">
          <div className="brand">
            <div className="brand-mark">PT</div>
            <div>
              <strong>Pháp Tâm Admin</strong>
              <small>Hệ thống Quản trị v0.1.0</small>
            </div>
          </div>
          <nav>
            {menu.map(([id, label, icon]) => (
              <button key={id} className={section === id ? 'active' : ''} type="button" onClick={() => setSection(id)}>
                {icon}
                {label}
              </button>
            ))}
            <button type="button" onClick={handleLogout} style={{ marginTop: '20px', color: '#f87171' }}>
              <Power size={16} />
              Đăng xuất
            </button>
          </nav>
        </div>
        <main>
          <div className="topbar">
            <div>
              <p>Menu</p>
              <h1>{menu.find((m) => m[0] === section)?.[1]}</h1>
            </div>
            <div>
              {notice && <span style={{ color: '#059669', marginRight: '16px', fontWeight: 'bold' }}>{notice}</span>}
              {error && <span style={{ color: '#dc2626', marginRight: '16px', fontWeight: 'bold' }}>Lỗi: {error}</span>}
              <button className="primary" type="button" onClick={load} disabled={loading}>
                <RefreshCcw size={15} />
                {loading ? 'Đang tải...' : 'Làm mới'}
              </button>
            </div>
          </div>
          {loading && data === emptyData ? (
            <div>Đang tải dữ liệu...</div>
          ) : (
            <div className="content">
              {section === 'overview' && <Overview data={data} />}
              {section === 'audio' && <AudioManager data={data} run={run} />}
              {section === 'scripture' && <ScriptureManager data={data} run={run} />}
              {section === 'reminder' && <ScriptureReminderManager data={data} />}
              {section === 'video' && <VideoManager data={data} run={run} />}
              {section === 'meditation' && <MeditationManager data={data} run={run} />}
              {section === 'news' && <NewsManager data={data} run={run} />}
              {section === 'rss' && <RssManager data={data} run={run} />}
              {section === 'quote' && <QuoteManager data={data} run={run} />}
              {section === 'banner' && <BannerManager data={data} run={run} />}
              {section === 'users' && <UserManager data={data} run={run} />}
              {section === 'feedback' && <FeedbackManager data={data} run={run} />}
              {section === 'settings' && <SettingsPanel onSaved={load} />}
            </div>
          )}
        </main>
      </div>
    </SettingsContext.Provider>
  );
}

function Overview({ data }: { data: DataState }) {
  const cards = [
    ['Danh mục audio', data.overview.audioCategoryCount ?? 0, BookAudio],
    ['Bài kinh audio', data.overview.audioCount ?? 0, FileText],
    ['Bản đọc Kinh', data.overview.scriptureCount ?? 0, BookOpenText],
    ['Lịch nhắc tụng kinh', data.overview.scriptureReminderCount ?? 0, CalendarClock],
    ['Video', data.overview.videoCount ?? 0, Clapperboard],
    ['Bài Thiền', data.overview.meditationProgramCount ?? 0, Pause],
    ['Tin tức', data.overview.newsCount ?? 0, Newspaper],
    ['Danh mục tin', data.overview.newsCategoryCount ?? 0, Newspaper],
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
          <p>Quản lý danh mục, audio, video, RSS, banner, trích dẫn, lịch nhắc tụng kinh và góp ý. Media được upload trực tiếp lên Cloudflare R2 bằng URL ký tạm thời từ backend.</p>
        </div>
      </article>
    </section>
  );
}

function AudioManager({ data, run }: { data: DataState; run: RunAction }) {
  const [editingAudio, setEditingAudio] = useState<Audio | null>(null);
  const scriptureCategoryIds = new Set(data.scriptures.map((scripture) => scripture.categoryId).filter(Boolean));
  const audioCategories = data.audioCategories.filter(
    (item) => (item._count?.audios ?? 0) > 0 || !scriptureCategoryIds.has(item.id),
  );

  function editCategory(row: AudioCategory) {
    const name = askText('Tên danh mục', row.name);
    if (name === undefined) return;
    const description = askText('Mô tả', row.description ?? '');
    if (description === undefined) return;
    void run(() => api.update(`/admin/audio-category/${row.id}`, { name, description }), 'Đã cập nhật danh mục audio');
  }

  function editAudio(row: Audio) {
    setEditingAudio(row);
  }

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
            ['audioUrl', 'Tệp audio MP3', 'upload:audio/library'],
            ['thumbnailUrl', 'Ảnh đại diện', 'upload:images/audio'],
            ['categoryId', 'Danh mục', 'select', audioCategories.map((item) => [item.id, item.name])],
          ]}
          onSubmit={async (values) => {
            const duration = await detectMediaDuration(values.audioUrl, 'audio');
            void run(() => api.create('/admin/audio', { ...values, duration }), 'Đã thêm audio');
          }}
        />
      </Panel>
      <Panel title="Danh mục audio" className="span">
        <Table
          rows={audioCategories}
          columns={[
            ['name', 'Tên'],
            ['description', 'Mô tả'],
            [(row: AudioCategory) => row._count?.audios ?? 0, 'Số audio'],
            [
              (row: AudioCategory) => (
                <button className="ghost" type="button" onClick={() => editCategory(row)}>
                  <Pencil size={15} />
                  Sửa
                </button>
              ),
              'Thao tác',
            ],
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
            [(row: Audio) => formatDurationSeconds(row.duration), 'Thời lượng'],
            [(row: Audio) => row.viewCount.toLocaleString('vi-VN'), 'Lượt xem'],
            ['audioUrl', 'Audio URL'],
            [
              (row: Audio) => (
                <button className="ghost" type="button" onClick={() => editAudio(row)}>
                  <Pencil size={15} />
                  Sửa
                </button>
              ),
              'Thao tác',
            ],
          ]}
          onDelete={(row) => run(() => api.remove(`/admin/audio/${row.id}`), 'Đã xóa audio')}
        />
      </Panel>
      {editingAudio && (
        <AudioEditModal
          audio={editingAudio}
          categories={audioCategories}
          onClose={() => setEditingAudio(null)}
          onSave={async (values) => {
            const duration = values.audioUrl === editingAudio.audioUrl
              ? editingAudio.duration
              : await detectMediaDuration(values.audioUrl, 'audio');
            const saved = await run(
              () => api.update(`/admin/audio/${editingAudio.id}`, compactPayload({ ...values, duration })),
              'Đã cập nhật audio',
            );
            if (saved) setEditingAudio(null);
          }}
        />
      )}
    </div>
  );
}

function ScriptureManager({ data, run }: { data: DataState; run: RunAction }) {
  const [selectedScriptureId, setSelectedScriptureId] = useState('');
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [backgroundImageUrl, setBackgroundImageUrl] = useState('');
  const [categoryId, setCategoryId] = useState('');
  const [scriptureStatus, setScriptureStatus] = useState('');
  const [scriptureBusy, setScriptureBusy] = useState(false);
  const [rawText, setRawText] = useState('');
  const [lines, setLines] = useState<EditableScriptureLine[]>([]);
  const autoTimingTimer = useRef<number | undefined>(undefined);
  const autoTimingRequest = useRef(0);
  const savedDraftRef = useRef(scriptureDraftSnapshot({ title: '', description: '', backgroundImageUrl: '', categoryId: '', rawText: '', lines: [] }));
  const currentDraft = useMemo(
    () => scriptureDraftSnapshot({ title, description, backgroundImageUrl, categoryId, rawText, lines }),
    [title, description, backgroundImageUrl, categoryId, rawText, lines],
  );
  const hasUnsavedChanges = currentDraft !== savedDraftRef.current;
  const scriptureCategoryIds = new Set(data.scriptures.map((scripture) => scripture.categoryId).filter(Boolean));
  const scriptureCategories = data.audioCategories.filter(
    (item) => scriptureCategoryIds.has(item.id) || (item._count?.audios ?? 0) === 0,
  );

  useEffect(() => {
    return () => window.clearTimeout(autoTimingTimer.current);
  }, []);

  function editCategory(row: AudioCategory) {
    const name = askText('Tên danh mục Đọc Kinh', row.name);
    if (name === undefined) return;
    const description = askText('Mô tả', row.description ?? '');
    if (description === undefined) return;
    void run(() => api.update(`/admin/audio-category/${row.id}`, { name, description }), 'Đã cập nhật danh mục Đọc Kinh');
  }

  function splitText() {
    const nextLines = linesFromText(rawText);
    setLines(nextLines);
    setScriptureStatus(`Đã tách ${nextLines.length} dòng Kinh.`);
    scheduleLineTiming(nextLines);
  }

  async function autoTiming(sourceLines = lines, options: { quiet?: boolean } = {}) {
    const requestId = ++autoTimingRequest.current;
    const cleanLines = sourceLines.map((line) => line.content.trim()).filter(Boolean);
    if (cleanLines.length === 0) {
      if (!options.quiet) setScriptureStatus('Chưa có nội dung để tự tính thời gian.');
      return;
    }
    setScriptureBusy(true);
    if (!options.quiet) setScriptureStatus(`Đang tự tính thời gian cho ${cleanLines.length} dòng...`);
    try {
      const generated = await api.generateScriptureTiming({ lines: cleanLines });
      if (requestId !== autoTimingRequest.current) return;
      setLines(generated);
      setRawText(generated.map((line) => line.content).join('\n'));
      setScriptureStatus(`Đã tự tính thời gian cho ${generated.length} dòng.`);
    } catch (caught) {
      setScriptureStatus(caught instanceof Error ? caught.message : 'Không tự tính được thời gian.');
    } finally {
      setScriptureBusy(false);
    }
  }

  function syncRawFromLines(nextLines: EditableScriptureLine[]) {
    setRawText(nextLines.map((line) => line.content).join('\n'));
  }

  function scheduleLineTiming(nextLines: EditableScriptureLine[]) {
    window.clearTimeout(autoTimingTimer.current);
    const cleanLines = nextLines.map((line) => line.content.trim()).filter(Boolean);
    if (cleanLines.length === 0) return;
    autoTimingTimer.current = window.setTimeout(() => {
      void autoTiming(nextLines, { quiet: true });
    }, 650);
  }

  async function importScriptureFile(file?: File) {
    if (!file) return;
    setScriptureBusy(true);
    setScriptureStatus(`Đang đọc tệp ${file.name}...`);
    try {
      const name = file.name.toLowerCase();
      if (name.endsWith('.json')) {
        const parsed = JSON.parse(await file.text());
        const importedLines = normalizeImportedLines(parsed.lines ?? []);
        setTitle(parsed.title ?? title);
        setDescription(parsed.description ?? description);
        setCategoryId(parsed.category_id ?? parsed.categoryId ?? categoryId);
        setRawText(importedLines.map((line) => line.content).join('\n'));
        setLines(importedLines);
        setScriptureStatus(`Đã nạp ${importedLines.length} dòng từ tệp JSON.`);
        return;
      }

      const text = name.endsWith('.docx') ? await extractDocxText(file) : await file.text();
      const nextLines = linesFromText(text);
      setTitle((current) => current || file.name.replace(/\.(txt|docx)$/i, ''));
      setRawText(text);
      await autoTiming(nextLines);
    } catch (caught) {
      setScriptureStatus(caught instanceof Error ? caught.message : 'Không đọc được tệp Kinh');
    } finally {
      setScriptureBusy(false);
    }
  }

  function openScripture(scripture: Scripture) {
    if (!confirmLoseChanges()) return;
    const nextLines = normalizeImportedLines(scripture.lines ?? []);
    const nextRawText = nextLines.map((line) => line.content).join('\n');
    setSelectedScriptureId(scripture.id);
    setTitle(scripture.title);
    setDescription(scripture.description ?? '');
    setBackgroundImageUrl(scripture.backgroundImageUrl ?? '');
    setCategoryId(scripture.categoryId ?? '');
    setRawText(nextRawText);
    setLines(nextLines);
    savedDraftRef.current = scriptureDraftSnapshot({
      title: scripture.title,
      description: scripture.description ?? '',
      backgroundImageUrl: scripture.backgroundImageUrl ?? '',
      categoryId: scripture.categoryId ?? '',
      rawText: nextRawText,
      lines: nextLines,
    });
    setScriptureStatus(`Đang mở "${scripture.title}" với ${nextLines.length} dòng.`);
  }

  function confirmLoseChanges() {
    if (!hasUnsavedChanges) return true;
    return window.confirm('Bạn đã thay đổi nội dung, hình ảnh, tiêu đề hoặc danh mục nhưng chưa Lưu. Nếu Hủy hoặc tạo Kinh mới thì các thay đổi này sẽ bị mất.');
  }

  function resetScriptureForm() {
    setSelectedScriptureId('');
    setTitle('');
    setDescription('');
    setBackgroundImageUrl('');
    setCategoryId('');
    setRawText('');
    setLines([]);
    savedDraftRef.current = scriptureDraftSnapshot({ title: '', description: '', backgroundImageUrl: '', categoryId: '', rawText: '', lines: [] });
    setScriptureStatus('');
  }

  function newScripture() {
    if (!confirmLoseChanges()) return;
    resetScriptureForm();
  }

  function cancelEdit() {
    if (!confirmLoseChanges()) return;
    resetScriptureForm();
  }

  async function saveScripture() {
    const saved = await run(
      () =>
        (selectedScriptureId ? api.update(`/admin/scripture/${selectedScriptureId}`, {
          title,
          description,
          backgroundImageUrl,
          categoryId,
          lines,
        }) : api.create('/admin/scripture', {
          title,
          description,
          backgroundImageUrl,
          categoryId,
          lines,
        })),
      selectedScriptureId ? 'Đã cập nhật bản Đọc Kinh' : 'Đã tạo bản Đọc Kinh',
    );
    if (saved) savedDraftRef.current = currentDraft;
  }

  function updateLine(index: number, patch: Partial<{ content: string; start_time: number }>, shouldRetiming = false) {
    const nextLines = lines.map((line, current) => (current === index ? { ...line, ...patch } : line));
    setLines(nextLines);
    syncRawFromLines(nextLines);
    if (shouldRetiming) scheduleLineTiming(nextLines);
  }

  function moveLine(index: number, direction: -1 | 1) {
    const nextIndex = index + direction;
    if (nextIndex < 0 || nextIndex >= lines.length) return;
    const next = [...lines];
    [next[index], next[nextIndex]] = [next[nextIndex], next[index]];
    setLines(next);
    syncRawFromLines(next);
    scheduleLineTiming(next);
  }

  function addLine() {
    const nextLines = [...lines, { content: '', start_time: lines.length ? lines[lines.length - 1].start_time + 4 : 0 }];
    setLines(nextLines);
    syncRawFromLines(nextLines);
  }

  function removeLine(index: number) {
    const nextLines = lines.filter((_, current) => current !== index);
    setLines(nextLines);
    syncRawFromLines(nextLines);
    scheduleLineTiming(nextLines);
  }

  return (
    <div className="single-column">
      <Panel title="Tạo danh mục Đọc Kinh">
        <SmartForm
          fields={[['name', 'Tên danh mục'], ['description', 'Mô tả']]}
          onSubmit={(values) => run(() => api.create('/admin/audio-category', values), 'Đã tạo danh mục Đọc Kinh')}
        />
      </Panel>
      <Panel title="Danh mục Đọc Kinh">
        <Table
          rows={scriptureCategories}
          columns={[
            ['name', 'Tên'],
            ['description', 'Mô tả'],
            [(row: AudioCategory) => data.scriptures.filter((scripture) => scripture.categoryId === row.id).length, 'Số bản đọc'],
            [
              (row: AudioCategory) => (
                <button className="ghost" type="button" onClick={() => editCategory(row)}>
                  <Pencil size={15} />
                  Sửa
                </button>
              ),
              'Thao tác',
            ],
          ]}
          onDelete={(row) => run(() => api.remove(`/admin/audio-category/${row.id}`), 'Đã xóa danh mục Đọc Kinh')}
        />
      </Panel>
      <Panel title="Tạo bản Đọc Kinh">
        <div className="scripture-create">
          {selectedScriptureId && (
            <div className="scripture-form-heading span">
              <div>
                <strong>Đang chỉnh sửa bản đã lưu</strong>
                {scriptureStatus && <span>{scriptureStatus}</span>}
              </div>
              <div className="action-group">
                <button className="ghost" type="button" onClick={cancelEdit}>
                  Hủy
                </button>
                <button className="ghost" type="button" onClick={newScripture}>
                  <Plus size={16} />
                  Kinh mới
                </button>
              </div>
            </div>
          )}
          <label>
            Tiêu đề
            <input value={title} onChange={(event) => setTitle(event.target.value)} placeholder="Ví dụ: Kinh A Di Đà - bản đọc chậm" />
          </label>
          <label>
            Danh mục
            <select value={categoryId} onChange={(event) => setCategoryId(event.target.value)}>
              <option value="">Không chọn</option>
              {scriptureCategories.map((item) => (
                <option key={item.id} value={item.id}>
                  {item.name}
                </option>
              ))}
            </select>
          </label>
          <label>
            Ảnh nền đọc kinh
            <UploadField kind="images/scripture" value={backgroundImageUrl} onUploaded={setBackgroundImageUrl} />
            <small className="field-note">
              Khuyến nghị 1600x2400 hoặc tỷ lệ 2:3 cho ảnh dọc. App sẽ tự phủ kín màn hình từng thiết bị, ảnh có thể được cắt nhẹ ở mép.
            </small>
          </label>
          <label className="span">
            Mô tả
            <textarea value={description} onChange={(event) => setDescription(event.target.value)} />
          </label>
          <label className="span">
            Dán nội dung Kinh, mỗi câu một dòng
            <textarea className="scripture-raw" value={rawText} placeholder={scriptureRawPlaceholder} onChange={(event) => setRawText(event.target.value)} />
          </label>
          <div className="scripture-actions span">
            <button className="ghost" type="button" onClick={splitText}>
              <FileText size={16} />
              Tách dòng
            </button>
            <button className="ghost" type="button" disabled={scriptureBusy} onClick={() => void autoTiming()}>
              <RefreshCcw size={16} />
              {scriptureBusy ? 'Đang xử lý...' : 'Tự tính thời gian'}
            </button>
            <button className="ghost" type="button" onClick={downloadScriptureSample}>
              <Download size={16} />
              Tải mẫu
            </button>
            <label className="upload-button">
              <Upload size={16} />
              Upload JSON/TXT/DOCX
              <input type="file" accept="application/json,.json,text/plain,.txt,.docx,application/vnd.openxmlformats-officedocument.wordprocessingml.document" onChange={(event) => void importScriptureFile(event.target.files?.[0])} />
            </label>
            <button
              className="primary"
              type="button"
              disabled={scriptureBusy || !title.trim() || lines.length === 0}
              onClick={() => void saveScripture()}
            >
              <Save size={16} />
              {selectedScriptureId ? 'Cập nhật bản đọc' : 'Lưu bản đọc'}
            </button>
          </div>
        </div>
      </Panel>

      <div className="scripture-editor">
        <Panel title="Dòng Kinh" className="scripture-lines-panel">
          <div className="line-editor">
            {lines.map((line, index) => (
              <div className="line-row" key={`${index}-${line.content}`}>
                <span>{index + 1}</span>
                <textarea value={line.content} onChange={(event) => updateLine(index, { content: event.target.value }, true)} />
                <input type="number" min="0" step="0.1" value={line.start_time} onChange={(event) => updateLine(index, { start_time: Number(event.target.value) })} />
                <button className="ghost icon-only" type="button" onClick={() => moveLine(index, -1)} aria-label="Đưa dòng lên">
                  ↑
                </button>
                <button className="ghost icon-only" type="button" onClick={() => moveLine(index, 1)} aria-label="Đưa dòng xuống">
                  ↓
                </button>
                <button className="danger icon-only" type="button" onClick={() => removeLine(index)} aria-label="Xóa dòng">
                  <Trash2 size={15} />
                </button>
              </div>
            ))}
          </div>
          <button className="ghost" type="button" onClick={addLine}>
            <Plus size={16} />
            Thêm dòng
          </button>
        </Panel>
        <Panel title="Preview đọc Kinh">
          <ScripturePreview lines={lines} />
        </Panel>
      </div>

      <Panel title="Danh sách bản Đọc Kinh">
        <Table
          rows={data.scriptures}
          columns={[
            ['title', 'Tiêu đề'],
            [(row: Scripture) => row.category?.name ?? '-', 'Danh mục'],
            [(row: Scripture) => row.lines?.length ?? row._count?.lines ?? 0, 'Số dòng'],
            [(row: Scripture) => row.viewCount.toLocaleString('vi-VN'), 'Lượt xem'],
            [
              (row: Scripture) => (
                <button className="ghost" type="button" onClick={() => openScripture(row)}>
                  Mở
                </button>
              ),
              'Xem/Sửa',
            ],
          ]}
          onDelete={(row) => run(() => api.remove(`/admin/scripture/${row.id}`), 'Đã xóa bản Đọc Kinh')}
        />
      </Panel>
    </div>
  );
}

function ScripturePreview({ lines }: { lines: Array<{ content: string; start_time: number }> }) {
  const [playing, setPlaying] = useState(false);
  const [speed, setSpeed] = useState(1);
  const [elapsed, setElapsed] = useState(0);
  const activeIndex = useMemo(() => {
    let index = 0;
    lines.forEach((line, current) => {
      if (elapsed >= line.start_time) index = current;
    });
    return index;
  }, [elapsed, lines]);

  useEffect(() => {
    if (!playing) return undefined;
    let frame = 0;
    let previous = performance.now();
    const tick = (now: number) => {
      setElapsed((value) => value + ((now - previous) / 1000) * speed);
      previous = now;
      frame = requestAnimationFrame(tick);
    };
    frame = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frame);
  }, [playing, speed]);

  return (
    <div className="scripture-preview">
      <div className="preview-toolbar">
        <button className="primary" type="button" onClick={() => setPlaying(!playing)}>
          {playing ? <Pause size={16} /> : <Play size={16} />}
          {playing ? 'Tạm dừng' : 'Đọc thử'}
        </button>
        <button className="ghost" type="button" onClick={() => setElapsed(0)}>
          <RefreshCcw size={16} />
          Về đầu
        </button>
        {[0.75, 1, 1.25].map((value) => (
          <button key={value} className={speed === value ? 'speed active' : 'speed'} type="button" onClick={() => setSpeed(value)}>
            {value === 0.75 ? 'Chậm' : value === 1 ? 'Bình thường' : 'Nhanh'}
          </button>
        ))}
        <label>
          Tùy chỉnh {speed.toFixed(2)}x
          <input type="range" min="0.25" max="3" step="0.05" value={speed} onChange={(event) => setSpeed(Number(event.target.value))} />
        </label>
      </div>
      <div className="reader-stage">
        <div className="reader-center-line" />
        <div className="reader-lines" style={{ transform: `translateY(${160 - activeIndex * 58}px)` }}>
          {lines.map((line, index) => (
            <button
              type="button"
              key={`${index}-${line.start_time}`}
              className={index === activeIndex ? 'reader-line active' : 'reader-line'}
              onClick={() => setElapsed(line.start_time)}
            >
              {line.content || '...'}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}

const weekdayOptions = [
  [1, 'T2'],
  [2, 'T3'],
  [3, 'T4'],
  [4, 'T5'],
  [5, 'T6'],
  [6, 'T7'],
  [7, 'CN'],
  [0, 'CN'],
] as const;

function ScriptureReminderManager({ data }: { data: DataState }) {
  return (
    <div className="single-column">
      <Panel title="Danh sách lịch nhắc tụng kinh của người dùng">
        <div className="scripture-form-heading">
          <div>
            <strong>Chỉ theo dõi lịch do user tự tạo</strong>
            <span>Admin xem người tạo, bài kinh, giờ nhắc, ngày nhắc, chế độ đọc và trạng thái. Việc tạo/sửa lịch nhắc thuộc về người dùng trong app.</span>
          </div>
        </div>
        <Table
          rows={data.scriptureReminders}
          columns={[
            [(row: ScriptureReminder) => row.user?.name || row.user?.email || 'Lịch hệ thống', 'User'],
            ['title', 'Tên lịch'],
            [(row: ScriptureReminder) => row.scripture?.title ?? '-', 'Bộ kinh'],
            ['timeOfDay', 'Giờ nhắc'],
            [(row: ScriptureReminder) => row.weekdays.map((day) => weekdayOptions.find(([value]) => value === day)?.[1] ?? day).join(', '), 'Ngày'],
            [(row: ScriptureReminder) => (row.resumeMode === 'RESUME' ? 'Tiếp tục' : 'Bắt đầu lại'), 'Chế độ'],
            [(row: ScriptureReminder) => row.lastLineIndex.toLocaleString('vi-VN'), 'Dòng đã đọc'],
            [(row: ScriptureReminder) => (row.active ? 'Đang bật' : 'Tắt'), 'Trạng thái'],
            [(row: ScriptureReminder) => new Date(row.createdAt).toLocaleString('vi-VN'), 'Thời gian tạo'],
          ]}
        />
      </Panel>
    </div>
  );
}

function VideoManager({ data, run }: { data: DataState; run: RunAction }) {
  const [editingVideo, setEditingVideo] = useState<Video | null>(null);

  function editCategory(row: VideoCategory) {
    const name = askText('Tên danh mục', row.name);
    if (name === undefined) return;
    const description = askText('Mô tả', row.description ?? '');
    if (description === undefined) return;
    void run(() => api.update(`/admin/video-category/${row.id}`, { name, description }), 'Đã cập nhật danh mục video');
  }

  function editVideo(row: Video) {
    setEditingVideo(row);
  }

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
            ['videoUrl', 'Tệp video MP4 hoặc URL YouTube', 'upload:video/dharma'],
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
            [
              (row: VideoCategory) => (
                <button className="ghost" type="button" onClick={() => editCategory(row)}>
                  <Pencil size={15} />
                  Sửa
                </button>
              ),
              'Thao tác',
            ],
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
            [(row: Video) => row.viewCount.toLocaleString('vi-VN'), 'Lượt xem'],
            ['videoUrl', 'Video URL'],
            [
              (row: Video) => (
                <button className="ghost" type="button" onClick={() => editVideo(row)}>
                  <Pencil size={15} />
                  Sửa
                </button>
              ),
              'Thao tác',
            ],
          ]}
          onDelete={(row) => run(() => api.remove(`/admin/video/${row.id}`), 'Đã xóa video')}
        />
      </Panel>
      {editingVideo && (
        <VideoEditModal
          video={editingVideo}
          categories={data.videoCategories}
          onClose={() => setEditingVideo(null)}
          onSave={async (values) => {
            const saved = await run(
              () => api.update(`/admin/video/${editingVideo.id}`, compactPayload(values)),
              'Đã cập nhật video',
            );
            if (saved) setEditingVideo(null);
          }}
        />
      )}
    </div>
  );
}

function AudioEditModal({
  audio,
  categories,
  onClose,
  onSave,
}: {
  audio: Audio;
  categories: AudioCategory[];
  onClose: () => void;
  onSave: (values: { title: string; description: string; audioUrl: string; thumbnailUrl: string; categoryId: string }) => Promise<void>;
}) {
  const [values, setValues] = useState({
    title: audio.title,
    description: audio.description ?? '',
    audioUrl: audio.audioUrl,
    thumbnailUrl: audio.thumbnailUrl ?? '',
    categoryId: audio.categoryId,
  });

  return (
    <Modal title="Sửa audio" onClose={onClose}>
      <form
        className="form"
        onSubmit={(event) => {
          event.preventDefault();
          void onSave(values);
        }}
      >
        <label>
          Tiêu đề
          <input value={values.title} onChange={(event) => setValues({ ...values, title: event.target.value })} required />
        </label>
        <label>
          Mô tả
          <textarea value={values.description} onChange={(event) => setValues({ ...values, description: event.target.value })} />
        </label>
        <label>
          Tệp audio MP3 hoặc URL
          <UploadField kind="audio/library" value={values.audioUrl} onUploaded={(audioUrl) => setValues({ ...values, audioUrl })} />
        </label>
        <label>
          Ảnh đại diện
          <UploadField kind="images/audio" value={values.thumbnailUrl} onUploaded={(thumbnailUrl) => setValues({ ...values, thumbnailUrl })} />
        </label>
        <label>
          Danh mục
          <select value={values.categoryId} onChange={(event) => setValues({ ...values, categoryId: event.target.value })} required>
            <option value="">Chọn...</option>
            {categories.map((item) => (
              <option key={item.id} value={item.id}>
                {item.name}
              </option>
            ))}
          </select>
        </label>
        <div className="modal-actions">
          <button className="ghost" type="button" onClick={onClose}>
            Hủy
          </button>
          <button className="primary" type="submit">
            <Save size={16} />
            Lưu thay đổi
          </button>
        </div>
      </form>
    </Modal>
  );
}

function VideoEditModal({
  video,
  categories,
  onClose,
  onSave,
}: {
  video: Video;
  categories: VideoCategory[];
  onClose: () => void;
  onSave: (values: { title: string; teacher: string; description: string; videoUrl: string; thumbnailUrl: string; categoryId: string }) => Promise<void>;
}) {
  const [values, setValues] = useState({
    title: video.title,
    teacher: video.teacher ?? '',
    description: video.description ?? '',
    videoUrl: video.videoUrl,
    thumbnailUrl: video.thumbnailUrl ?? '',
    categoryId: video.categoryId,
  });

  return (
    <Modal title="Sửa video" onClose={onClose}>
      <form
        className="form"
        onSubmit={(event) => {
          event.preventDefault();
          void onSave(values);
        }}
      >
        <label>
          Tiêu đề
          <input value={values.title} onChange={(event) => setValues({ ...values, title: event.target.value })} required />
        </label>
        <label>
          Giảng sư
          <input value={values.teacher} onChange={(event) => setValues({ ...values, teacher: event.target.value })} />
        </label>
        <label>
          Mô tả
          <textarea value={values.description} onChange={(event) => setValues({ ...values, description: event.target.value })} />
        </label>
        <label>
          Tệp video MP4 hoặc URL YouTube
          <UploadField kind="video/dharma" value={values.videoUrl} onUploaded={(videoUrl) => setValues({ ...values, videoUrl })} />
        </label>
        <label>
          Ảnh đại diện
          <UploadField kind="images/video" value={values.thumbnailUrl} onUploaded={(thumbnailUrl) => setValues({ ...values, thumbnailUrl })} />
        </label>
        <label>
          Danh mục
          <select value={values.categoryId} onChange={(event) => setValues({ ...values, categoryId: event.target.value })} required>
            <option value="">Chọn...</option>
            {categories.map((item) => (
              <option key={item.id} value={item.id}>
                {item.name}
              </option>
            ))}
          </select>
        </label>
        <div className="modal-actions">
          <button className="ghost" type="button" onClick={onClose}>
            Hủy
          </button>
          <button className="primary" type="submit">
            <Save size={16} />
            Lưu thay đổi
          </button>
        </div>
      </form>
    </Modal>
  );
}

function Modal({ title, children, onClose }: { title: string; children: React.ReactNode; onClose: () => void }) {
  return (
    <div className="modal-backdrop" role="presentation" onMouseDown={onClose}>
      <section className="modal-panel" role="dialog" aria-modal="true" aria-label={title} onMouseDown={(event) => event.stopPropagation()}>
        <div className="modal-heading">
          <h2>{title}</h2>
          <button className="ghost icon-only" type="button" onClick={onClose} aria-label="Đóng">
            ×
          </button>
        </div>
        {children}
      </section>
    </div>
  );
}

const VideoEmbedExtension = TiptapNode.create({
  name: 'videoEmbed',
  group: 'inline',
  inline: true,
  atom: true,
  addAttributes() {
    return {
      src: {
        default: null,
      },
      textAlign: {
        default: 'left',
        renderHTML: (attributes) => ({
          'data-text-align': attributes.textAlign,
        }),
        parseHTML: (element) => element.getAttribute('data-text-align') || 'left',
      },
    };
  },
  parseHTML() {
    return [
      { tag: 'iframe[src]' },
      { tag: 'video[src]' },
      { tag: 'div[data-video]' },
    ];
  },
  renderHTML({ HTMLAttributes }) {
    const src = String(HTMLAttributes.src ?? HTMLAttributes['data-video'] ?? '');
    if (/\.mp4(?:\?|#|$)/i.test(src)) {
      return ['video', mergeAttributes(HTMLAttributes, { src, controls: 'true' })];
    }
    return ['iframe', mergeAttributes(HTMLAttributes, { src, allowfullscreen: 'true', frameborder: '0' })];
  },
});

function RichTextEditor({
  value,
  onChange,
  placeholder,
  compact = false,
  imageUploadKind = 'images/news',
  videoUploadKind = 'video',
}: {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  compact?: boolean;
  imageUploadKind?: Parameters<typeof uploadToR2>[1];
  videoUploadKind?: Parameters<typeof uploadToR2>[1];
}) {
  const imageInputRef = useRef<HTMLInputElement | null>(null);
  const videoInputRef = useRef<HTMLInputElement | null>(null);
  const lastEmitHtmlRef = useRef('');
  const [uploadingImage, setUploadingImage] = useState(false);
  const [uploadingVideo, setUploadingVideo] = useState(false);

  // Auto-cleanup and parse existing content ONLY ONCE on mount
  const initialContent = useMemo(() => parseInitialEditorContent(value), []);

  const editor = useEditor({
    extensions: [
      StarterKit.configure({
        heading: { levels: [2, 3] },
      }),
      UnderlineExtension,
      LinkExtension.configure({
        autolink: true,
        defaultProtocol: 'https',
        openOnClick: false,
      }),
      ImageExtension.configure({
        allowBase64: false,
        inline: true,
      }),
      TextAlignExtension.configure({
        types: ['heading', 'paragraph', 'image', 'videoEmbed'],
      }),
      PlaceholderExtension.configure({
        placeholder: placeholder ?? '',
      }),
      Superscript,
      TextStyle,
      Color,
      Highlight.configure({ multicolor: true }),
      VideoEmbedExtension,
    ],
    content: initialContent,
    editorProps: {
      attributes: {
        class: 'rich-surface modern-editor-surface',
        spellcheck: 'false',
        style: 'min-height: 300px; padding: 20px; outline: none; background: #ffffff; border-radius: 0 0 12px 12px; font-family: "Inter", "Segoe UI", sans-serif; font-size: 16px; line-height: 1.6; color: #111827;'
      },
    },
    onUpdate({ editor: nextEditor }) {
      const nextHtml = nextEditor.getHTML();
      lastEmitHtmlRef.current = nextHtml;
      onChange(nextHtml);
    },
  });

  // Handle external value changes
  useEffect(() => {
    if (!editor || editor.isFocused) return;
    if (value === lastEmitHtmlRef.current) return;
    
    const newHtml = parseInitialEditorContent(value);
    if (editor.getHTML() !== newHtml) {
      editor.commands.setContent(newHtml, { emitUpdate: false });
      lastEmitHtmlRef.current = newHtml;
    }
  }, [value, editor]);

  function runCommand(format: string, commandValue?: string | number | boolean) {
    if (!editor) return;
    const chain = editor.chain().focus();
    if (format === 'header') {
      if (commandValue === 2) chain.toggleHeading({ level: 2 }).run();
      else if (commandValue === 3) chain.toggleHeading({ level: 3 }).run();
      else chain.setParagraph().run();
      return;
    }
    if (format === 'blockquote') chain.toggleBlockquote().run();
    if (format === 'bold') chain.toggleBold().run();
    if (format === 'italic') chain.toggleItalic().run();
    if (format === 'underline') chain.toggleUnderline().run();
    if (format === 'strike') chain.toggleStrike().run();
    if (format === 'list' && commandValue === 'ordered') chain.toggleOrderedList().run();
    if (format === 'list' && commandValue !== 'ordered') chain.toggleBulletList().run();
    if (format === 'align') chain.setTextAlign(commandValue ? String(commandValue) : 'left').run();
    if (format === 'link' && commandValue === false) chain.unsetLink().run();
    if (format === 'superscript') chain.toggleSuperscript().run();
    if (format === 'color') chain.setColor(String(commandValue)).run();
    if (format === 'highlight') chain.toggleHighlight({ color: String(commandValue) }).run();
  }

  function addLink() {
    if (!editor) return;
    const url = window.prompt('Dán liên kết https://...');
    if (!url) return;
    editor.chain().focus().extendMarkRange('link').setLink({ href: url }).run();
  }

  function addImageUrl() {
    const url = window.prompt('Dán URL hình ảnh https://...');
    if (!url) return;
    insertEmbed('image', url);
  }

  function addVideo() {
    const url = window.prompt('Dán link video YouTube hoặc MP4');
    if (!url) return;
    insertEmbed('video', url);
  }

  function insertEmbed(type: 'image' | 'video', url: string) {
    if (!editor) return;
    if (type === 'image') {
      editor.chain().focus().setImage({ src: url, alt: 'Hình ảnh' }).createParagraphNear().run();
      return;
    }
    editor.chain().focus().insertContent({ type: 'videoEmbed', attrs: { src: url } }).createParagraphNear().run();
  }

  async function uploadImage(file?: File) {
    if (!file) return;
    setUploadingImage(true);
    try {
      const url = await uploadToR2(file, imageUploadKind);
      insertEmbed('image', url);
    } catch (caught) {
      window.alert(caught instanceof Error ? caught.message : 'Upload ảnh thất bại');
    } finally {
      setUploadingImage(false);
      if (imageInputRef.current) imageInputRef.current.value = '';
    }
  }

  async function uploadVideo(file?: File) {
    if (!file) return;
    setUploadingVideo(true);
    try {
      const url = await uploadToR2(file, videoUploadKind);
      insertEmbed('video', url);
    } catch (caught) {
      window.alert(caught instanceof Error ? caught.message : 'Upload video thất bại');
    } finally {
      setUploadingVideo(false);
      if (videoInputRef.current) videoInputRef.current.value = '';
    }
  }

  const h2Active = Boolean(editor?.isActive('heading', { level: 2 }));
  const h3Active = Boolean(editor?.isActive('heading', { level: 3 }));

  const toolbarStyle: React.CSSProperties = {
    display: 'flex',
    flexWrap: 'wrap',
    gap: '4px',
    padding: '12px',
    background: '#f9fafb',
    borderBottom: '1px solid #e5e7eb',
    borderRadius: '12px 12px 0 0',
  };

  const btnStyle = (active: boolean): React.CSSProperties => ({
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    width: '32px',
    height: '32px',
    background: active ? '#e0e7ff' : 'transparent',
    color: active ? '#4f46e5' : '#4b5563',
    border: 'none',
    borderRadius: '6px',
    cursor: 'pointer',
    transition: 'all 0.2s',
  });

  return (
    <div style={{ border: '1px solid #d1d5db', borderRadius: '12px', boxShadow: '0 4px 6px -1px rgba(0, 0, 0, 0.05)', marginTop: '8px' }}>
      <div style={{ padding: '8px 16px', background: '#4f46e5', color: '#fff', fontSize: '12px', fontWeight: 'bold', borderRadius: '11px 11px 0 0', display: 'flex', alignItems: 'center', gap: '8px' }}>
        <span style={{ width: '8px', height: '8px', background: '#34d399', borderRadius: '50%' }}></span>
        Trình soạn thảo Siêu Cấp (Hỗ trợ Ảnh & Video)
      </div>
      <div style={toolbarStyle} onMouseDown={(event) => event.preventDefault()}>
        {/* Headings */}
        <button style={btnStyle(h2Active)} type="button" onClick={() => runCommand('header', 2)} title="Tiêu đề Lớn"><Heading2 size={16} /></button>
        <button style={btnStyle(h3Active)} type="button" onClick={() => runCommand('header', 3)} title="Tiêu đề Nhỏ"><Heading3 size={16} /></button>
        <button style={btnStyle(Boolean(editor?.isActive('paragraph')))} type="button" onClick={() => runCommand('header', false)} title="Đoạn văn thường"><span style={{ fontWeight: 'bold' }}>Aa</span></button>
        <div style={{ width: '1px', background: '#d1d5db', margin: '0 4px' }}></div>
        
        {/* Inline Formatting */}
        <button style={btnStyle(Boolean(editor?.isActive('bold')))} type="button" onClick={() => runCommand('bold')} title="In đậm"><Bold size={16} /></button>
        <button style={btnStyle(Boolean(editor?.isActive('italic')))} type="button" onClick={() => runCommand('italic')} title="In nghiêng"><Italic size={16} /></button>
        <button style={btnStyle(Boolean(editor?.isActive('underline')))} type="button" onClick={() => runCommand('underline')} title="Gạch chân"><Underline size={16} /></button>
        <button style={btnStyle(Boolean(editor?.isActive('strike')))} type="button" onClick={() => runCommand('strike')} title="Gạch ngang"><Strikethrough size={16} /></button>
        <button style={btnStyle(Boolean(editor?.isActive('superscript')))} type="button" onClick={() => runCommand('superscript')} title="Số mũ (Mũ)"><SuperscriptIcon size={16} /></button>
        <div style={{ width: '1px', background: '#d1d5db', margin: '0 4px' }}></div>
        
        {/* Colors */}
        <button style={btnStyle(false)} type="button" onClick={() => {
          const color = window.prompt('Nhập mã màu (ví dụ: #ff0000 hoặc red)', '#ff0000');
          if (color) runCommand('color', color);
        }} title="Màu chữ"><Baseline size={16} /></button>
        <button style={btnStyle(false)} type="button" onClick={() => {
          const color = window.prompt('Nhập màu nền (ví dụ: #ffff00 hoặc yellow)', '#ffff00');
          if (color) runCommand('highlight', color);
        }} title="Tô sáng"><Highlighter size={16} /></button>
        <div style={{ width: '1px', background: '#d1d5db', margin: '0 4px' }}></div>
        
        {/* Blocks & Lists */}
        <button style={btnStyle(Boolean(editor?.isActive('blockquote')))} type="button" onClick={() => runCommand('blockquote')} title="Trích dẫn"><Quote size={16} /></button>
        <button style={btnStyle(Boolean(editor?.isActive('bulletList')))} type="button" onClick={() => runCommand('list', 'bullet')} title="Danh sách"><List size={16} /></button>
        <button style={btnStyle(Boolean(editor?.isActive('orderedList')))} type="button" onClick={() => runCommand('list', 'ordered')} title="Danh sách số"><ListOrdered size={16} /></button>
        <div style={{ width: '1px', background: '#d1d5db', margin: '0 4px' }}></div>
        
        {/* Alignment */}
        <button style={btnStyle(Boolean(editor?.isActive({ textAlign: 'left' })))} type="button" onClick={() => runCommand('align', false)} title="Căn trái"><AlignLeft size={16} /></button>
        <button style={btnStyle(Boolean(editor?.isActive({ textAlign: 'center' })))} type="button" onClick={() => runCommand('align', 'center')} title="Căn giữa"><AlignCenter size={16} /></button>
        <button style={btnStyle(Boolean(editor?.isActive({ textAlign: 'right' })))} type="button" onClick={() => runCommand('align', 'right')} title="Căn phải"><AlignRight size={16} /></button>
        <div style={{ width: '1px', background: '#d1d5db', margin: '0 4px' }}></div>
        
        {/* Media & Links */}
        <button style={btnStyle(Boolean(editor?.isActive('link')))} type="button" onClick={addLink} title="Chèn liên kết"><Link2 size={16} /></button>
        <button style={btnStyle(false)} type="button" onClick={addImageUrl} title="Chèn ảnh từ URL"><Image size={16} /></button>
        <button style={btnStyle(false)} type="button" onClick={() => imageInputRef.current?.click()} title="Tải ảnh lên (R2)">{uploadingImage ? '...' : <ImagePlus size={16} />}</button>
        <button style={btnStyle(false)} type="button" onClick={addVideo} title="Chèn video từ URL"><VideoIcon size={16} /></button>
        <button style={btnStyle(false)} type="button" onClick={() => videoInputRef.current?.click()} title="Tải video lên (R2)">{uploadingVideo ? '...' : <Clapperboard size={16} />}</button>
        
        <div style={{ width: '1px', background: '#d1d5db', margin: '0 4px' }}></div>
        <button style={btnStyle(false)} type="button" onClick={() => { if(editor) editor.chain().focus().clearNodes().unsetAllMarks().setTextAlign('left').run(); }} title="Xóa định dạng"><Eraser size={16} /></button>
        
        <input ref={imageInputRef} type="file" accept="image/*" hidden onChange={(event) => void uploadImage(event.target.files?.[0])} />
        <input ref={videoInputRef} type="file" accept="video/mp4,video/quicktime,video/webm" hidden onChange={(event) => void uploadVideo(event.target.files?.[0])} />
      </div>
      <EditorContent editor={editor} />
    </div>
  );
}
function parseInitialEditorContent(value: string) {
  const trimmed = value.trim();
  if (!trimmed) return '';

  let htmlContent = trimmed;

  if (!/<\/?[a-z][\s\S]*>/i.test(trimmed)) {
    const normalized = trimmed
      .replace(/<b>(.*?)<\/b>/gis, '**$1**')
      .replace(/<strong>(.*?)<\/strong>/gis, '**$1**')
      .replace(/<url=(.*?)>(.*?)<\/url>/gis, '[$2]($1)')
      .replace(/<url>(.*?)<\/url>/gis, '[$1]($1)')
      .replace(/\[b\](.*?)\[\/b\]/gis, '**$1**')
      .replace(/\[i\](.*?)\[\/i\]/gis, '*$1*')
      .replace(/\[u\](.*?)\[\/u\]/gis, '__$1__')
      .replace(/\[url=(.*?)\](.*?)\[\/url\]/gis, '[$2]($1)')
      .replace(/\[url\](.*?)\[\/url\]/gis, '[$1]($1)');

    const blocks = normalized.split(/\n{2,}/).map((block) => block.trim()).filter(Boolean);
    htmlContent = blocks
      .map((block) => {
        if (block === '##' || block === '###') return '';
        if (block.startsWith('### ')) return `<h3>${inlineMarkupToHtml(block.slice(4))}</h3>`;
        if (block.startsWith('## ')) return `<h2>${inlineMarkupToHtml(block.slice(3))}</h2>`;
        if (block.startsWith('> ')) return `<blockquote>${inlineMarkupToHtml(block.replace(/^> /gm, ''))}</blockquote>`;
        if (block.startsWith('![')) {
          const image = block.match(/^!\[(.*?)\]\((https?:\/\/[^)]+)\)$/);
          if (image) return `<figure><img src="${escapeHtml(image[2])}" alt="${escapeHtml(image[1])}" /></figure>`;
        }
        if (block.startsWith('[[video:')) {
          const video = block.match(/^\[\[video:(.*?)\]\]$/);
          if (video) return `<div data-video="${escapeHtml(video[1])}">Video: ${escapeHtml(video[1])}</div>`;
        }
        const lines = block.split('\n').map((line) => line.trim()).filter(Boolean);
        if (lines.every((line) => line.startsWith('- '))) {
          return `<ul>${lines.map((line) => `<li>${inlineMarkupToHtml(line.slice(2))}</li>`).join('')}</ul>`;
        }
        if (lines.every((line) => /^\d+\. /.test(line))) {
          return `<ol>${lines.map((line) => `<li>${inlineMarkupToHtml(line.replace(/^\d+\. /, ''))}</li>`).join('')}</ol>`;
        }
        return `<p>${inlineMarkupToHtml(lines.join('<br>'))}</p>`;
      })
      .join('');
  }

  try {
    const container = document.createElement('div');
    container.innerHTML = htmlContent;
    
    // 1. Khử H2, H3 bị lỗi (dài quá mức)
    container.querySelectorAll('h1, h2, h3, h4, h5, h6').forEach((heading) => {
      const textLength = (heading.textContent || '').trim().length;
      if (textLength > 60) {
        const p = document.createElement('p');
        p.innerHTML = heading.innerHTML;
        heading.replaceWith(p);
      }
    });

    // 2. Khử b, strong bị bọc toàn bộ văn bản dài (nguyên nhân làm chữ to như H2)
    container.querySelectorAll('b, strong').forEach((bold) => {
      if ((bold.textContent || '').trim().length > 60) {
        const span = document.createElement('span');
        span.innerHTML = bold.innerHTML;
        bold.replaceWith(span);
      }
    });

    // 3. Xóa thẻ <br> ở cuối đoạn (nguyên nhân gây lỗi nhảy xuống dòng khi click)
    container.querySelectorAll('p').forEach((p) => {
      let lastChild = p.lastChild;
      while (lastChild) {
        if (lastChild.nodeType === 1 && (lastChild as HTMLElement).tagName === 'BR') {
          const toRemove = lastChild;
          lastChild = lastChild.previousSibling;
          toRemove.remove();
        } else if (lastChild.nodeType === 3 && (lastChild.textContent || '').trim() === '') {
          const toRemove = lastChild;
          lastChild = lastChild.previousSibling;
          toRemove.remove();
        } else {
          break;
        }
      }
    });

    return container.innerHTML;
  } catch (err) {
    return htmlContent;
  }
}

function inlineMarkupToHtml(value: string) {
  const escaped = escapeHtml(value);
  return escaped
    .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
    .replace(/__(.+?)__/g, '<u>$1</u>')
    .replace(/\*(.+?)\*/g, '<em>$1</em>')
    .replace(/~~(.+?)~~/g, '<s>$1</s>')
    .replace(/\[(.+?)\]\((https?:\/\/[^)]+)\)/g, '<a href="$2">$1</a>');
}

function isSafeMediaUrl(value: string) {
  return /^https?:\/\//i.test(value);
}

function escapeHtml(value: string) {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function newsContentToPlainText(value: string) {
  const trimmed = value.trim();
  if (!trimmed) return '';
  if (!/<\/?[a-z][\s\S]*>/i.test(trimmed)) return trimmed.replace(/^\s*#{1,6}\s+/gm, '');

  const container = document.createElement('div');
  container.innerHTML = trimmed;
  container.querySelectorAll('script, style').forEach((node) => node.remove());
  container.querySelectorAll('br').forEach((node) => node.replaceWith('\n'));
  container.querySelectorAll('p, div, h1, h2, h3, h4, h5, h6, blockquote, li').forEach((node) => {
    node.appendChild(document.createTextNode('\n\n'));
  });
  return (container.textContent ?? '')
    .replace(/\u00a0/g, ' ')
    .replace(/[ \t]+\n/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

function BbCodeTextarea({
  value,
  onChange,
  placeholder,
  className,
  compact = false,
  imageUploadKind = 'images/news',
}: {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  className?: string;
  compact?: boolean;
  imageUploadKind?: Parameters<typeof uploadToR2>[1];
}) {
  const inputRef = useRef<HTMLTextAreaElement | null>(null);
  const imageInputRef = useRef<HTMLInputElement | null>(null);
  const [uploadingImage, setUploadingImage] = useState(false);

  function insertBbcode(startTag: string, endTag = '') {
    const input = inputRef.current;
    if (!input) {
      onChange(`${value}${startTag}${endTag}`);
      return;
    }
    const start = input.selectionStart;
    const end = input.selectionEnd;
    const selected = value.slice(start, end);
    const next = `${value.slice(0, start)}${startTag}${selected}${endTag}${value.slice(end)}`;
    onChange(next);
    window.setTimeout(() => {
      input.focus();
      const cursor = selected ? start + startTag.length + selected.length + endTag.length : start + startTag.length;
      input.setSelectionRange(cursor, cursor);
    }, 0);
  }

  function insertLink() {
    const url = window.prompt('Dán liên kết https://...');
    if (!url) return;
    insertBbcode(`[url=${url}]`, '[/url]');
  }

  function insertImage() {
    const url = window.prompt('Dán URL hình ảnh https://...');
    if (!url) return;
    insertBbcode(`[img]${url}[/img]`);
  }

  async function uploadImage(file?: File) {
    if (!file) return;
    setUploadingImage(true);
    try {
      const url = await uploadToR2(file, imageUploadKind);
      insertBbcode(`[img]${url}[/img]`);
    } catch (caught) {
      window.alert(caught instanceof Error ? caught.message : 'Upload ảnh thất bại');
    } finally {
      setUploadingImage(false);
      if (imageInputRef.current) imageInputRef.current.value = '';
    }
  }

  function insertVideo() {
    const url = window.prompt('Dán link video YouTube hoặc MP4');
    if (!url) return;
    insertBbcode(`[video]${url}[/video]`);
  }

  function clearFormat() {
    const input = inputRef.current;
    if (!input) {
      onChange(stripBbcodeFormatting(value));
      return;
    }
    const start = input.selectionStart;
    const end = input.selectionEnd;
    const hasSelection = end > start;
    const source = hasSelection ? value.slice(start, end) : value;
    const cleaned = stripBbcodeFormatting(source);
    const next = hasSelection ? `${value.slice(0, start)}${cleaned}${value.slice(end)}` : cleaned;
    onChange(next);
    window.setTimeout(() => {
      input.focus();
      const cursor = hasSelection ? start + cleaned.length : cleaned.length;
      input.setSelectionRange(cursor, cursor);
    }, 0);
  }

  return (
    <div className="bbcode-editor">
      <div className={`bbcode-toolbar ${compact ? 'compact' : ''}`} aria-label="Công cụ BBCode">
        <button type="button" onClick={() => insertBbcode('[b]', '[/b]')} title="In đậm">
          <Bold size={16} />
        </button>
        <button type="button" onClick={() => insertBbcode('[i]', '[/i]')} title="In nghiêng">
          <Italic size={16} />
        </button>
        <button type="button" onClick={() => insertBbcode('[u]', '[/u]')} title="Gạch chân">
          <Underline size={16} />
        </button>
        <button type="button" onClick={() => insertBbcode('[s]', '[/s]')} title="Gạch ngang">
          <Strikethrough size={16} />
        </button>
        <button type="button" onClick={() => insertBbcode('[quote]', '[/quote]')} title="Trích dẫn">
          <Quote size={16} />
        </button>
        <button type="button" onClick={() => insertBbcode('\n- ')} title="Danh sách">
          <List size={16} />
        </button>
        <button type="button" onClick={insertLink} title="Liên kết">
          <Link2 size={16} />
        </button>
        <button type="button" onClick={insertImage} title="Hình ảnh">
          <ImagePlus size={16} />
        </button>
        <button type="button" onClick={() => imageInputRef.current?.click()} title="Upload ảnh lên R2">
          {uploadingImage ? '...' : <Upload size={16} />}
        </button>
        <button type="button" onClick={insertVideo} title="Video">
          <VideoIcon size={16} />
        </button>
        <button type="button" onClick={clearFormat} title="Xóa format">
          <Eraser size={16} />
        </button>
        <input
          ref={imageInputRef}
          type="file"
          accept="image/*"
          hidden
          onChange={(event) => void uploadImage(event.target.files?.[0])}
        />
      </div>
      <textarea
        ref={inputRef}
        className={className}
        value={value}
        onChange={(event) => onChange(event.target.value)}
        spellCheck={false}
        autoCorrect="off"
        autoCapitalize="off"
        placeholder={placeholder}
      />
      <div className={`bbcode-preview ${compact ? 'compact' : ''}`}>
        <span className="bbcode-preview-label">Xem trước</span>
        <div dangerouslySetInnerHTML={{ __html: bbcodeToPreviewHtml(value) }} />
      </div>
    </div>
  );
}

function stripBbcodeFormatting(value: string) {
  return value
    .replace(/\[(?:\/)?(?:b|i|u|s|quote)\]/gi, '')
    .replace(/\[url=(.*?)\](.*?)\[\/url\]/gis, '$2')
    .replace(/\[url\](.*?)\[\/url\]/gis, '$1')
    .replace(/\[img\](.*?)\[\/img\]/gis, '$1')
    .replace(/\[video\](.*?)\[\/video\]/gis, '$1')
    .replace(/\*\*(.*?)\*\*/gis, '$1')
    .replace(/__(.*?)__/gis, '$1')
    .replace(/~~(.*?)~~/gis, '$1')
    .replace(/\*(.*?)\*/gis, '$1');
}

function bbcodeToPreviewHtml(value: string) {
  const normalized = value.trim();
  if (!normalized) return '<p class="muted">Chưa có nội dung xem trước.</p>';
  return normalized
    .split(/\n{2,}/)
    .map((block) => block.trim())
    .filter(Boolean)
    .map((block) => {
      const image = block.match(/^\[img\](.*?)\[\/img\]$/i);
      if (image && isSafeMediaUrl(image[1].trim())) {
        const url = escapeHtml(image[1].trim());
        return `<figure><img src="${url}" alt="Hình ảnh" /></figure>`;
      }
      const video = block.match(/^\[video\](.*?)\[\/video\]$/i);
      if (video) return `<div class="preview-video">Video: ${escapeHtml(video[1].trim())}</div>`;
      const quote = block.match(/^\[quote\]([\s\S]*?)\[\/quote\]$/i);
      if (quote) return `<blockquote>${bbcodeInlineToHtml(quote[1].trim()).replace(/\n/g, '<br>')}</blockquote>`;
      const lines = block.split('\n').map((line) => line.trim()).filter(Boolean);
      if (lines.length > 0 && lines.every((line) => line.startsWith('- '))) {
        return `<ul>${lines.map((line) => `<li>${bbcodeInlineToHtml(line.slice(2))}</li>`).join('')}</ul>`;
      }
      return `<p>${bbcodeInlineToHtml(block).replace(/\n/g, '<br>')}</p>`;
    })
    .join('');
}

function bbcodeInlineToHtml(value: string) {
  return escapeHtml(value)
    .replace(/\[b\]([\s\S]*?)\[\/b\]/gi, '<strong>$1</strong>')
    .replace(/\[i\]([\s\S]*?)\[\/i\]/gi, '<em>$1</em>')
    .replace(/\[u\]([\s\S]*?)\[\/u\]/gi, '<u>$1</u>')
    .replace(/\[s\]([\s\S]*?)\[\/s\]/gi, '<s>$1</s>')
    .replace(/\[url=(https?:\/\/[^\]]+)\]([\s\S]*?)\[\/url\]/gi, '<a href="$1" target="_blank" rel="noreferrer">$2</a>')
    .replace(/\[url\](https?:\/\/[\s\S]*?)\[\/url\]/gi, '<a href="$1" target="_blank" rel="noreferrer">$1</a>');
}

function NewsManager({ data, run }: { data: DataState; run: RunAction }) {
  const [title, setTitle] = useState('');
  const [summary, setSummary] = useState('');
  const [content, setContent] = useState('');
  const [categoryId, setCategoryId] = useState('');
  const [imageUrl, setImageUrl] = useState('');
  const [link, setLink] = useState('');
  const [shareEnabled, setShareEnabled] = useState(true);
  const [editingNewsId, setEditingNewsId] = useState('');

  function editCategory(row: NewsCategory) {
    const name = askText('Tên danh mục', row.name);
    if (name === undefined) return;
    const description = askText('Mô tả', row.description ?? '');
    if (description === undefined) return;
    void run(() => api.update(`/admin/news-category/${row.id}`, { name, description }), 'Đã cập nhật danh mục tin');
  }

function editNews(row: NewsItem) {
    setEditingNewsId(row.id);
    setTitle(row.title);
    setSummary(row.summary ?? '');
    setImageUrl(row.imageUrl ?? '');
    setLink(row.link ?? '');
    setContent(row.content ?? '');
    setCategoryId(row.categoryId ?? '');
    setShareEnabled(row.shareEnabled);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  function resetNewsForm() {
    setEditingNewsId('');
    setTitle('');
    setSummary('');
    setContent('');
    setCategoryId('');
    setImageUrl('');
    setLink('');
    setShareEnabled(true);
  }

  return (
    <div className="single-column">
      <div className="two-column">
        <Panel title="Tạo danh mục tin tức">
          <SmartForm
            fields={[['name', 'Tên danh mục'], ['description', 'Mô tả']]}
            onSubmit={(values) => run(() => api.create('/admin/news-category', values), 'Đã tạo danh mục tin tức')}
          />
        </Panel>
        <Panel title="Danh mục tin tức">
          <Table
            rows={data.newsCategories}
            columns={[
              ['name', 'Tên'],
              ['description', 'Mô tả'],
              [(row: NewsCategory) => row._count?.items ?? 0, 'Số tin'],
              [
                (row: NewsCategory) => (
                  <button className="ghost" type="button" onClick={() => editCategory(row)}>
                    <Pencil size={15} />
                    Sửa
                  </button>
                ),
                'Thao tác',
              ],
            ]}
            onDelete={(row) => run(() => api.remove(`/admin/news-category/${row.id}`), 'Đã xóa danh mục tin')}
          />
        </Panel>
      </div>

      <Panel title="Tạo tin riêng">
        <div className="news-editor">
          {editingNewsId && (
            <div className="scripture-form-heading span">
              <div>
                <strong>Đang sửa tin</strong>
                <span>Nội dung sẽ được cập nhật vào tin đã chọn.</span>
              </div>
              <button className="ghost" type="button" onClick={resetNewsForm}>
                Tạo tin mới
              </button>
            </div>
          )}
          <label>
            Tiêu đề
            <input value={title} onChange={(event) => setTitle(event.target.value)} placeholder="Tiêu đề tin tức" />
          </label>
          <label>
            Danh mục
            <select value={categoryId} onChange={(event) => setCategoryId(event.target.value)}>
              <option value="">Không chọn</option>
              {data.newsCategories.map((item) => (
                <option key={item.id} value={item.id}>
                  {item.name}
                </option>
              ))}
            </select>
          </label>
          <label className="span">
            Tóm tắt
            <textarea value={summary} onChange={(event) => setSummary(event.target.value)} />
          </label>
          <label>
            Ảnh tin
            <UploadField kind="images/news" value={imageUrl} onUploaded={setImageUrl} />
          </label>
          <label>
            Link gốc hoặc link chia sẻ
            <input value={link} onChange={(event) => setLink(event.target.value)} placeholder="https://..." />
          </label>
          <div className="span" style={{ display: 'grid', gap: '7px', color: '#6a564e', fontSize: '13px', fontWeight: 700 }}>
            Nội dung
            <RichTextEditor
              value={content}
              onChange={setContent}
              placeholder="Viết nội dung tin tức"
              imageUploadKind="images/news"
            />
          </div>
          <label className="check-row span">
            <input type="checkbox" checked={shareEnabled} onChange={(event) => setShareEnabled(event.target.checked)} />
            <Share2 size={16} />
            Cho phép chia sẻ lên mạng xã hội
          </label>
          <button
            className="primary quote-save-button"
            type="button"
            onClick={async () => {
              const payload = {
                title,
                summary,
                content,
                imageUrl,
                link,
                categoryId,
                shareEnabled,
                sourceType: 'MANUAL',
              };
              const ok = await run(
                () =>
                  editingNewsId
                    ? api.update(`/admin/news/${editingNewsId}`, payload)
                    : api.create('/admin/news', payload),
                editingNewsId ? 'Đã cập nhật tin tức' : 'Đã tạo tin riêng',
              );
              if (ok) resetNewsForm();
            }}
          >
            <Save size={16} />
            {editingNewsId ? 'Cập nhật tin' : 'Lưu tin'}
          </button>
        </div>
      </Panel>

      <Panel title="Danh sách tin tức">
        <Table
          rows={data.news}
          columns={[
            ['imageUrl', 'Ảnh'],
            ['title', 'Tiêu đề'],
            [(row: NewsItem) => row.category?.name ?? '-', 'Danh mục'],
            [(row: NewsItem) => (row.sourceType === 'MANUAL' ? 'Tin riêng' : 'RSS'), 'Nguồn'],
            [(row: NewsItem) => (row.shareEnabled ? 'Cho phép' : 'Tắt'), 'Chia sẻ'],
            [(row: NewsItem) => row.viewCount.toLocaleString('vi-VN'), 'Lượt xem'],
            [(row: NewsItem) => new Date(row.publishedAt).toLocaleDateString('vi-VN'), 'Ngày đăng'],
            [
              (row: NewsItem) => (
                <div className="action-group">
                  <button className="ghost" type="button" onClick={() => editNews(row)}>
                    <Pencil size={15} />
                    Sửa
                  </button>
                  <button
                    className="ghost"
                    type="button"
                    onClick={() => run(() => api.update(`/admin/news/${row.id}`, { shareEnabled: !row.shareEnabled }), row.shareEnabled ? 'Đã tắt chia sẻ' : 'Đã bật chia sẻ')}
                  >
                    <Share2 size={15} />
                    {row.shareEnabled ? 'Tắt chia sẻ' : 'Bật chia sẻ'}
                  </button>
                </div>
              ),
              'Thao tác',
            ],
          ]}
          onDelete={(row) => run(() => api.remove(`/admin/news/${row.id}`), 'Đã xóa tin')}
        />
      </Panel>
    </div>
  );
}

function MeditationManager({ data, run }: { data: DataState; run: RunAction }) {
  function editMeditation(row: MeditationProgram) {
    const title = askText('Tiêu đề', row.title);
    if (title === undefined) return;
    const description = askText('Mô tả', row.description ?? '');
    if (description === undefined) return;
    const duration = askNumber('Thời lượng giây', row.duration);
    if (duration === undefined) return;
    const audioUrl = askText('Âm thanh nền URL', row.audioUrl ?? '');
    if (audioUrl === undefined) return;
    const imageUrl = askText('Ảnh nền URL', row.imageUrl ?? '');
    if (imageUrl === undefined) return;
    void run(
      () => api.update(`/admin/meditation/${row.id}`, { title, description, duration, audioUrl, imageUrl }),
      'Đã cập nhật bài Thiền',
    );
  }

  return (
    <div className="single-column">
      <Panel title="Tạo bài Thiền">
        <SmartForm
          fields={[
            ['title', 'Tiêu đề'],
            ['description', 'Mô tả'],
            ['duration', 'Thời lượng giây', 'number'],
            ['audioUrl', 'Âm thanh nền', 'upload:audio/meditation'],
            ['imageUrl', 'Ảnh nền', 'upload:images/meditation'],
          ]}
          onSubmit={(values) => run(() => api.create('/admin/meditation', { ...values, duration: Number(values.duration || 0), active: true }), 'Đã tạo bài Thiền')}
        />
      </Panel>
      <Panel title="Danh sách bài Thiền">
        <Table
          rows={data.meditationPrograms}
          columns={[
            ['imageUrl', 'Ảnh'],
            ['title', 'Tiêu đề'],
            ['description', 'Mô tả'],
            [(row: MeditationProgram) => `${row.duration}s`, 'Thời lượng'],
            [(row: MeditationProgram) => (row.active ? 'Đang bật' : 'Tắt'), 'Trạng thái'],
            [
              (row: MeditationProgram) => (
                <div className="action-group">
                  <button className="ghost" type="button" onClick={() => editMeditation(row)}>
                    <Pencil size={15} />
                    Sửa
                  </button>
                  <button
                    className="ghost"
                    type="button"
                    onClick={() => run(() => api.update(`/admin/meditation/${row.id}`, { active: !row.active }), row.active ? 'Đã tắt bài Thiền' : 'Đã bật bài Thiền')}
                  >
                    <Power size={15} />
                    {row.active ? 'Tắt' : 'Bật'}
                  </button>
                </div>
              ),
              'Thao tác',
            ],
          ]}
          onDelete={(row) => run(() => api.remove(`/admin/meditation/${row.id}`), 'Đã xóa bài Thiền')}
        />
      </Panel>
    </div>
  );
}

function RssManager({ data, run }: { data: DataState; run: RunAction }) {
  function editRss(row: RssSource) {
    const name = askText('Tên website', row.name);
    if (name === undefined) return;
    const url = askText('RSS URL', row.url);
    if (url === undefined) return;
    void run(() => api.update(`/admin/rss/${row.id}`, { name, url }), 'Đã cập nhật RSS');
  }

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
            [
              (row: RssSource) => (
                <div className="action-group">
                  <button className="ghost" type="button" onClick={() => editRss(row)}>
                    <Pencil size={15} />
                    Sửa
                  </button>
                  <button
                    className="ghost"
                    type="button"
                    onClick={() => run(() => api.update(`/admin/rss/${row.id}`, { active: !row.active }), row.active ? 'Đã tắt RSS' : 'Đã bật RSS')}
                  >
                    <Power size={15} />
                    {row.active ? 'Tắt' : 'Bật'}
                  </button>
                </div>
              ),
              'Thao tác',
            ],
          ]}
          onDelete={(row) => run(() => api.remove(`/admin/rss/${row.id}`), 'Đã xóa RSS')}
        />
      </Panel>
    </div>
  );
}

function QuoteManager({ data, run }: { data: DataState; run: RunAction }) {
  const [content, setContent] = useState('');
  const [imageUrl, setImageUrl] = useState('');
  const [editingQuoteId, setEditingQuoteId] = useState('');
  const [selectedQuoteIds, setSelectedQuoteIds] = useState<string[]>(data.quoteRotation.quoteIds);
  const activeQuote = data.quotes.find((quote) => quote.active);
  const activeQuoteId = data.quoteRotation.currentQuoteId ?? activeQuote?.id ?? null;
  const hasLockedActive = Boolean(activeQuoteId);
  const selectedCount = selectedQuoteIds.length;

  useEffect(() => {
    setSelectedQuoteIds(data.quoteRotation.quoteIds);
  }, [data.quoteRotation.quoteIds.join('|')]);

  function editQuote(row: QuoteRecord) {
    setEditingQuoteId(row.id);
    setContent(row.content);
    setImageUrl(row.imageUrl ?? '');
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  function resetQuoteForm() {
    setEditingQuoteId('');
    setContent('');
    setImageUrl('');
  }

  function toggleSelected(id: string, checked: boolean) {
    setSelectedQuoteIds((current) => checked ? [...current, id] : current.filter((quoteId) => quoteId !== id));
  }

  async function saveQuoteRotation(enabled: boolean) {
    const orderedIds = data.quotes.map((quote) => quote.id).filter((id) => selectedQuoteIds.includes(id));
    const ok = await run(
      () => api.updateQuoteRotation({ enabled, quoteIds: orderedIds, paused: false }),
      enabled ? 'Đã bật auto chuyển trích dẫn' : 'Đã tắt auto chuyển trích dẫn',
    );
    if (ok) setSelectedQuoteIds(orderedIds);
  }

  return (
    <div className="single-column">
      <Panel title={editingQuoteId ? 'Sửa trích dẫn' : 'Tạo trích dẫn'}>
        <div className="quote-editor">
          {editingQuoteId && (
            <div className="scripture-form-heading">
              <div>
                <strong>Đang sửa trích dẫn</strong>
                <span>Nội dung sẽ được cập nhật vào trích dẫn đã chọn.</span>
              </div>
              <button className="ghost" type="button" onClick={resetQuoteForm}>
                Tạo trích dẫn mới
              </button>
            </div>
          )}
          <label className="span">
            Nội dung
            <textarea
              className="quote-lines-input"
              value={content}
              onChange={(event) => setContent(event.target.value)}
              placeholder={editingQuoteId ? 'Sửa nội dung trích dẫn này' : 'Mỗi dòng là một trích dẫn riêng.\nVí dụ:\nTâm an thì cảnh an.\nBiết đủ là giàu.'}
            />
            {!editingQuoteId && <span className="field-note">Khi lưu, hệ thống tự tách mỗi dòng thành một trích dẫn riêng.</span>}
          </label>
          <label>
            Ảnh minh họa
            <UploadField kind="images/quote" value={imageUrl} onUploaded={setImageUrl} />
          </label>
          <button
            className="primary"
            type="button"
            onClick={async () => {
              const ok = await run(
                () =>
                  editingQuoteId
                    ? api.update(`/admin/quote/${editingQuoteId}`, { content, imageUrl })
                    : api.create('/admin/quote', { content, imageUrl }),
                editingQuoteId ? 'Đã cập nhật trích dẫn' : 'Đã tạo trích dẫn',
              );
              if (ok) resetQuoteForm();
            }}
          >
            <Save size={16} />
            {editingQuoteId ? 'Cập nhật trích dẫn' : 'Lưu trích dẫn'}
          </button>
        </div>
      </Panel>
      <Panel title="Danh sách trích dẫn">
        <div className="quote-controlbar">
          <div>
            <strong>Auto chuyển trích dẫn</strong>
            <span>
              {data.quoteRotation.enabled
                ? data.quoteRotation.paused
                  ? 'Đang dừng, giữ nguyên trích dẫn hiện tại.'
                  : 'Đang chạy, tự đổi sau 00:00 giờ Việt Nam.'
                : selectedCount > 0
                  ? `Đã chọn ${selectedCount.toLocaleString('vi-VN')} trích dẫn.`
                  : 'Chọn các trích dẫn theo thứ tự từ trên xuống dưới rồi bật auto.'}
            </span>
          </div>
          <div className="action-group">
            <button
              className="ghost"
              type="button"
              disabled={selectedCount === 0}
              onClick={() => void saveQuoteRotation(!data.quoteRotation.enabled)}
            >
              <Power size={15} />
              {data.quoteRotation.enabled ? 'Tắt auto' : 'Bật auto'}
            </button>
            <button
              className="ghost"
              type="button"
              disabled={!data.quoteRotation.enabled}
              onClick={() => run(() => api.updateQuoteRotation({ paused: !data.quoteRotation.paused }), data.quoteRotation.paused ? 'Đã tiếp tục auto' : 'Đã dừng auto')}
            >
              {data.quoteRotation.paused ? <Play size={15} /> : <Pause size={15} />}
              {data.quoteRotation.paused ? 'Tiếp tục' : 'Dừng'}
            </button>
            <button
              className="ghost"
              type="button"
              disabled={!data.quoteRotation.enabled || data.quoteRotation.paused || selectedCount < 2}
              onClick={() => run(() => api.skipQuoteRotation(), 'Đã chuyển sang trích dẫn tiếp theo')}
            >
              <RefreshCcw size={15} />
              Bỏ qua
            </button>
          </div>
        </div>
        <Table
          rows={data.quotes}
          columns={[
            [
              (row: QuoteRecord) => (
                <input
                  className="table-checkbox"
                  type="checkbox"
                  checked={selectedQuoteIds.includes(row.id)}
                  onChange={(event) => toggleSelected(row.id, event.target.checked)}
                />
              ),
              'Chọn',
            ],
            ['imageUrl', 'Ảnh'],
            [
              (row: QuoteRecord) => (
                <span className={row.id === activeQuoteId ? 'quote-current-content' : ''}>
                  {row.content}
                </span>
              ),
              'Nội dung',
            ],
            [
              (row: QuoteRecord) => (
                <div className="quote-status-cell">
                  {row.id === activeQuoteId && <span className="status-pill active">Đang hiển thị</span>}
                  {row.id !== activeQuoteId && <span className="status-pill">Tắt</span>}
                  <button
                    className={`toggle-switch ${row.active ? 'on' : ''}`}
                    type="button"
                    disabled={data.quoteRotation.enabled || (hasLockedActive && row.id !== activeQuoteId)}
                    aria-label={row.active ? 'Tắt hiển thị trích dẫn' : 'Bật hiển thị trích dẫn'}
                    onClick={() => run(() => api.update(`/admin/quote/${row.id}`, { active: !row.active }), row.active ? 'Đã tắt trích dẫn' : 'Đã bật trích dẫn')}
                  >
                    <span />
                  </button>
                </div>
              ),
              'Trạng thái',
            ],
            [(row: QuoteRecord) => new Date(row.createdAt).toLocaleString('vi-VN'), 'Ngày tạo'],
            [
              (row: QuoteRecord) => (
                <div className="action-group">
                  <button className="ghost" type="button" onClick={() => editQuote(row)}>
                    <Pencil size={15} />
                    Sửa
                  </button>
                </div>
              ),
              'Thao tác',
            ],
          ]}
          onDelete={(row) => run(() => api.remove(`/admin/quote/${row.id}`), 'Đã xóa trích dẫn')}
          pageSize={10}
        />
      </Panel>
    </div>
  );
}

function BannerManager({ data, run }: { data: DataState; run: RunAction }) {
  function editBanner(row: Banner) {
    const imageUrl = askText('Ảnh banner URL', row.imageUrl);
    if (imageUrl === undefined) return;
    const link = askText('Liên kết', row.link ?? '');
    if (link === undefined) return;
    void run(() => api.update(`/admin/banner/${row.id}`, { imageUrl, link }), 'Đã cập nhật banner');
  }

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
            [
              (row: Banner) => (
                <div className="action-group">
                  <button className="ghost" type="button" onClick={() => editBanner(row)}>
                    <Pencil size={15} />
                    Sửa
                  </button>
                  <button
                    className="ghost"
                    type="button"
                    onClick={() => run(() => api.update(`/admin/banner/${row.id}`, { active: !row.active }), row.active ? 'Đã tắt banner' : 'Đã bật banner')}
                  >
                    <Power size={15} />
                    {row.active ? 'Tắt' : 'Bật'}
                  </button>
                </div>
              ),
              'Thao tác',
            ],
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
            ['username', 'Tài khoản'],
            ['email', 'Email'],
            ['birthDate', 'Ngày sinh', 'date'],
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
            ['username', 'Tài khoản'],
            ['name', 'Họ tên'],
            ['email', 'Email'],
            [(row: AdminUser) => (row.birthDate ? new Date(row.birthDate).toLocaleDateString('vi-VN') : '-'), 'Ngày sinh'],
            [(row: AdminUser) => (row.role === 'ADMIN' ? 'Quản trị viên' : 'Người dùng'), 'Vai trò'],
            [(row: AdminUser) => (row.active ? 'Đang hoạt động' : 'Đã dừng'), 'Trạng thái'],
            [(row: AdminUser) => row._count?.playlists ?? 0, 'Playlist'],
            [(row: AdminUser) => row._count?.favorites ?? 0, 'Yêu thích'],
            [(row: AdminUser) => new Date(row.createdAt).toLocaleDateString('vi-VN'), 'Ngày tạo'],
            [
              (row: AdminUser) => (
                <div className="action-group">
                  <button
                    className="ghost"
                    type="button"
                    onClick={() => {
                      const name = window.prompt('Họ tên', row.name ?? '');
                      if (name === null) return;
                      const username = window.prompt('Tài khoản', row.username ?? '');
                      if (username === null) return;
                      void run(() => api.update(`/admin/users/${row.id}`, { name, username }), 'Đã cập nhật tài khoản');
                    }}
                  >
                    Sửa
                  </button>
                  <button
                    className="ghost"
                    type="button"
                    onClick={() => run(() => api.update(`/admin/users/${row.id}`, { active: !row.active }), row.active ? 'Đã dừng tài khoản' : 'Đã kích hoạt tài khoản')}
                  >
                    {row.active ? 'Dừng' : 'Kích hoạt'}
                  </button>
                </div>
              ),
              'Thao tác',
            ],
          ]}
          onDelete={(row) => run(() => api.remove(`/admin/users/${row.id}`), 'Đã xóa tài khoản')}
        />
      </Panel>
    </div>
  );
}

function FeedbackManager({ data, run }: { data: DataState; run: RunAction }) {
  function viewFeedback(row: Feedback) {
    window.alert(`${row.type}\n${row.user?.username || row.user?.email || row.user?.name || 'Khách/không xác định'}\n\n${row.content}`);
  }

  return (
    <Panel title="Góp ý và báo lỗi từ người dùng">
      <Table
        rows={data.feedback}
        columns={[
          ['type', 'Loại'],
          [(row: Feedback) => row.user?.username || row.user?.email || row.user?.name || 'Khách/không xác định', 'Người góp ý'],
          ['content', 'Nội dung'],
          [(row: Feedback) => new Date(row.createdAt).toLocaleString('vi-VN'), 'Thời gian'],
          [
            (row: Feedback) => (
              <button className="ghost" type="button" onClick={() => viewFeedback(row)}>
                <Eye size={15} />
                Xem
              </button>
            ),
            'Thao tác',
          ],
        ]}
        onDelete={(row) => run(() => api.remove(`/admin/feedback/${row.id}`), 'Đã xóa góp ý')}
      />
    </Panel>
  );
}

function SettingsPanel({ onSaved }: { onSaved: () => void }) {
  const [value, setValue] = useState(getApiBaseUrl());
  const settings = React.useContext(SettingsContext);
  const [contentPageSize, setContentPageSize] = useState(String(settings.contentPageSize));
  const [usage, setUsage] = useState<R2Usage | null>(null);
  const [usageError, setUsageError] = useState('');

  async function loadUsage() {
    setUsageError('');
    try {
      setUsage(await api.r2Usage());
    } catch (error) {
      setUsageError(error instanceof Error ? error.message : 'Không tải được usage R2');
    }
  }

  useEffect(() => {
    void loadUsage();
  }, []);

  useEffect(() => {
    setContentPageSize(String(settings.contentPageSize));
  }, [settings.contentPageSize]);

  return (
    <div className="single-column">
      <Panel title="Cấu hình kết nối API">
        <form
          className="form"
          onSubmit={(event) => {
            event.preventDefault();
            setApiBaseUrl(value);
            void onSaved();
            void loadUsage();
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
      <Panel title="Cấu hình hiển thị">
        <form
          className="form"
          onSubmit={async (event) => {
            event.preventDefault();
            await api.updateSettings({ contentPageSize: Number(contentPageSize) });
            void onSaved();
          }}
        >
          <label>
            Số bài mỗi trang
            <input
              type="number"
              min="1"
              max="100"
              value={contentPageSize}
              onChange={(event) => setContentPageSize(event.target.value)}
            />
            <span className="field-note">Áp dụng chung cho các bảng danh sách trong toàn bộ menu quản trị.</span>
          </label>
          <button className="primary" type="submit">
            <Save size={16} />
            Lưu số bài mỗi trang
          </button>
        </form>
      </Panel>
      <Panel title="Usage R2">
        <div className="usage-grid">
          <article>
            <span>Bucket</span>
            <strong>{usage?.bucket ?? '-'}</strong>
          </article>
          <article>
            <span>Dung lượng</span>
            <strong>{usage ? formatBytes(usage.storageBytes) : '-'}</strong>
          </article>
          <article>
            <span>Số object</span>
            <strong>{usage?.objectCount ?? '-'}</strong>
          </article>
          <article>
            <span>Băng thông 30 ngày</span>
            <strong>{usage?.bandwidth.available ? formatBytes(usage.bandwidth.bytes ?? 0) : 'Chưa có dữ liệu'}</strong>
          </article>
          <article>
            <span>Requests 30 ngày</span>
            <strong>{usage?.bandwidth.available ? usage.bandwidth.requests?.toLocaleString('vi-VN') : '-'}</strong>
          </article>
        </div>
        {usage?.bandwidth.reason && <p className="field-note">Băng thông cần cấu hình CLOUDFLARE_API_TOKEN trên backend để đọc Cloudflare GraphQL.</p>}
        {usageError && <p className="error">{usageError}</p>}
        <button className="ghost" type="button" onClick={() => void loadUsage()}>
          <RefreshCcw size={16} />
          Tải lại usage
        </button>
      </Panel>
    </div>
  );
}

type RunAction = (action: () => Promise<unknown>, message: string) => Promise<boolean>;
type Field = [name: string, label: string, type?: string, options?: string[][]];

function askText(label: string, current = '') {
  return window.prompt(label, current) ?? undefined;
}

function askNumber(label: string, current: number) {
  const value = window.prompt(label, String(current));
  if (value === null) return undefined;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : undefined;
}

function compactPayload(values: Record<string, unknown>) {
  return Object.fromEntries(Object.entries(values).filter(([, value]) => value !== undefined));
}

function detectMediaDuration(url: string, kind: 'audio' | 'video'): Promise<number> {
  const cleanUrl = url.trim();
  if (!cleanUrl) return Promise.resolve(0);

  return new Promise((resolve) => {
    const media = document.createElement(kind);
    const timeout = window.setTimeout(() => finish(0), 7000);

    function finish(value: number) {
      window.clearTimeout(timeout);
      media.removeAttribute('src');
      media.load();
      resolve(Number.isFinite(value) && value > 0 ? Math.round(value) : 0);
    }

    media.preload = 'metadata';
    media.onloadedmetadata = () => finish(media.duration);
    media.onerror = () => finish(0);
    media.src = cleanUrl;
  });
}

function formatDurationSeconds(seconds?: number) {
  const safe = Math.max(0, Number(seconds || 0));
  if (safe === 0) return 'Tự nhận khi phát';
  const hours = Math.floor(safe / 3600);
  const minutes = Math.floor((safe % 3600) / 60).toString().padStart(2, '0');
  const rest = Math.floor(safe % 60).toString().padStart(2, '0');
  return hours > 0 ? `${hours}:${minutes}:${rest}` : `${minutes}:${rest}`;
}

function formatBytes(bytes?: number | null) {
  const safe = Math.max(0, Number(bytes || 0));
  if (safe < 1024) return `${safe} B`;
  const units = ['KB', 'MB', 'GB', 'TB'];
  let value = safe / 1024;
  let index = 0;
  while (value >= 1024 && index < units.length - 1) {
    value /= 1024;
    index += 1;
  }
  return `${value.toFixed(value >= 10 ? 1 : 2)} ${units[index]}`;
}

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
          ) : label === 'Nội dung' ? (
            <BbCodeTextarea value={values[name]} onChange={(value) => setValues({ ...values, [name]: value })} compact />
          ) : label === 'Mô tả' ? (
            <textarea value={values[name]} onChange={(event) => setValues({ ...values, [name]: event.target.value })} />
          ) : (
            <input type={type} value={values[name]} onChange={(event) => setValues({ ...values, [name]: event.target.value })} required={['name', 'title', 'url', 'audioUrl', 'videoUrl', 'imageUrl', 'content', 'timeOfDay'].includes(name)} />
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
  const accept = kind.startsWith('audio') ? 'audio/mpeg,.mp3' : kind.startsWith('video') ? 'video/mp4,.mp4' : 'image/*';

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
  pageSize,
}: {
  rows: T[];
  columns: Array<[keyof T | ((row: T) => React.ReactNode), string]>;
  onDelete?: (row: T) => void;
  pageSize?: number;
}) {
  const { contentPageSize } = React.useContext(SettingsContext);
  const resolvedPageSize = Math.max(1, Number(pageSize ?? contentPageSize ?? 10));
  const [page, setPage] = useState(1);
  const pageCount = Math.max(1, Math.ceil(rows.length / resolvedPageSize));
  const safePage = Math.min(page, pageCount);
  const visibleRows = rows.slice((safePage - 1) * resolvedPageSize, safePage * resolvedPageSize);
  const pageButtons = paginationPages(safePage, pageCount);

  useEffect(() => {
    setPage(1);
  }, [resolvedPageSize, rows.length]);

  useEffect(() => {
    if (page > pageCount) setPage(pageCount);
  }, [page, pageCount]);

  if (rows.length === 0) return <div className="empty">Chưa có dữ liệu.</div>;

  return (
    <>
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
            {visibleRows.map((row) => (
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
                    <button
                      className="danger"
                      type="button"
                      onClick={() => {
                        if (window.confirm('Xóa mục này? Thao tác này không thể hoàn tác.')) onDelete(row);
                      }}
                    >
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
      {pageCount > 1 && (
        <div className="pagination">
          <span>
            Trang {safePage}/{pageCount} • {rows.length.toLocaleString('vi-VN')} mục
          </span>
          <div>
            <button className="ghost page-jump" type="button" disabled={safePage === 1} onClick={() => setPage(1)}>
              1
            </button>
            {pageButtons[0] > 2 && <span className="page-ellipsis">...</span>}
            {pageButtons.map((pageNumber) => (
              <button
                key={pageNumber}
                className={`ghost page-jump ${pageNumber === safePage ? 'active' : ''}`}
                type="button"
                disabled={pageNumber === safePage}
                onClick={() => setPage(pageNumber)}
              >
                {pageNumber}
              </button>
            ))}
            {pageButtons[pageButtons.length - 1] < pageCount - 1 && <span className="page-ellipsis">...</span>}
            {pageCount > 1 && (
              <button className="ghost page-jump" type="button" disabled={safePage === pageCount} onClick={() => setPage(pageCount)}>
                {pageCount}
              </button>
            )}
            <button className="ghost" type="button" disabled={safePage === 1} onClick={() => setPage((value) => Math.max(1, value - 1))}>
              Trước
            </button>
            <button className="ghost" type="button" disabled={safePage === pageCount} onClick={() => setPage((value) => Math.min(pageCount, value + 1))}>
              Sau
            </button>
          </div>
        </div>
      )}
    </>
  );
}

function paginationPages(current: number, total: number) {
  const pages = new Set<number>();
  for (let page = current - 1; page <= current + 1; page += 1) {
    if (page > 1 && page < total) pages.add(page);
  }
  if (current === 1 && total > 2) pages.add(2);
  if (current === total && total > 2) pages.add(total - 1);
  return Array.from(pages).sort((a, b) => a - b);
}

createRoot(document.getElementById('root')!).render(<App />);
