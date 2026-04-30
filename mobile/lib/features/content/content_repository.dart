import 'content_models.dart';

class ContentRepository {
  List<AudioCategory> get audioCategories => const [
    AudioCategory(id: 'adi-da', name: 'Kinh A Di Da'),
    AudioCategory(id: 'pho-mon', name: 'Kinh Pho Mon'),
    AudioCategory(id: 'dia-tang', name: 'Kinh Dia Tang'),
    AudioCategory(id: 'thien-tap', name: 'Thien tap'),
  ];

  List<AudioItem> get audios => const [
    AudioItem(
      id: 'a1',
      title: 'Kinh A Di Da - Ban tung cham',
      category: 'Kinh A Di Da',
      duration: Duration(minutes: 42, seconds: 18),
      thumbnailUrl:
          'https://images.unsplash.com/photo-1528319725582-ddc096101511?auto=format&fit=crop&w=900&q=80',
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
      description: 'Ban tung niem tinh lang, phu hop nghe moi ngay.',
    ),
    AudioItem(
      id: 'a2',
      title: 'Kinh Pho Mon - Quan The Am',
      category: 'Kinh Pho Mon',
      duration: Duration(minutes: 36, seconds: 7),
      thumbnailUrl:
          'https://images.unsplash.com/photo-1545389336-cf090694435e?auto=format&fit=crop&w=900&q=80',
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
    ),
    AudioItem(
      id: 'a3',
      title: 'Kinh Dia Tang - Pham Nguyen',
      category: 'Kinh Dia Tang',
      duration: Duration(hours: 1, minutes: 12, seconds: 44),
      thumbnailUrl:
          'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=900&q=80',
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
    ),
  ];

  List<VideoItem> get videos => const [
    VideoItem(
      id: 'v1',
      title: 'Song cham de thay binh an',
      teacher: 'Thay Phap Hoa',
      topic: 'Ung dung Phat phap',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1519834785169-98be25ec3f84?auto=format&fit=crop&w=900&q=80',
      videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    ),
    VideoItem(
      id: 'v2',
      title: 'Hieu ve vo thuong trong doi song',
      teacher: 'Thich Nhat Tu',
      topic: 'Giao ly can ban',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1499209974431-9dddcece7f88?auto=format&fit=crop&w=900&q=80',
      videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    ),
  ];

  List<NewsItem> get news => [
    NewsItem(
      id: 'n1',
      title: 'Khoa tu mua he danh cho Phat tu tre',
      source: 'RSS Giao hoi',
      publishedAt: DateTime(2026, 4, 30),
    ),
    NewsItem(
      id: 'n2',
      title: 'Nhung bai hoc ve long tu bi trong doi song hien dai',
      source: 'Phat giao VN',
      publishedAt: DateTime(2026, 4, 29),
    ),
  ];
}
