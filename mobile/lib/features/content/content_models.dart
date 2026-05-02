class AudioCategory {
  const AudioCategory({required this.id, required this.name, this.description});

  factory AudioCategory.fromJson(Map<String, dynamic> json) {
    return AudioCategory(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Danh mục',
      description: json['description'] as String?,
    );
  }

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
    required this.createdAt,
    this.viewCount = 0,
    this.description,
  });

  final String id;
  final String title;
  final String category;
  final Duration duration;
  final String thumbnailUrl;
  final String audioUrl;
  final DateTime createdAt;
  final int viewCount;
  final String? description;

  factory AudioItem.fromJson(Map<String, dynamic> json) {
    final category = json['category'];
    return AudioItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Audio',
      category: category is Map<String, dynamic>
          ? category['name'] as String? ?? 'Không danh mục'
          : 'Không danh mục',
      duration: Duration(seconds: NumberParser.asInt(json['duration'])),
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      audioUrl: json['audioUrl'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      viewCount: NumberParser.asInt(json['viewCount']),
      description: json['description'] as String?,
    );
  }
}

class VideoItem {
  const VideoItem({
    required this.id,
    required this.title,
    required this.teacher,
    required this.topic,
    required this.thumbnailUrl,
    required this.videoUrl,
    required this.createdAt,
    this.viewCount = 0,
    this.description,
  });

  final String id;
  final String title;
  final String teacher;
  final String topic;
  final String thumbnailUrl;
  final String videoUrl;
  final DateTime createdAt;
  final int viewCount;
  final String? description;

  factory VideoItem.fromJson(Map<String, dynamic> json) {
    final category = json['category'];
    return VideoItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Video',
      teacher: json['teacher'] as String? ?? '',
      topic: category is Map<String, dynamic>
          ? category['name'] as String? ?? 'Không danh mục'
          : 'Không danh mục',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      videoUrl: json['videoUrl'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      viewCount: NumberParser.asInt(json['viewCount']),
      description: json['description'] as String?,
    );
  }
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
    this.viewCount = 0,
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
  final int viewCount;
  final String? imageUrl;
  final String? link;
  final bool shareEnabled;

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    final category = json['category'];
    return NewsItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Tin tức',
      category: category is Map<String, dynamic>
          ? category['name'] as String? ?? 'Tin tức'
          : 'Tin tức',
      source: json['sourceName'] as String? ?? 'Pháp Tâm',
      publishedAt:
          DateTime.tryParse(json['publishedAt'] as String? ?? '') ??
          DateTime.now(),
      summary: json['summary'] as String? ?? '',
      content: json['content'] as String? ?? json['summary'] as String? ?? '',
      viewCount: NumberParser.asInt(json['viewCount']),
      imageUrl: json['imageUrl'] as String?,
      link: json['link'] as String?,
      shareEnabled: json['shareEnabled'] as bool? ?? true,
    );
  }
}

class MeditationProgram {
  const MeditationProgram({
    required this.id,
    required this.title,
    required this.duration,
    this.description,
    this.audioUrl,
    this.imageUrl,
  });

  factory MeditationProgram.fromJson(Map<String, dynamic> json) {
    return MeditationProgram(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Thiền',
      description: json['description'] as String?,
      duration: Duration(seconds: NumberParser.asInt(json['duration'])),
      audioUrl: json['audioUrl'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  final String id;
  final String title;
  final String? description;
  final Duration duration;
  final String? audioUrl;
  final String? imageUrl;
}

class DailyQuote {
  const DailyQuote({required this.id, required this.content, this.imageUrl});

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
  const HomeBanner({required this.id, required this.imageUrl, this.link});

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

  factory ScriptureLine.fromJson(Map<String, dynamic> json) {
    final seconds = NumberParser.asDouble(
      json['start_time'] ?? json['startTime'],
    );
    return ScriptureLine(
      content: json['content'] as String? ?? '',
      startTime: Duration(milliseconds: (seconds * 1000).round()),
    );
  }

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
    this.categoryId,
    this.category,
    this.createdAt,
    this.viewCount = 0,
  });

  factory Scripture.fromJson(Map<String, dynamic> json) {
    final category = json['category'];
    final rawLines = json['lines'];
    final lines = rawLines is List
        ? rawLines
              .whereType<Map<String, dynamic>>()
              .map(ScriptureLine.fromJson)
              .where((line) => line.content.trim().isNotEmpty)
              .toList()
        : <ScriptureLine>[];
    return Scripture(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Bản đọc Kinh',
      description: json['description'] as String?,
      backgroundImageUrl: json['backgroundImageUrl'] as String?,
      categoryId: json['categoryId'] as String?,
      category: category is Map<String, dynamic>
          ? category['name'] as String? ?? 'Đọc kinh'
          : null,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      viewCount: NumberParser.asInt(json['viewCount']),
      lines: lines,
    );
  }

  final String id;
  final String title;
  final String? description;
  final String? backgroundImageUrl;
  final String? categoryId;
  final String? category;
  final DateTime? createdAt;
  final int viewCount;
  final List<ScriptureLine> lines;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    this.username,
    this.name,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      username: json['username'] as String?,
      name: json['name'] as String?,
    );
  }

  final String id;
  final String email;
  final String? username;
  final String? name;
}

class NumberParser {
  const NumberParser._();

  static int asInt(Object? value) {
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double asDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
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

  factory ScriptureReminder.fromJson(Map<String, dynamic> json) {
    final scriptureJson = json['scripture'];
    final scripture = scriptureJson is Map<String, dynamic>
        ? Scripture.fromJson(scriptureJson)
        : const Scripture(id: '', title: 'Bản đọc Kinh', lines: []);
    return ScriptureReminder(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Nhắc tụng kinh',
      scripture: scripture,
      timeOfDay: _durationFromTimeOfDay(json['timeOfDay'] as String?),
      weekdays: (json['weekdays'] as List? ?? const [])
          .map(NumberParser.asInt)
          .where((value) => value >= 1 && value <= 7)
          .toSet(),
      resumeMode: json['resumeMode'] == 'RESTART'
          ? ReminderResumeMode.restart
          : ReminderResumeMode.resume,
      active: json['active'] as bool? ?? true,
      lastLineIndex: NumberParser.asInt(json['lastLineIndex']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'scriptureId': scripture.id,
      'timeOfDay': _formatTimeOfDay(timeOfDay),
      'weekdays': weekdays.toList()..sort(),
      'resumeMode': resumeMode == ReminderResumeMode.restart
          ? 'RESTART'
          : 'RESUME',
      'active': active,
      'lastLineIndex': lastLineIndex,
    };
  }

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

Duration _durationFromTimeOfDay(String? value) {
  final parts = (value ?? '05:30').split(':');
  final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 5;
  final minute = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 30;
  return Duration(hours: hour.clamp(0, 23), minutes: minute.clamp(0, 59));
}

String _formatTimeOfDay(Duration value) {
  final hour = value.inHours.remainder(24).toString().padLeft(2, '0');
  final minute = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  return '$hour:$minute';
}
