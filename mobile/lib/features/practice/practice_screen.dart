import 'package:flutter/material.dart';

import '../meditation/meditation_screen.dart';
import '../scripture/scripture_screen.dart';

class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tu tập')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          _PracticeTile(
            icon: Icons.auto_stories_outlined,
            title: 'Đọc kinh',
            subtitle: 'Đọc dạng trang sách, chỉnh chữ và chế độ ánh sáng ấm.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ScriptureReadingScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _PracticeTile(
            icon: Icons.record_voice_over_outlined,
            title: 'Tụng kinh',
            subtitle: 'Karaoke từng dòng, lịch nhắc và tự chuyển phẩm.',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ScriptureScreen())),
          ),
          const SizedBox(height: 12),
          _PracticeTile(
            icon: Icons.self_improvement_outlined,
            title: 'Thiền',
            subtitle: 'Hẹn giờ thiền và âm thanh nền.',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const MeditationScreen())),
          ),
        ],
      ),
    );
  }
}

class _PracticeTile extends StatelessWidget {
  const _PracticeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 12,
        ),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
          child: Icon(icon),
        ),
        title: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(subtitle),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
