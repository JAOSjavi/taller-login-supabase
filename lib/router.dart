import 'package:go_router/go_router.dart';
import 'screens/registro.dart';
import 'screens/login.dart';
import 'screens/bienvenida.dart';
import 'screens/agendar_cita.dart';
import 'services/supabase_service.dart';

class AppRouter {
  static final GoRouter _router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/registro',
        name: 'registro',
        builder: (context, state) => const RegistroScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/bienvenida',
        name: 'bienvenida',
        builder: (context, state) => const BienvenidaScreen(),
      ),
      GoRoute(
        path: '/agendar-cita',
        name: 'agendar-cita',
        builder: (context, state) => const AgendarCitaScreen(),
      ),
    ],
    redirect: (context, state) {
      final isLoggedIn = SupabaseService.instance.isLoggedIn;
      final isLoginRoute = state.matchedLocation == '/login';
      final isRegistroRoute = state.matchedLocation == '/registro';

      // Si no está logueado y no está en login o registro, redirigir a login
      if (!isLoggedIn && !isLoginRoute && !isRegistroRoute) {
        return '/login';
      }

      // Si está logueado y está en login o registro, redirigir a bienvenida
      if (isLoggedIn && (isLoginRoute || isRegistroRoute)) {
        return '/bienvenida';
      }

      return null;
    },
  );

  static GoRouter get router => _router;
}
