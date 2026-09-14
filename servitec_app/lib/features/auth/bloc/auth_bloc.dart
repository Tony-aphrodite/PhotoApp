import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthSignInRequested>(_onSignInRequested);
    on<AuthRegisterClientRequested>(_onRegisterClientRequested);
    on<AuthRegisterTechnicianRequested>(_onRegisterTechnicianRequested);
    on<AuthSignOutRequested>(_onSignOutRequested);
    on<AuthResetPasswordRequested>(_onResetPasswordRequested);
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final firebaseUser = _authRepository.currentUser;
      if (firebaseUser != null) {
        final user = await _authRepository.getUserProfile(firebaseUser.uid);
        if (!user.activo) {
          // Suspended since the last launch. The cached Firebase session is
          // still valid, so without this check the account keeps working
          // until the token expires.
          await _authRepository.signOut();
          emit(AuthError(_suspendedMessage));
          return;
        }
        emit(AuthAuthenticated(user));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onSignInRequested(
    AuthSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await _authRepository.signIn(
        email: event.email,
        password: event.password,
      );
      if (!user.activo) {
        await _authRepository.signOut();
        emit(AuthError(_suspendedMessage));
        return;
      }
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(_mapAuthError(e)));
    }
  }

  Future<void> _onRegisterClientRequested(
    AuthRegisterClientRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await _authRepository.registerClient(
        email: event.email,
        password: event.password,
        nombre: event.nombre,
        apellido: event.apellido,
        telefono: event.telefono,
      );
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(_mapAuthError(e)));
    }
  }

  Future<void> _onRegisterTechnicianRequested(
    AuthRegisterTechnicianRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await _authRepository.registerTechnician(
        email: event.email,
        password: event.password,
        nombre: event.nombre,
        apellido: event.apellido,
        telefono: event.telefono,
        especialidades: event.especialidades,
      );
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(_mapAuthError(e)));
    }
  }

  Future<void> _onSignOutRequested(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authRepository.signOut();
    emit(AuthUnauthenticated());
  }

  Future<void> _onResetPasswordRequested(
    AuthResetPasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authRepository.resetPassword(event.email);
      emit(AuthPasswordResetSent());
    } catch (e) {
      emit(AuthError(_mapAuthError(e)));
    }
  }

  /// Shown when an admin has set `activo: false` on the account. Says who to
  /// contact rather than why, since the reason is the admin's to give.
  static const String _suspendedMessage =
      'Esta cuenta está suspendida. Contacta a ServiTec para más información.';

  /// Turns an auth failure into something the user can act on.
  ///
  /// Reads `FirebaseAuthException.code` directly rather than substring-matching
  /// `toString()`, and — critically — includes the raw code in the fallback.
  /// The previous version returned a bare "Error de autenticación" for any code
  /// it did not list, which hid the real cause during testing and left nothing
  /// to diagnose from.
  String _mapAuthError(dynamic error) {
    if (error is PhoneAlreadyInUseException) {
      return 'Este teléfono ya está registrado en otra cuenta. Inicia sesión o usa otro número.';
    }
    if (error is InvalidPhoneException) {
      return 'Ingresa un teléfono de 10 dígitos';
    }

    final code = error is FirebaseAuthException
        ? error.code
        : RegExp(r'\[firebase_auth/([a-z-]+)\]')
                .firstMatch(error.toString())
                ?.group(1) ??
            '';

    switch (code) {
      // Modern Firebase returns this for both a wrong password and an unknown
      // email, so the copy must not imply which one it was.
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Correo o contraseña incorrectos';
      case 'user-not-found':
        return 'No se encontró una cuenta con este correo';
      case 'wrong-password':
        return 'Contraseña incorrecta';
      case 'email-already-in-use':
        return 'Este correo ya está registrado. Inicia sesión o usa otro correo.';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres';
      case 'invalid-email':
        return 'Correo electrónico inválido';
      case 'user-disabled':
        return 'Esta cuenta está deshabilitada. Contacta a soporte.';
      case 'too-many-requests':
        return 'Demasiados intentos fallidos. Espera unos minutos e intenta de nuevo.';
      case 'network-request-failed':
        return 'Sin conexión. Revisa tu internet e intenta de nuevo.';
      case 'operation-not-allowed':
        return 'El registro con correo no está habilitado en el proyecto.';
      case 'permission-denied':
        return 'Tu cuenta se creó pero no se pudo guardar el perfil. Contacta a soporte.';
    }

    // Unknown: surface the code so a screenshot is enough to diagnose it.
    final detail = code.isNotEmpty ? code : error.toString();
    return 'Error de autenticación ($detail)';
  }
}
