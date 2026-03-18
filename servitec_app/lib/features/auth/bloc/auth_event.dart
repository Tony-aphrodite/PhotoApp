import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class AuthSignInRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthSignInRequested({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class AuthRegisterClientRequested extends AuthEvent {
  final String email;
  final String password;
  final String nombre;
  final String apellido;
  final String telefono;

  const AuthRegisterClientRequested({
    required this.email,
    required this.password,
    required this.nombre,
    required this.apellido,
    required this.telefono,
  });

  @override
  List<Object?> get props => [email, password, nombre, apellido, telefono];
}

class AuthRegisterTechnicianRequested extends AuthEvent {
  final String email;
  final String password;
  final String nombre;
  final String apellido;
  final String telefono;
  final List<String> especialidades;

  const AuthRegisterTechnicianRequested({
    required this.email,
    required this.password,
    required this.nombre,
    required this.apellido,
    required this.telefono,
    required this.especialidades,
  });

  @override
  List<Object?> get props => [email, password, nombre, apellido, telefono, especialidades];
}

class AuthSignOutRequested extends AuthEvent {}

class AuthResetPasswordRequested extends AuthEvent {
  final String email;

  const AuthResetPasswordRequested({required this.email});

  @override
  List<Object?> get props => [email];
}
