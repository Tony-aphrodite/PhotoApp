import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/auth_repository.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';

/// Where every account without a verified email is held until it clicks the
/// link. The router sends it here and nowhere else.
///
/// Checks run from this screen against the repository rather than through the
/// bloc, because a bloc loading state would make the router bounce the user to
/// /login mid-check. Only the final "verified" is handed to the bloc.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with WidgetsBindingObserver {
  static const _resendCooldown = 60;

  bool _checking = false;
  bool _sending = false;
  int _cooldownLeft = 0;
  Timer? _cooldownTimer;

  AuthRepository get _repo => context.read<AuthRepository>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cooldownTimer?.cancel();
    super.dispose();
  }

  // The link opens in the browser or mail app. Coming back to ServiTec is the
  // natural next step, so check then — most people never need the button.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check(silent: true);
  }

  Future<void> _check({bool silent = false}) async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final verified = await _repo.reloadEmailVerified();
      if (!mounted) return;
      if (verified) {
        context.read<AuthBloc>().add(AuthEmailVerified());
      } else if (!silent) {
        _toast(
          'Todavía no aparece verificado. Abre el enlace del correo y vuelve a intentarlo.',
          error: true,
        );
      }
    } catch (_) {
      if (mounted && !silent) {
        _toast('Sin conexión. Revisa tu internet e intenta de nuevo.', error: true);
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    if (_sending || _cooldownLeft > 0) return;
    setState(() => _sending = true);
    try {
      await _repo.sendEmailVerification();
      if (!mounted) return;
      _toast('Te enviamos un nuevo enlace.');
      _startCooldown();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _toast(
        e.code == 'too-many-requests'
            ? 'Ya pediste varios correos. Espera unos minutos antes de pedir otro.'
            : 'No se pudo enviar el correo (${e.code}). Intenta de nuevo.',
        error: true,
      );
    } catch (_) {
      if (mounted) {
        _toast('Sin conexión. Revisa tu internet e intenta de nuevo.', error: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownLeft = _resendCooldown);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldownLeft--);
      if (_cooldownLeft <= 0) t.cancel();
    });
  }

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? AppTheme.errorColor : AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final email = _repo.currentEmail ?? '';
    final muted = Colors.white.withValues(alpha: 0.6);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF061A1E), Color(0xFF0A3D42), Color(0xFF0A2E36)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF0D7377), Color(0xFF14BDAC)],
                        ),
                      ),
                      child: const Icon(Icons.mark_email_unread_outlined,
                          color: Colors.white, size: 40),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Verifica tu correo',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text.rich(
                    TextSpan(
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 15, color: muted, height: 1.5),
                      children: [
                        const TextSpan(text: 'Enviamos un enlace de verificación a\n'),
                        TextSpan(
                          text: email,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const TextSpan(
                          text: '\nÁbrelo para activar tu cuenta y regresa a la app.',
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '¿No lo ves? Revisa la carpeta de spam o correo no deseado.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    height: 56,
                    child: FilledButton(
                      onPressed: _checking ? null : () => _check(),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF14BDAC),
                        disabledBackgroundColor:
                            const Color(0xFF14BDAC).withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _checking
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white),
                            )
                          : Text(
                              'Ya lo verifiqué',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed:
                          (_sending || _cooldownLeft > 0) ? null : _resend,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.2)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        _cooldownLeft > 0
                            ? 'Reenviar correo en ${_cooldownLeft}s'
                            : _sending
                                ? 'Enviando…'
                                : 'Reenviar correo',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(
                              alpha: (_sending || _cooldownLeft > 0) ? 0.4 : 0.9),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () =>
                        context.read<AuthBloc>().add(AuthSignOutRequested()),
                    child: Text(
                      'Usar otra cuenta',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.secondaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
