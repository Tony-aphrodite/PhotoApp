import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_constants.dart';
import '../theme/app_theme.dart';

/// One-time modal shown on first authenticated launch that explains the
/// off-platform rules the user is agreeing to.
///
/// Mount via [maybeShow] from a top-level widget (e.g. AppShell) so it fires
/// once per user. Acceptance is persisted on the user document as
/// `disclosureAcceptedAt`, so it never appears again on any device.
class OnboardingDisclosureDialog extends StatelessWidget {
  const OnboardingDisclosureDialog({super.key});

  /// Shows the dialog if [alreadyAccepted] is false. Writes the acceptance
  /// timestamp to Firestore on tap. Idempotent — safe to call every rebuild.
  static Future<void> maybeShow({
    required BuildContext context,
    required String uid,
    required bool alreadyAccepted,
  }) async {
    if (alreadyAccepted) return;
    // Defer to post-frame so we don't try to open a route mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!context.mounted) return;
      final accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const OnboardingDisclosureDialog(),
      );
      if (accepted == true) {
        await FirebaseFirestore.instance
            .collection(AppConstants.usersCollection)
            .doc(uid)
            .update({'disclosureAcceptedAt': Timestamp.now()});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_outlined,
                        color: AppTheme.primaryColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Antes de empezar',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _bullet(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Comunicación dentro de ServiTec',
                body:
                    'Toda coordinación con el técnico o cliente debe hacerse en el chat de la app. Esto nos permite darte soporte y proteger tus datos.',
              ),
              const SizedBox(height: 14),
              _bullet(
                icon: Icons.credit_card_outlined,
                title: 'Pagos y facturación por la plataforma',
                body:
                    'Los pagos se procesan por Stripe dentro de la app; el CFDI se emite automáticamente. Los acuerdos fuera de ServiTec no son válidos.',
              ),
              const SizedBox(height: 14),
              _bullet(
                icon: Icons.warning_amber_rounded,
                title: 'Sin cobertura fuera de la app',
                body:
                    'Los trabajos gestionados fuera de la plataforma no cuentan con garantía, soporte ni seguro. Podrían ocasionar la suspensión de la cuenta.',
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Entendido y acepto',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bullet({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
