import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/service_repository.dart';
import 'data/repositories/user_repository.dart';
import 'data/repositories/storage_repository.dart';
import 'data/repositories/config_repository.dart';
import 'data/repositories/factura_repository.dart';
import 'data/repositories/payment_repository.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/bloc/auth_event.dart';
import 'core/utils/notification_service.dart';
import 'routes/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Stripe.
  //
  // The default is the ServiTec sandbox publishable key. Publishable keys are
  // designed to ship inside client apps — they can only create payment methods
  // and confirm intents the server already authorised, never move money or read
  // account data. The secret key lives only in Cloud Functions.
  //
  // Override for a live build without touching this file:
  //   flutter build apk --release --dart-define=STRIPE_PUBLISHABLE_KEY=pk_live_...
  Stripe.publishableKey = const String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue:
        'pk_test_51TnonGCYw4D3Tylpflzd5RglJjdk7HHyIJB6nPR8ISRotCND5u4pxRor8RclceKE1z73DTWJfXKREQnhrFtyuSHq00SSczPkV9',
  );

  // Initialize notifications
  await NotificationService().initialize();

  // Set system UI
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ServiTecApp());
}

class ServiTecApp extends StatelessWidget {
  const ServiTecApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Create repositories
    final authRepository = AuthRepository();
    final serviceRepository = ServiceRepository();
    final userRepository = UserRepository();
    final storageRepository = StorageRepository();
    final configRepository = ConfigRepository();
    final paymentRepository = PaymentRepository();
    final facturaRepository = FacturaRepository();

    // Create auth bloc
    final authBloc = AuthBloc(authRepository: authRepository)
      ..add(AuthCheckRequested());

    // Create router
    final appRouter = AppRouter(authBloc: authBloc);

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider.value(value: serviceRepository),
        RepositoryProvider.value(value: userRepository),
        RepositoryProvider.value(value: storageRepository),
        RepositoryProvider.value(value: configRepository),
        RepositoryProvider.value(value: paymentRepository),
        RepositoryProvider.value(value: facturaRepository),
      ],
      child: BlocProvider.value(
        value: authBloc,
        child: MaterialApp.router(
          title: 'ServiTec',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.system,
          routerConfig: appRouter.router,
        ),
      ),
    );
  }
}
