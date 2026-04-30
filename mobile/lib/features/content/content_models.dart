class AudioCategory {
  const AudioCategory({required this.id, required this.name, this.description});

  final String id;
  final String name;
  final String? description;
}

class AudioItem {
  const AudioItem({
    required this.id,
    required this.title,
    required this.category,
    required this.duration,
    required this.thumbnailUrl,
    required this.audioUrl,
    this.description,
  });

  final String id;
  final String title;
  final String category;
  final Duration duration;
  final String thumbnailUrl;
  final String audioUrl;
  final String? description;
}

class VideoItem {
  const VideoItem({
    required this.id,
    required this.title,
    required this.teacher,
    required this.topic,
    required this.thumbnailUrl,
    required this.videoUrl,
    this.description,
  });

  final String id;
  final String title;
  final String teacher;
  final String topic;
  final String thumbnailUrl;
  final String videoUrl;
  final String? description;
}

class NewsItem {
  const NewsItem({
    required this.id,
    required this.title,
    required this.source,
    required this.publishedAt,
  });

  final String id;
  final String title;
  final String source;
  final DateTime publishedAt;
}
