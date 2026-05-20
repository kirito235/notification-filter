import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'constants/theme.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppTheme.surface,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const FilterNotifApp());
}

class FilterNotifApp extends StatelessWidget {
  const FilterNotifApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FilterNotif',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const SplashScreen(),
    );
  }
}
