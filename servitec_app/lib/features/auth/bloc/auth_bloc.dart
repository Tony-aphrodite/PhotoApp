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

  String _mapAuthError(dynamic error) {
    final message = error.toString();
    if (message.contains('user-not-found')) {
      return 'No se encontró una cuenta con este correo';
    } else if (message.contains('wrong-password')) {
      return 'Contraseña incorrecta';
    } else if (message.contains('email-already-in-use')) {
      return 'Este correo ya está registrado';
    } else if (message.contains('weak-password')) {
      return 'La contraseña es demasiado débil';
    } else if (message.contains('invalid-email')) {
      return 'Correo electrónico inválido';
    } else if (message.contains('too-many-requests')) {
      return 'Demasiados intentos. Intenta más tarde';
    }
    return 'Error de autenticación. Intenta de nuevo';
  }
}
