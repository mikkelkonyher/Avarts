import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_avartsproto/pages/login_page.dart';
import 'package:flutter_avartsproto/pages/register_page.dart';

const Color _scaffoldColor = Color(0xFF0D1117);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const LazyStravaApp());
}

class LazyStravaApp extends StatelessWidget {
  const LazyStravaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final darkScheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF2F81F7),
          brightness: Brightness.dark,
        ).copyWith(
          surface: const Color(0xFF161B22),
          surfaceContainerHighest: const Color(0xFF1F232A),
          primary: const Color(0xFF2F81F7),
          secondary: const Color(0xFF8B949E),
          tertiary: const Color(0xFF8957E5),
          onSurface: const Color(0xFFE6EDF3),
          onPrimary: Colors.white,
        );

    return MaterialApp(
      title: 'LazyStrava',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: darkScheme,
        scaffoldBackgroundColor: _scaffoldColor,
        fontFamily: 'SF Pro Display',
        appBarTheme: AppBarTheme(
          backgroundColor: darkScheme.surface,
          foregroundColor: darkScheme.onSurface,
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          color: darkScheme.surface,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _scaffoldColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: darkScheme.surfaceContainerHighest),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: darkScheme.surfaceContainerHighest),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: darkScheme.primary, width: 1.5),
          ),
          labelStyle: TextStyle(color: darkScheme.secondary),
          hintStyle: TextStyle(
            color: darkScheme.secondary.withValues(alpha: 0.7),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: darkScheme.primary,
            foregroundColor: darkScheme.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: darkScheme.primary,
            textStyle: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        dividerTheme: DividerThemeData(
          color: darkScheme.surfaceContainerHighest,
          thickness: 1,
        ),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginPage(),
        '/register': (_) => const RegisterPage(),
      },
    );
  }
}
