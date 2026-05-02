import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/offline/media_downloads.dart';

class MediaDownloadButton extends ConsumerWidget {
  const MediaDownloadButton({
    required this.mediaKey,
    required this.title,
    required this.url,
    super.key,
  });

  final String mediaKey;
  final String title;
  final String url;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(mediaDownloadsProvider);
    return downloads.when(
      loading: () => IconButton(
        tooltip: 'Tải về để nghe/xem offline',
        onPressed: null,
        icon: const Icon(Icons.download_outlined),
      ),
      error: (error, stackTrace) => IconButton(
        tooltip: 'Không đọc được tệp offline',
        onPressed: () => ref.invalidate(mediaDownloadsProvider),
        icon: const Icon(Icons.refresh),
      ),
      data: (state) {
        final downloaded = state.isDownloaded(mediaKey);
        final downloading = state.isDownloading(mediaKey);
        final progress = state.progress[mediaKey] ?? 0;

        if (downloading) {
          return SizedBox.square(
            dimension: 40,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                value: progress > 0 ? progress.clamp(0, 1) : null,
              ),
            ),
          );
        }

        return IconButton(
          tooltip: downloaded ? 'Xóa bản tải về' : 'Tải về để nghe/xem offline',
          onPressed: url.trim().isEmpty
              ? null
              : () async {
                  try {
                    if (downloaded) {
                      await ref
                          .read(mediaDownloadsProvider.notifier)
                          .remove(mediaKey);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã xóa bản tải về')),
                        );
                      }
                    } else {
                      await ref
                          .read(mediaDownloadsProvider.notifier)
                          .download(key: mediaKey, title: title, url: url);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã tải về để dùng offline'),
                          ),
                        );
                      }
                    }
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Chưa tải được tệp')),
                      );
                    }
                  }
                },
          icon: Icon(
            downloaded ? Icons.download_done : Icons.download_outlined,
          ),
        );
      },
    );
  }
}
