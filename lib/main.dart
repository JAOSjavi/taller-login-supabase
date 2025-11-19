import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'router.dart';
import 'services/supabase_service.dart';
import 'services/session_service.dart';
import 'controllers/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cargar variables de entorno
  await dotenv.load(fileName: ".env");

  // Inicializar Supabase
  await SupabaseService.instance.initialize();

  // Cargar sesión guardada
  await SessionService.instance.loadUser();

  // Inicializar controlador de tema
  Get.put(ThemeController());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeController themeController = Get.find<ThemeController>();

    return Obx(
      () => MaterialApp.router(
        title: 'Sistema de Salud',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          fontFamily: 'Poppins',
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.blue[600],
            foregroundColor: Colors.white,
            elevation: 0,
            titleTextStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          textTheme: const TextTheme(
            displayLarge: TextStyle(fontFamily: 'Poppins'),
            displayMedium: TextStyle(fontFamily: 'Poppins'),
            displaySmall: TextStyle(fontFamily: 'Poppins'),
            headlineLarge: TextStyle(fontFamily: 'Poppins'),
            headlineMedium: TextStyle(fontFamily: 'Poppins'),
            headlineSmall: TextStyle(fontFamily: 'Poppins'),
            titleLarge: TextStyle(fontFamily: 'Poppins'),
            titleMedium: TextStyle(fontFamily: 'Poppins'),
            titleSmall: TextStyle(fontFamily: 'Poppins'),
            bodyLarge: TextStyle(fontFamily: 'Poppins'),
            bodyMedium: TextStyle(fontFamily: 'Poppins'),
            bodySmall: TextStyle(fontFamily: 'Poppins'),
            labelLarge: TextStyle(fontFamily: 'Poppins'),
            labelMedium: TextStyle(fontFamily: 'Poppins'),
            labelSmall: TextStyle(fontFamily: 'Poppins'),
          ),
        ),
        darkTheme: ThemeData(
          colorScheme:
              ColorScheme.fromSeed(
                seedColor: Colors.grey,
                brightness: Brightness.dark,
              ).copyWith(
                background: const Color(0xFF1E1E1E),
                surface: const Color(0xFF2A2A2A),
                primary: Colors.blueGrey[200],
                secondary: Colors.blueGrey[100],
              ),
          useMaterial3: true,
          fontFamily: 'Poppins',
          scaffoldBackgroundColor: const Color(0xFF1E1E1E),
          cardColor: const Color(0xFF2A2A2A),
          dialogBackgroundColor: const Color(0xFF2A2A2A),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF2C2C2C),
            foregroundColor: Colors.white,
            elevation: 0,
            titleTextStyle: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3C3C3C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF2F2F2F),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF444444)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF444444)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blueGrey),
            ),
            labelStyle: const TextStyle(
              color: Colors.white70,
              fontFamily: 'Poppins',
            ),
            hintStyle: const TextStyle(
              color: Colors.white54,
              fontFamily: 'Poppins',
            ),
          ),
          textTheme: const TextTheme(
            displayLarge: TextStyle(fontFamily: 'Poppins'),
            displayMedium: TextStyle(fontFamily: 'Poppins'),
            displaySmall: TextStyle(fontFamily: 'Poppins'),
            headlineLarge: TextStyle(fontFamily: 'Poppins'),
            headlineMedium: TextStyle(fontFamily: 'Poppins'),
            headlineSmall: TextStyle(fontFamily: 'Poppins'),
            titleLarge: TextStyle(fontFamily: 'Poppins'),
            titleMedium: TextStyle(fontFamily: 'Poppins'),
            titleSmall: TextStyle(fontFamily: 'Poppins'),
            bodyLarge: TextStyle(fontFamily: 'Poppins'),
            bodyMedium: TextStyle(fontFamily: 'Poppins'),
            bodySmall: TextStyle(fontFamily: 'Poppins'),
            labelLarge: TextStyle(fontFamily: 'Poppins'),
            labelMedium: TextStyle(fontFamily: 'Poppins'),
            labelSmall: TextStyle(fontFamily: 'Poppins'),
          ),
        ),
        themeMode: themeController.isDarkMode.value
            ? ThemeMode.dark
            : ThemeMode.light,
        routerConfig: AppRouter.router,
      ),
    );
  }
}
