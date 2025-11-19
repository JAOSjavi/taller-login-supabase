import 'package:go_router/go_router.dart';
import 'screens/registro.dart';
import 'screens/login.dart';
import 'screens/bienvenida.dart';
import 'screens/agendar_cita.dart';
import 'screens/mis_citas.dart';
import 'screens/editar_cita.dart';
import 'screens/medico_panel.dart';
import 'screens/doctor_panel_screen.dart';
import 'screens/detalle_cita_medico.dart';
import 'services/supabase_service.dart';
import 'services/session_service.dart';

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
      GoRoute(
        path: '/mis-citas',
        name: 'mis-citas',
        builder: (context, state) => const MisCitasScreen(),
      ),
      GoRoute(
        path: '/editar-cita/:citaId',
        name: 'editar-cita',
        builder: (context, state) {
          final citaId = state.pathParameters['citaId']!;
          return EditarCitaScreen(citaId: citaId);
        },
      ),
      GoRoute(
        path: '/medico-panel',
        name: 'medico-panel',
        builder: (context, state) => const MedicoPanelScreen(),
      ),
      GoRoute(
        path: '/doctor-panel',
        name: 'doctor-panel',
        builder: (context, state) => const DoctorPanelScreen(),
      ),
      GoRoute(
        path: '/detalle-cita-medico/:citaId',
        name: 'detalle-cita-medico',
        builder: (context, state) {
          final citaId = state.pathParameters['citaId']!;
          return DetalleCitaMedicoScreen(citaId: citaId);
        },
      ),
    ],
    redirect: (context, state) {
      final isLoggedIn = SupabaseService.instance.isLoggedIn;
      final isSuperUser = SessionService.instance.isSuperUser;
      final location = state.matchedLocation;
      final isLoginRoute = location == '/login';
      final isRegistroRoute = location == '/registro';
      final isBienvenidaRoute = location == '/bienvenida';
      final isMedicoPanelRoute = location == '/medico-panel';

      // Si no está logueado y no está en login o registro, redirigir a login
      if (!isLoggedIn && !isLoginRoute && !isRegistroRoute) {
        return '/login';
      }

      // Si está logueado y está en login o registro, redirigir a bienvenida
      if (isLoggedIn && (isLoginRoute || isRegistroRoute)) {
        return isSuperUser ? '/medico-panel' : '/bienvenida';
      }

      // Forzar ruta del panel del médico si es superusuario
      if (isLoggedIn && isSuperUser && !isMedicoPanelRoute && isBienvenidaRoute) {
        return '/medico-panel';
      }

      return null;
    },
  );

  static GoRouter get router => _router;
}
