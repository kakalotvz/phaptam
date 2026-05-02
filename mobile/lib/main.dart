import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/network/api_client.dart';
import 'core/notifications/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await apiClient.restoreSession();
  await NotificationService.instance.init();
  runApp(const ProviderScope(child: PhapTamApp()));
}
