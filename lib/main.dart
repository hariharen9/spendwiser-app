import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'data/services/notifications_service.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationsService.init();
  await NotificationsService.requestPermissions();
  await Hive.initFlutter();
  await Hive.openBox<String>('finance');
  await Hive.openBox<String>('settings');
  GoogleFonts.config.allowRuntimeFetching = false;
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
  runApp(const ProviderScope(child: SpendwiserApp()));
}

