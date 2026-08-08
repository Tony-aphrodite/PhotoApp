import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';

/// Multi-step wizard where a técnico provides their fiscal identity (RFC,
/// razón social, régimen, CP) and uploads their CSD (.cer/.key + password).
///
/// The CSD bytes are held in memory ONLY. On submit they will be forwarded to
/// a Cloud Function that uploads them to FacturAPI (creating a per-técnico
/// organization) — nothing sensitive is persisted in Firestore or Storage.
///
/// TODO(phase2-cloud-fns): wire the submit path to the
/// `setupTechnicianFiscal` HTTPS callable once functions/ is deployed. Until
/// then, we save the non-sensitive identity fields to the user document and
/// keep the CSD bytes local so the tester can walk the flow end-to-end.
class FiscalOnboardingScreen extends StatefulWidget {
  const FiscalOnboardingScreen({super.key});

  @override
  State<FiscalOnboardingScreen> createState() => _FiscalOnboardingScreenState();
}

class _FiscalOnboardingScreenState extends State<FiscalOnboardingScreen> {
  final _pageController = PageController();
  int _step = 0;

  // Step 1: fiscal identity
  final _rfcController = TextEditingController();
  final _razonSocialController = TextEditingController();
  final _codigoPostalController = TextEditingController();
  String _regimenFiscal = '626'; // RESICO by default

  // Step 2: CSD
  Uint8List? _cerBytes;
  String? _cerFileName;
  Uint8List? _keyBytes;
  String? _keyFileName;
  final _csdPasswordController = TextEditingController();

  bool _submitting = false;

  static const _regimenOptions = <_RegimenOption>[
    _RegimenOption('626', 'RESICO (Persona Física)'),
    _RegimenOption('612', 'Actividad Empresarial y Profesional'),
    _RegimenOption('621', 'Incorporación Fiscal'),
    _RegimenOption('601', 'Régimen General (Persona Moral)'),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _rfcController.dispose();
    _razonSocialController.dispose();
    _codigoPostalController.dispose();
    _csdPasswordController.dispose();
    super.dispose();
  }

  bool _step1Valid() {
    final rfc = _rfcController.text.trim().toUpperCase();
    // Basic RFC validation: 12 (moral) or 13 (física) alphanumerics.
    final rfcOk = RegExp(r'^[A-ZÑ&]{3,4}\d{6}[A-Z0-9]{3}$').hasMatch(rfc);
    final razonOk = _razonSocialController.text.trim().length >= 3;
    final cpOk = RegExp(r'^\d{5}$').hasMatch(_codigoPostalController.text.trim());
    return rfcOk && razonOk && cpOk;
  }

  bool _step2Valid() {
    return _cerBytes != null &&
        _keyBytes != null &&
        _csdPasswordController.text.isNotEmpty;
  }

