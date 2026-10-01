import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/tester_identity.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/survey_repository.dart';
import '../../firebase_options.dart';

/// "Encuesta de prueba" on the profile screen. Shows only while the admin has
/// configured a survey link, and never for admins themselves.
class SurveyButton extends StatelessWidget {
  final UserModel user;

  const SurveyButton({super.key, required this.user});

  String get _rol =>
      user.isTechnician ? SurveyRepository.rolTecnico : SurveyRepository.rolCliente;

  Future<void> _open(BuildContext context, String template) async {
    final info = await PackageInfo.fromPlatform();
    final uri = SurveyRepository.buildUri(
      template,
      codigo: TesterIdentity.codeFor(user.uid),
      rol: _rol,
      version: '${info.version}+${info.buildNumber}',
      // Which build the answer came from: the test-server APK or the one on
      // the production backend. Same code and version otherwise.
      origen: isDevBuild ? 'app-android-pruebas' : 'app-android',
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
      stream: context.read<SurveyRepository>().watchLink(_rol),
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

/// Admin dialog to paste, replace or remove the two survey links.
Future<void> configureSurveyLink(BuildContext context) async {
  final repo = context.read<SurveyRepository>();
  final current = await repo.fetchLinks();
  if (!context.mounted) return;
  final cliente = TextEditingController(text: current.cliente);
  final tecnico = TextEditingController(text: current.tecnico);
  final formKey = GlobalKey<FormState>();

  String? validate(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    return SurveyRepository.isValidLink(t) ? null : 'Debe ser un enlace de Google Forms';
  }

  Widget field(String label, TextEditingController c) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: TextFormField(
          controller: c,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: label,
            hintText: 'https://docs.google.com/forms/…',
            border: const OutlineInputBorder(),
          ),
          validator: validate,
        ),
      );

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Encuestas de prueba',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cada rol ve solo su encuesta en el perfil. Deja un campo vacío '
                'para ocultar ese botón.\n\nPara saber quién respondió y con qué '
                'versión: en Google Forms abre ⋮ → "Obtener enlace prellenado", '
                'escribe CODIGO, ROL, VERSION y ORIGEN en las preguntas de uso interno '
                'y pega aquí ese enlace. La app los reemplaza por el código del '
                'tester (nunca su correo), su rol, la versión y desde qué app respondió.',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, height: 1.5, color: AppTheme.textSecondary),
              ),
              field('Encuesta para clientes', cliente),
              field('Encuesta para técnicos', tecnico),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () {
            if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
  if (saved != true || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await repo.saveLinks(cliente: cliente.text, tecnico: tecnico.text);
    final sinCodigo = [cliente.text, tecnico.text]
        .where((l) => l.trim().isNotEmpty && !SurveyRepository.hasPlaceholders(l))
        .isNotEmpty;
    messenger.showSnackBar(SnackBar(
      content: Text(sinCodigo
          ? 'Encuestas guardadas. Aviso: sin CODIGO, ROL y VERSION no se podrá saber qué tester respondió.'
          : 'Encuestas guardadas. Los testers ya ven el botón en su perfil.'),
      backgroundColor: AppTheme.successColor,
    ));
  } catch (e) {
    messenger.showSnackBar(SnackBar(
      content: Text('No se pudo guardar: $e'),
      backgroundColor: AppTheme.errorColor,
    ));
  }
}
