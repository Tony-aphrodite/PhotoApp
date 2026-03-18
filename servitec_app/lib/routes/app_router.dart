import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/widgets/app_shell.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/bloc/auth_state.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/client/screens/client_home_screen.dart';
import '../features/client/screens/client_services_screen.dart';
import '../features/client/screens/create_service_screen.dart';
import '../features/technician/screens/technician_home_screen.dart';
import '../features/admin/screens/admin_home_screen.dart';
import '../features/admin/screens/admin_technicians_screen.dart';
import '../features/admin/screens/assign_technician_screen.dart';
import '../features/admin/screens/admin_tariffs_screen.dart';
import '../features/payment/screens/payment_screen.dart';
import '../features/earnings/screens/technician_earnings_screen.dart';
import '../features/earnings/screens/admin_finance_screen.dart';
import '../features/service/screens/review_screen.dart';
import '../features/diagnostic/screens/create_quotation_screen.dart';
import '../features/diagnostic/screens/review_quotation_screen.dart';
import '../features/validation/screens/technician_documents_screen.dart';
import '../features/validation/screens/admin_validation_screen.dart';
import '../features/appointment/screens/book_appointment_screen.dart';
import '../features/service/screens/service_detail_screen.dart';
import '../features/chat/screens/chat_screen.dart';
import '../features/profile/screens/profile_screen.dart';

class AppRouter {
  final AuthBloc authBloc;

  AppRouter({required this.authBloc});

  late final GoRouter router = GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: (context, state) {
      final authState = authBloc.state;
      final isLoggedIn = authState is AuthAuthenticated;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/forgot-password';

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) {
        final user = authState.user;
        if (user.isClient) return '/client';
        if (user.isTechnician) return '/technician';
        if (user.isAdmin) return '/admin';
      }
      return null;
    },
    routes: [
      // Auth routes
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // Client shell
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/client',
                builder: (context, state) => const ClientHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/client/services',
                builder: (context, state) => const ClientServicesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/client/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // Technician shell
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/technician',
                builder: (context, state) => const TechnicianHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/technician/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // Admin shell
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin',
                builder: (context, state) => const AdminHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/technicians',
                builder: (context, state) => const AdminTechniciansScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // Shared routes
      GoRoute(
        path: '/client/create-service',
        builder: (context, state) => CreateServiceScreen(
          initialCategory: state.extra as String?,
        ),
      ),
      GoRoute(
        path: '/service/:id',
        builder: (context, state) => ServiceDetailScreen(
          serviceId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/client/service/:id',
        builder: (context, state) => ServiceDetailScreen(
          serviceId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/chat/:serviceId',
        builder: (context, state) => ChatScreen(
          serviceId: state.pathParameters['serviceId']!,
        ),
      ),
      GoRoute(
        path: '/admin/assign/:serviceId',
        builder: (context, state) => AssignTechnicianScreen(
          serviceId: state.pathParameters['serviceId']!,
        ),
      ),
      GoRoute(
        path: '/admin/tariffs',
        builder: (context, state) => const AdminTariffsScreen(),
      ),
      GoRoute(
        path: '/admin/finance',
        builder: (context, state) => const AdminFinanceScreen(),
      ),
      GoRoute(
        path: '/payment/:serviceId',
        builder: (context, state) => PaymentScreen(
          serviceId: state.pathParameters['serviceId']!,
        ),
      ),
      GoRoute(
        path: '/review/:serviceId',
        builder: (context, state) => ReviewScreen(
          serviceId: state.pathParameters['serviceId']!,
        ),
      ),
      GoRoute(
        path: '/technician/earnings',
        builder: (context, state) => const TechnicianEarningsScreen(),
      ),
      GoRoute(
        path: '/technician/documents',
        builder: (context, state) => const TechnicianDocumentsScreen(),
      ),
      GoRoute(
        path: '/quotation/create/:serviceId',
        builder: (context, state) => CreateQuotationScreen(
          serviceId: state.pathParameters['serviceId']!,
        ),
      ),
      GoRoute(
        path: '/quotation/review/:quotationId',
        builder: (context, state) => ReviewQuotationScreen(
          quotationId: state.pathParameters['quotationId']!,
        ),
      ),
      GoRoute(
        path: '/admin/validation',
        builder: (context, state) => const AdminValidationScreen(),
      ),
      GoRoute(
        path: '/appointment/:serviceId/:technicianId',
        builder: (context, state) => BookAppointmentScreen(
          serviceId: state.pathParameters['serviceId']!,
          technicianId: state.pathParameters['technicianId']!,
        ),
      ),
    ],
  );
}

// Helper to convert stream to listenable for GoRouter
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    stream.listen((_) => notifyListeners());
  }
}
