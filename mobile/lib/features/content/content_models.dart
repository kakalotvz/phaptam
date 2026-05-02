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
    required this.category,
    required this.source,
    required this.publishedAt,
    required this.summary,
    required this.content,
    this.imageUrl,
    this.link,
    this.shareEnabled = true,
  });

  final String id;
  final String title;
  final String category;
  final String source;
  final DateTime publishedAt;
  final String summary;
  final String content;
  final String? imageUrl;
  final String? link;
  final bool shareEnabled;
}

class DailyQuote {
  const DailyQuote({
    required this.id,
    required this.content,
    this.imageUrl,
  });

  factory DailyQuote.fromJson(Map<String, dynamic> json) {
    return DailyQuote(
      id: json['id'] as String,
      content: json['content'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
    );
  }

  final String id;
  final String content;
  final String? imageUrl;
}

class HomeBanner {
  const HomeBanner({
    required this.id,
    required this.imageUrl,
    this.link,
  });

  factory HomeBanner.fromJson(Map<String, dynamic> json) {
    return HomeBanner(
      id: json['id'] as String,
      imageUrl: json['imageUrl'] as String? ?? '',
      link: json['link'] as String?,
    );
  }

  final String id;
  final String imageUrl;
  final String? link;
}

class ScriptureLine {
  const ScriptureLine({required this.content, required this.startTime});

  final String content;
  final Duration startTime;
}

class Scripture {
  const Scripture({
    required this.id,
    required this.title,
    required this.lines,
    this.description,
    this.backgroundImageUrl,
  });

  final String id;
  final String title;
  final String? description;
  final String? backgroundImageUrl;
  final List<ScriptureLine> lines;
}

enum ReminderResumeMode { resume, restart }

class ScriptureReminder {
  const ScriptureReminder({
    required this.id,
    required this.title,
    required this.scripture,
    required this.timeOfDay,
    required this.weekdays,
    required this.resumeMode,
    this.active = true,
    this.lastLineIndex = 0,
  });

  final String id;
  final String title;
  final Scripture scripture;
  final Duration timeOfDay;
  final Set<int> weekdays;
  final ReminderResumeMode resumeMode;
  final bool active;
  final int lastLineIndex;

  ScriptureReminder copyWith({
    String? title,
    Scripture? scripture,
    Duration? timeOfDay,
    Set<int>? weekdays,
    ReminderResumeMode? resumeMode,
    bool? active,
    int? lastLineIndex,
  }) {
    return ScriptureReminder(
      id: id,
      title: title ?? this.title,
      scripture: scripture ?? this.scripture,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      weekdays: weekdays ?? this.weekdays,
      resumeMode: resumeMode ?? this.resumeMode,
      active: active ?? this.active,
      lastLineIndex: lastLineIndex ?? this.lastLineIndex,
    );
  }
}
