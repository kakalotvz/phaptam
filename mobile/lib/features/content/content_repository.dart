import 'content_models.dart';

class ContentRepository {
  List<AudioCategory> get audioCategories => const [
    AudioCategory(id: 'adi-da', name: 'Kinh A Di Đà'),
    AudioCategory(id: 'pho-mon', name: 'Kinh Phổ Môn'),
    AudioCategory(id: 'dia-tang', name: 'Kinh Địa Tạng'),
    AudioCategory(id: 'thien-tap', name: 'Thiền tập'),
  ];

  List<AudioItem> get audios => const [
    AudioItem(
      id: 'a1',
      title: 'Kinh A Di Đà - Bản tụng chậm',
      category: 'Kinh A Di Đà',
      duration: Duration(minutes: 42, seconds: 18),
      thumbnailUrl:
          'https://images.unsplash.com/photo-1528319725582-ddc096101511?auto=format&fit=crop&w=900&q=80',
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
      description: 'Bản tụng niệm tĩnh lặng, phù hợp nghe mỗi ngày.',
    ),
    AudioItem(
      id: 'a2',
      title: 'Kinh Phổ Môn - Quan Thế Âm',
      category: 'Kinh Phổ Môn',
      duration: Duration(minutes: 36, seconds: 7),
      thumbnailUrl:
          'https://images.unsplash.com/photo-1545389336-cf090694435e?auto=format&fit=crop&w=900&q=80',
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
    ),
    AudioItem(
      id: 'a3',
      title: 'Kinh Địa Tạng - Phẩm Nguyện',
      category: 'Kinh Địa Tạng',
      duration: Duration(hours: 1, minutes: 12, seconds: 44),
      thumbnailUrl:
          'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=900&q=80',
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
    ),
  ];

  List<VideoItem> get videos => const [
    VideoItem(
      id: 'v1',
      title: 'Sống chậm để thấy bình an',
      teacher: 'Thầy Pháp Hòa',
      topic: 'Ứng dụng Phật pháp',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1519834785169-98be25ec3f84?auto=format&fit=crop&w=900&q=80',
      videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    ),
    VideoItem(
      id: 'v2',
      title: 'Hiểu về vô thường trong đời sống',
      teacher: 'Thich Nhat Tu',
      topic: 'Giáo lý căn bản',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1499209974431-9dddcece7f88?auto=format&fit=crop&w=900&q=80',
      videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    ),
  ];

  List<NewsItem> get news => [
    NewsItem(
      id: 'n1',
      title: 'Khóa tu mùa hè dành cho Phật tử trẻ',
      source: 'RSS Giáo hội',
      publishedAt: DateTime(2026, 4, 30),
    ),
    NewsItem(
      id: 'n2',
      title: 'Những bài học về lòng từ bi trong đời sống hiện đại',
      source: 'Phật giáo VN',
      publishedAt: DateTime(2026, 4, 29),
    ),
  ];
}
