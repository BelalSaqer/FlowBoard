import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'providers/theme_provider.dart';
import 'screens/root_gate.dart';
import 'services/deep_link.dart';
import 'services/url_strategy.dart';
import 'theme/app_theme.dart';

void main() async {
  // Must run before anything else — see captureInitialDeepLink's doc.
  captureInitialDeepLink();
  WidgetsFlutterBinding.ensureInitialized();
  configureUrlStrategy();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: FlowBoardApp()));
}

class FlowBoardApp extends ConsumerWidget {
  const FlowBoardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'FlowBoard',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: const RootGate(),
    );
  }
}
