// Flutter imports
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:app_links/app_links.dart';

// Project imports
import 'package:avarts/pages/login_page.dart';
import 'package:avarts/pages/register_page.dart';
import 'package:avarts/pages/reset_password_page.dart';
import 'package:avarts/services/auth_service.dart';

/// Main background color for the app
const Color _scaffoldColor = Color(0xFF0D1117);

/// Application entry point
/// Initializes Flutter bindings, loads environment variables, and initializes Supabase
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize Supabase
  await AuthService.initialize();

  runApp(const AvartsApp());
}

/// Root widget of the application
/// Configures the app theme and routing
class AvartsApp extends StatefulWidget {
  const AvartsApp({super.key});

  @override
  State<AvartsApp> createState() => _AvartsAppState();
}

class _AvartsAppState extends State<AvartsApp> {
  final _appLinks = AppLinks();
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  /// Initialize deep link handling for password reset and email verification
  void _initDeepLinks() {
    // Handle initial link if app was opened via deep link
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _handleDeepLink(uri.toString());
      }
    });

    // Listen for deep links while app is running
    _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri.toString());
    });
  }

  /// Handles deep links for password reset and email verification
  Future<void> _handleDeepLink(String url) async {
    if (!mounted) return;

    try {
      final uri = Uri.parse(url);

      // Check for error parameters (when Supabase redirects with errors)
      final error = uri.queryParameters['error'];
      final errorDescription = uri.queryParameters['error_description'];

      if (error != null) {
        // Handle error cases (e.g., expired link, invalid token)
        final errorMessage =
            errorDescription?.replaceAll('+', ' ') ??
            'An error occurred: $error';

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 5),
          ),
        );

        // Navigate to login page on error
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
        return;
      }

      // Handle password reset
      if (uri.scheme == 'avarts' && uri.host == 'reset-password') {
        final accessToken = uri.queryParameters['access_token'];
        final refreshToken = uri.queryParameters['refresh_token'];

        if (accessToken != null && refreshToken != null) {
          await _authService.handlePasswordResetLink(url);

          if (!mounted) return;

          Navigator.of(context).pushNamedAndRemoveUntil(
            '/reset-password',
            (route) => false,
            arguments: {
              'accessToken': accessToken,
              'refreshToken': refreshToken,
            },
          );
        } else {
          throw Exception(
            'Missing access_token or refresh_token in password reset link',
          );
        }
      }
      // Handle email verification
      else if (uri.scheme == 'avarts' && uri.host == 'email-verified') {
        final accessToken = uri.queryParameters['access_token'];
        final refreshToken = uri.queryParameters['refresh_token'];
        final type = uri.queryParameters['type'];

        if (type == 'signup' && accessToken != null && refreshToken != null) {
          await _authService.handleEmailVerificationLink(url);

          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email verified successfully! You can now log in.'),
            ),
          );

          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/login', (route) => false);
        } else {
          throw Exception('Invalid email verification link parameters');
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error handling link: $e'),
          duration: const Duration(seconds: 5),
        ),
      );

      // Navigate to login on error
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Configure dark theme color scheme
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
      title: 'Avarts',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: darkScheme,
        scaffoldBackgroundColor: _scaffoldColor,
        fontFamily: 'SF Pro Display',

        // AppBar theme configuration
        appBarTheme: AppBarTheme(
          backgroundColor: darkScheme.surface,
          foregroundColor: darkScheme.onSurface,
          elevation: 0,
          centerTitle: true,
        ),

        // Card theme configuration
        cardTheme: CardThemeData(
          color: darkScheme.surface,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),

        // Input field theme configuration
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

        // Button themes
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

        // Divider theme
        dividerTheme: DividerThemeData(
          color: darkScheme.surfaceContainerHighest,
          thickness: 1,
        ),
      ),

      // Routing configuration
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginPage(),
        '/register': (_) => const RegisterPage(),
        '/reset-password': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>?;
          if (args == null) {
            return const LoginPage();
          }
          return ResetPasswordPage(
            accessToken: args['accessToken'] as String,
            refreshToken: args['refreshToken'] as String,
          );
        },
      },
    );
  }
}
