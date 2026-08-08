import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';

/// Optional fiscal profile for clientes. Fill this in if you want the CFDI
/// issued in your (or your company's) name; otherwise the invoice will be
/// stamped to "público en general" (RFC XAXX010101000) which is what most
/// consumers use.
///
/// This is deliberately separate from the técnico's fiscal onboarding: a
/// cliente doesn't need a CSD or régimen fiscal complexity — just RFC, razón
/// social and CP so their invoice can reach them properly.
class ClientFiscalScreen extends StatefulWidget {
  const ClientFiscalScreen({super.key});

  @override
  State<ClientFiscalScreen> createState() => _ClientFiscalScreenState();
}

class _ClientFiscalScreenState extends State<ClientFiscalScreen> {
  final _rfcController = TextEditingController();
  final _razonSocialController = TextEditingController();
  final _codigoPostalController = TextEditingController();
  String _regimenFiscal = '616'; // Sin obligaciones fiscales (default general public)
  bool _submitting = false;
  bool _loaded = false;

  static const _regimenOptions = <_Reg>[
    _Reg('616', 'Sin obligaciones fiscales (público)'),
    _Reg('612', 'Actividad Empresarial y Profesional'),
    _Reg('626', 'RESICO (Persona Física)'),
    _Reg('601', 'Régimen General (Persona Moral)'),
  ];

  @override
  void initState() {
    super.initState();
    _prefillFromCurrent();
  }

  Future<void> _prefillFromCurrent() async {
    final state = context.read<AuthBloc>().state;
    if (state is! AuthAuthenticated) return;
    final user = state.user;
    _rfcController.text = user.rfc ?? '';
    _razonSocialController.text = user.razonSocial ?? '';
    _codigoPostalController.text = user.codigoPostalFiscal ?? '';
    if (user.regimenFiscal != null) _regimenFiscal = user.regimenFiscal!;
    setState(() => _loaded = true);
  }

  bool _valid() {
    final rfc = _rfcController.text.trim().toUpperCase();
    final razon = _razonSocialController.text.trim();
    final cp = _codigoPostalController.text.trim();
    // Empty is also valid — user chose not to provide, defaults to público
    // en general. So we only validate when at least one field is populated.
    final anyFilled = rfc.isNotEmpty || razon.isNotEmpty || cp.isNotEmpty;
    if (!anyFilled) return true;
    final rfcOk = RegExp(r'^[A-ZÑ&]{3,4}\d{6}[A-Z0-9]{3}$').hasMatch(rfc);
    final razonOk = razon.length >= 3;
    final cpOk = RegExp(r'^\d{5}$').hasMatch(cp);
    return rfcOk && razonOk && cpOk;
  }

  Future<void> _save() async {
    if (!_valid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revisa los campos antes de guardar.')),
      );
      return;
    }
    final state = context.read<AuthBloc>().state;
    if (state is! AuthAuthenticated) return;
    setState(() => _submitting = true);
    try {
      final rfc = _rfcController.text.trim().toUpperCase();
      final razon = _razonSocialController.text.trim();
      final cp = _codigoPostalController.text.trim();
      final anyFilled = rfc.isNotEmpty || razon.isNotEmpty || cp.isNotEmpty;

      final update = <String, dynamic>{};
      if (anyFilled) {
        update['rfc'] = rfc;
        update['razonSocial'] = razon;
        update['regimenFiscal'] = _regimenFiscal;
        update['codigoPostalFiscal'] = cp;
      } else {
        // Explicit clear.
        update['rfc'] = FieldValue.delete();
        update['razonSocial'] = FieldValue.delete();
        update['regimenFiscal'] = FieldValue.delete();
        update['codigoPostalFiscal'] = FieldValue.delete();
      }
      await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(state.user.uid)
          .update(update);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(anyFilled
                ? 'Datos fiscales guardados.'
                : 'Datos fiscales eliminados. Tus facturas se emitirán a público en general.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _rfcController.dispose();
    _razonSocialController.dispose();
    _codigoPostalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Datos fiscales (opcional)',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                ),
              ),
              child: Text(
                'Si no llenas esta información, tus facturas se emitirán a nombre de "PÚBLICO EN GENERAL" (RFC XAXX010101000). Rellena solo si necesitas la factura a tu nombre o al de tu empresa.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  color: AppTheme.primaryColor,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _label('RFC'),
            TextField(
              controller: _rfcController,
              textCapitalization: TextCapitalization.characters,
              decoration: _dec(hint: 'XAXX010101000'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            _label('Razón social o nombre completo'),
            TextField(
              controller: _razonSocialController,
              decoration: _dec(hint: 'Como aparece en tu constancia fiscal'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            _label('Régimen fiscal'),
            DropdownButtonFormField<String>(
              value: _regimenFiscal,
              decoration: _dec(),
              items: _regimenOptions
                  .map((o) => DropdownMenuItem(
                        value: o.code,
                        child: Text('${o.code} — ${o.label}'),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _regimenFiscal = v ?? '616'),
            ),
            const SizedBox(height: 14),
            _label('Código postal fiscal'),
            TextField(
              controller: _codigoPostalController,
              keyboardType: TextInputType.number,
              decoration: _dec(hint: '00000'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 26),
            ElevatedButton(
              onPressed: _submitting ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      'Guardar',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
            letterSpacing: 0.3,
          ),
        ),
      );

  InputDecoration _dec({String? hint}) => InputDecoration(
        hintText: hint,
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
          borderSide: const BorderSide(
              color: AppTheme.primaryColor, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
}

class _Reg {
  final String code;
  final String label;
  const _Reg(this.code, this.label);
}