  Future<void> _pickFile({required bool isCer}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [isCer ? 'cer' : 'key'],
      withData: true, // load bytes into memory (no on-disk copy needed)
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null) return;
    setState(() {
      if (isCer) {
        _cerBytes = file.bytes;
        _cerFileName = file.name;
      } else {
        _keyBytes = file.bytes;
        _keyFileName = file.name;
      }
    });
  }

  void _next() {
    if (_step == 0 && !_step1Valid()) {
      _snack('Revisa que RFC, razón social y CP estén completos.');
      return;
    }
    if (_step == 1 && !_step2Valid()) {
      _snack('Sube ambos archivos (.cer y .key) y captura la contraseña.');
      return;
    }
    if (_step >= 2) return;
    setState(() => _step++);
    _pageController.animateToPage(
      _step,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step--);
    _pageController.animateToPage(
      _step,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.errorColor),
    );
  }

  Future<void> _submit() async {
    if (!_step1Valid() || !_step2Valid()) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;
    final user = authState.user;

    setState(() => _submitting = true);
    try {
      // 1) Persist non-sensitive fiscal identity fields to the user document.
      //    Rules permit this update for the técnico themselves.
      await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .update({
        'rfc': _rfcController.text.trim().toUpperCase(),
        'razonSocial': _razonSocialController.text.trim(),
        'regimenFiscal': _regimenFiscal,
        'codigoPostalFiscal': _codigoPostalController.text.trim(),
      });

      // 2) Forward CSD bytes + password to the setupTechnicianFiscal Cloud
      //    Function. It uploads the CSD to FacturAPI (creating the técnico's
      //    per-organization credentials) and updates facturapi.organizationId
      //    + status='active' on the user document via the admin SDK. Nothing
      //    sensitive is ever persisted client-side.
      final callable = FirebaseFunctions.instance
          .httpsCallable('setupTechnicianFiscal');
      await callable.call<Map<String, dynamic>>({
        'rfc': _rfcController.text.trim().toUpperCase(),
        'razonSocial': _razonSocialController.text.trim(),
        'regimenFiscal': _regimenFiscal,
        'codigoPostalFiscal': _codigoPostalController.text.trim(),
        'cerBase64': base64Encode(_cerBytes!),
        'keyBase64': base64Encode(_keyBytes!),
        'csdPassword': _csdPasswordController.text,
      });

      // 3) Wipe the CSD bytes from memory ASAP.
      setState(() {
        _cerBytes = null;
        _keyBytes = null;
        _csdPasswordController.clear();
      });

      // Analytics — technician completed the fiscal onboarding step.
      await AnalyticsService.logFiscalOnboardingCompleted(
        regimenFiscal: _regimenFiscal,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Datos fiscales enviados. Tu organization en FacturAPI está lista.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        context.pop();
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) _snack('Error del backend: ${e.message ?? e.code}');
    } catch (e) {
      if (mounted) _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
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
          'Datos fiscales',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          _StepIndicator(current: _step, total: 3),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStepIdentity(),
                _buildStepCsd(),
                _buildStepReview(),
              ],
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  // ---------- Step 1: Identidad Fiscal ----------
  Widget _buildStepIdentity() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('Identidad Fiscal',
              subtitle:
                  'Con estos datos generaremos tus facturas ante el SAT.'),
          const SizedBox(height: 16),
          _LabeledField(
            label: 'RFC',
            child: TextField(
              controller: _rfcController,
              textCapitalization: TextCapitalization.characters,
              decoration:
                  _dec(hint: 'XAXX010101000', helper: '12 o 13 caracteres'),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 14),
          _LabeledField(
            label: 'Razón social o nombre completo',
            child: TextField(
              controller: _razonSocialController,
              decoration: _dec(hint: 'Como aparece en tu constancia fiscal'),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 14),
          _LabeledField(
            label: 'Régimen fiscal',
            child: DropdownButtonFormField<String>(
              value: _regimenFiscal,
              decoration: _dec(),
              items: _regimenOptions
                  .map((o) => DropdownMenuItem(
                        value: o.code,
                        child: Text('${o.code} — ${o.label}'),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _regimenFiscal = v ?? '626'),
            ),
          ),
          const SizedBox(height: 14),
          _LabeledField(
            label: 'Código postal fiscal',
            child: TextField(
              controller: _codigoPostalController,
              keyboardType: TextInputType.number,
              decoration: _dec(hint: '00000', helper: '5 dígitos'),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Step 2: CSD ----------
  Widget _buildStepCsd() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('Certificado de Sello Digital (CSD)',
              subtitle:
                  'Sube tu .cer y .key con la contraseña del certificado. '
                  'Los archivos se envían directo a FacturAPI y nunca se '
                  'guardan en nuestros servidores.'),
          const SizedBox(height: 16),
          _FilePickerTile(
            label: 'Archivo .cer',
            fileName: _cerFileName,
            onPick: () => _pickFile(isCer: true),
            icon: Icons.description_outlined,
          ),
          const SizedBox(height: 12),
          _FilePickerTile(
            label: 'Archivo .key',
            fileName: _keyFileName,
            onPick: () => _pickFile(isCer: false),
            icon: Icons.key_outlined,
          ),
          const SizedBox(height: 14),
          _LabeledField(
            label: 'Contraseña del CSD',
            child: TextField(
              controller: _csdPasswordController,
              obscureText: true,
              decoration: _dec(hint: 'La contraseña que asignaste ante el SAT'),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Step 3: Review ----------
  Widget _buildStepReview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('Revisión',
              subtitle: 'Verifica antes de enviar.'),
          const SizedBox(height: 16),
          _ReviewCard(items: [
            _ReviewRow('RFC', _rfcController.text.trim().toUpperCase()),
            _ReviewRow('Razón social', _razonSocialController.text.trim()),
            _ReviewRow('Régimen fiscal',
                '$_regimenFiscal — ${_regimenLabel(_regimenFiscal)}'),
            _ReviewRow('Código postal', _codigoPostalController.text.trim()),
            _ReviewRow('Archivo .cer', _cerFileName ?? '—'),
            _ReviewRow('Archivo .key', _keyFileName ?? '—'),
            _ReviewRow('Contraseña CSD',
                _csdPasswordController.text.isEmpty ? '—' : '••••••'),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined,
                    size: 18, color: AppTheme.primaryColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'El .cer, .key y la contraseña se envían directamente a FacturAPI. '
                    'No se guardan en ServiTec.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_step > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _submitting ? null : _back,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Atrás'),
              ),
            ),
          if (_step > 0) const SizedBox(width: 12),
          Expanded(
            flex: _step == 0 ? 1 : 1,
            child: ElevatedButton(
              onPressed: _submitting
                  ? null
                  : (_step == 2 ? _submit : _next),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_step == 2 ? 'Enviar' : 'Siguiente'),
            ),
          ),
        ],
      ),
    );
  }

  String _regimenLabel(String code) {
    return _regimenOptions
        .firstWhere((o) => o.code == code,
            orElse: () => const _RegimenOption('', ''))
        .label;
  }

  InputDecoration _dec({String? hint, String? helper}) => InputDecoration(
        hintText: hint,
        helperText: helper,
        isDense: true,
        filled: true,
        fillColor: AppTheme.backgroundLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
}

class _RegimenOption {
  final String code;
  final String label;
  const _RegimenOption(this.code, this.label);
}

class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;
  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: List.generate(total, (i) {
          final active = i <= current;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
              height: 4,
              decoration: BoxDecoration(
                color: active
                    ? AppTheme.primaryColor
                    : AppTheme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SectionTitle(this.title, {this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _FilePickerTile extends StatelessWidget {
  final String label;
  final String? fileName;
  final VoidCallback onPick;
  final IconData icon;
  const _FilePickerTile({
    required this.label,
    required this.fileName,
    required this.onPick,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final picked = fileName != null;
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: picked
              ? AppTheme.successColor.withValues(alpha: 0.06)
              : AppTheme.backgroundLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: picked
                ? AppTheme.successColor.withValues(alpha: 0.25)
                : AppTheme.dividerColor,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (picked
                        ? AppTheme.successColor
                        : AppTheme.primaryColor)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                picked ? Icons.check_circle_outline : icon,
                size: 20,
                color: picked
                    ? AppTheme.successColor
                    : AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fileName ?? 'Toca para seleccionar',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.upload_file_outlined,
                size: 18, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final List<_ReviewRow> items;
  const _ReviewCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: List.generate(items.length, (i) {
          final r = items[i];
          return Padding(
            padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 130,
                  child: Text(
                    r.label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppTheme.textTertiary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    r.value.isEmpty ? '—' : r.value,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _ReviewRow {
  final String label;
  final String value;
  _ReviewRow(this.label, this.value);
}
