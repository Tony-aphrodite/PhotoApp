import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/services/tester_identity.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/service_repository.dart';
import 'data/repositories/user_repository.dart';
import 'data/repositories/storage_repository.dart';
import 'data/repositories/config_repository.dart';
import 'core/utils/category_catalog.dart';
import 'data/repositories/admin_flag_repository.dart';
import 'data/repositories/category_repository.dart';
import 'data/repositories/factura_repository.dart';
import 'data/repositories/payment_repository.dart';
import 'data/repositories/review_repository.dart';
import 'data/repositories/account_admin_repository.dart';
import 'data/repositories/survey_repository.dart';
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

  // Crash reporting. Flutter framework errors and uncaught async errors both
  // go to Crashlytics, so a tester who hits a crash does not have to describe
  // it. Disabled in debug builds to keep development crashes out of the
  // user-test dashboard.
  await FirebaseCrashlytics.instance
      .setCrashlyticsCollectionEnabled(!kDebugMode);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  // Tag reports with the tester code, never the email (see TesterIdentity).
  FirebaseAuth.instance.authStateChanges().listen((user) {
    FirebaseCrashlytics.instance.setUserIdentifier(
        user == null ? '' : TesterIdentity.codeFor(user.uid));
  });

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
    final adminFlagRepository = AdminFlagRepository();
    final reviewRepository = ReviewRepository();
    final categoryRepository = CategoryRepository();
    final accountAdminRepository = AccountAdminRepository();
    final surveyRepository = SurveyRepository();
    // Live lookup table every category picker reads. Starts from the
    // hardcoded defaults so the first frame is never empty.
    CategoryCatalog.start(categoryRepository);

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
        RepositoryProvider.value(value: adminFlagRepository),
        RepositoryProvider.value(value: reviewRepository),
        RepositoryProvider.value(value: categoryRepository),
        RepositoryProvider.value(value: accountAdminRepository),
        RepositoryProvider.value(value: surveyRepository),
      ],
      child: BlocProvider.value(
        value: authBloc,
        child: MaterialApp.router(
          title: 'ServiTec',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          // Pinned to light. Every screen hardcodes white surfaces and
          // near-black text (AppTheme.textPrimary), so on a phone set to dark
          // mode the system theme rendered dark text on dark panels — the
          // disclosure modal and the photo picker sheet were unreadable.
          // Revisit only if the screens are reworked to be theme-aware.
          themeMode: ThemeMode.light,
          routerConfig: appRouter.router,
        ),
      ),
    );
  }
}
