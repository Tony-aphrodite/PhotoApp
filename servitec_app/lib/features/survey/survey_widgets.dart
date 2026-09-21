import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/tester_identity.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/survey_repository.dart';

/// "Encuesta de prueba" on the profile screen. Shows only while the admin has
/// configured a survey link, and never for admins themselves.
class SurveyButton extends StatelessWidget {
  final UserModel user;

  const SurveyButton({super.key, required this.user});

  Future<void> _open(BuildContext context, String template) async {
    final info = await PackageInfo.fromPlatform();
    final uri = SurveyRepository.buildUri(
      template,
      codigo: TesterIdentity.codeFor(user.uid),
      rol: user.isTechnician ? 'tecnico' : 'cliente',
      version: '${info.version}+${info.buildNumber}',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No se pudo abrir la encuesta. Intenta de nuevo.'),
        backgroundColor: AppTheme.errorColor,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user.isAdmin) return const SizedBox.shrink();
    return StreamBuilder<String?>(
      stream: context.read<SurveyRepository>().watchLink(),
      builder: (context, snap) {
        final link = snap.data;
        if (link == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Material(
            color: AppTheme.primaryColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              onTap: () => _open(context, link),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.rate_review_outlined,
                        color: AppTheme.primaryColor),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Encuesta de prueba',
                              style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary)),
                          const SizedBox(height: 2),
                          Text(
                            'Cuéntanos cómo te fue probando ServiTec. Toma unos minutos.',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.open_in_new_rounded,
                        size: 18, color: AppTheme.textTertiary),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Admin dialog to paste, replace or remove the survey link.
Future<void> configureSurveyLink(BuildContext context) async {
  final repo = context.read<SurveyRepository>();
  final current = await repo.watchLink().first;
  if (!context.mounted) return;
  final controller = TextEditingController(text: current ?? '');
  final formKey = GlobalKey<FormState>();

  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Encuesta de prueba',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'En Google Forms, abre ⋮ → "Obtener enlace prellenado" y escribe '
                'CODIGO, ROL y VERSION en las tres preguntas de datos. Pega aquí '
                'el enlace que genera. Déjalo vacío para ocultar el botón.',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, height: 1.5, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: controller,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'https://docs.google.com/forms/…',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return null;
                  return SurveyRepository.isValidTemplate(t)
                      ? null
                      : 'El enlace debe ser de Google Forms e incluir CODIGO, ROL y VERSION';
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.pop(ctx, controller.text.trim());
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
  if (result == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await repo.saveLink(result);
    messenger.showSnackBar(SnackBar(
      content: Text(result.isEmpty
          ? 'Encuesta desactivada.'
          : 'Encuesta guardada. Los testers ya ven el botón en su perfil.'),
      backgroundColor: AppTheme.successColor,
    ));
  } catch (e) {
    messenger.showSnackBar(SnackBar(
      content: Text('No se pudo guardar: $e'),
      backgroundColor: AppTheme.errorColor,
    ));
  }
}
