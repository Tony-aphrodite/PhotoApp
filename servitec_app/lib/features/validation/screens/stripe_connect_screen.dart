import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';

/// Técnico-facing screen to link their Stripe Connect account.
///
/// A técnico can't receive payouts until they've completed Stripe's KYC +
/// bank account flow. This screen calls the
/// `createTechnicianConnectOnboardingLink` Cloud Function, which lazily
/// provisions a Stripe Connect Standard account on first call and returns a
/// short-lived Stripe-hosted onboarding URL. We launch that URL in the
/// external browser; Stripe redirects the técnico back to the app when done.
class StripeConnectScreen extends StatefulWidget {
  const StripeConnectScreen({super.key});

  @override
  State<StripeConnectScreen> createState() => _StripeConnectScreenState();
}

class _StripeConnectScreenState extends State<StripeConnectScreen> {
  bool _loading = true;
  bool _launching = false;
  String? _error;

  // Status returned by getTechnicianConnectStatus:
  //   'not_started' | 'incomplete' | 'active'
  String _status = 'not_started';
  bool _chargesEnabled = false;
  bool _payoutsEnabled = false;
  List<String> _requirementsDue = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await FirebaseFunctions.instance
          .httpsCallable('getTechnicianConnectStatus')
          .call<Map<String, dynamic>>();
      final data = Map<String, dynamic>.from(res.data);
      setState(() {
        _status = data['status'] as String? ?? 'not_started';
        _chargesEnabled = data['chargesEnabled'] as bool? ?? false;
        _payoutsEnabled = data['payoutsEnabled'] as bool? ?? false;
        _requirementsDue = (data['requirementsCurrentlyDue'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [];
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startOnboarding() async {
    setState(() {
      _launching = true;
      _error = null;
    });
    try {
      final res = await FirebaseFunctions.instance
          .httpsCallable('createTechnicianConnectOnboardingLink')
          .call<Map<String, dynamic>>();
      final url = res.data['url'] as String?;
      if (url == null) throw Exception('URL vacía');
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) throw Exception('No se pudo abrir el navegador');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Cuenta bancaria (Stripe)',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatusCard(
                status: _status,
                chargesEnabled: _chargesEnabled,
                payoutsEnabled: _payoutsEnabled,
                requirementsDue: _requirementsDue,
                loading: _loading,
              ),
              const SizedBox(height: 20),
              _explanation(),
              const SizedBox(height: 24),
              _ctaButton(),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.errorColor,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _explanation() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿Por qué es necesario?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Para recibir el pago de tus servicios necesitas tener una cuenta bancaria enlazada. '
            'Stripe (nuestro procesador de pagos) hará una verificación breve de identidad y '
            'te pedirá tu CLABE. Después de completarla podrás cobrar automáticamente cada servicio.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'ServiTec nunca ve tus datos bancarios. Los guarda Stripe directamente.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppTheme.textTertiary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ctaButton() {
    final label = switch (_status) {
      'active' => 'Actualizar información bancaria',
      'incomplete' => 'Continuar configuración',
      _ => 'Enlazar cuenta bancaria',
    };
    return ElevatedButton(
      onPressed: _launching ? null : _startOnboarding,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _launching
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : Text(label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              )),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String status;
  final bool chargesEnabled;
  final bool payoutsEnabled;
  final List<String> requirementsDue;
  final bool loading;

  const _StatusCard({
    required this.status,
    required this.chargesEnabled,
    required this.payoutsEnabled,
    required this.requirementsDue,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final (color, icon, label, message) = switch (status) {
      'active' => (
          AppTheme.successColor,
          Icons.check_circle_outline_rounded,
          'Activa',
          'Puedes recibir pagos y payouts automáticos.',
        ),
      'incomplete' => (
          AppTheme.warningColor,
          Icons.info_outline_rounded,
          'Incompleta',
          'Faltan datos por completar. Continúa la configuración para poder cobrar.',
        ),
      _ => (
          AppTheme.textTertiary,
          Icons.link_off_rounded,
          'Sin enlazar',
          'Enlaza tu cuenta bancaria con Stripe para empezar a cobrar servicios.',
        ),
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              if (loading) ...[
                const Spacer(),
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: color),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppTheme.textPrimary,
              height: 1.4,
            ),
          ),
          if (status == 'incomplete' && requirementsDue.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Pendiente: ${requirementsDue.take(3).join(", ")}${requirementsDue.length > 3 ? "…" : ""}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
