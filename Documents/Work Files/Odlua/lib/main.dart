import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:odlua/firebase_options.dart';
import 'package:odlua/utils/notifications/notificaions_services.dart';
import 'app.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

// Add this navigation handler function
void _handleNotificationNavigation(Map<String, dynamic> payload) {
  final type = payload['type'] as String?;

  if (type == 'chat_message') {
    final chatId = payload['chatId'];
    final senderId = payload['senderId'];

    DebugHelper.log(
        'Chat notification tapped - Chat ID: $chatId, Sender: $senderId');

    // This will be handled by your app's navigation system
    // You can use a global navigator key or event bus to navigate to the chat
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await EasyLocalization.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize notification service and register handler
  await NotificationService().init();
  NotificationService()
      .registerNavigationHandler(_handleNotificationNavigation);

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
        Locale('de'),
        Locale('fr'),
      ],
      path: 'assets/i18n',
      fallbackLocale: const Locale('en'),
      child: const App(),
    ),
  );
}
