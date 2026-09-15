import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/service_model.dart';
import '../../../data/models/work_stop.dart';
import '../../../data/repositories/service_flow_repository.dart';
import '../../../data/repositories/service_repository.dart';
import '../../../data/repositories/storage_repository.dart';

/// The técnico stops a job that cannot be finished safely or correctly.
///
/// Evidence is required — reason, explanation, at least one photo — because
/// the cliente may dispute the amount and an admin will judge from what is
/// recorded here. The amount is for work actually done and can never exceed
/// what the cliente already approved.
class StopWorkScreen extends StatefulWidget {
  final String serviceId;

  const StopWorkScreen({super.key, required this.serviceId});

  @override
  State<StopWorkScreen> createState() => _StopWorkScreenState();
}

class _StopWorkScreenState extends State<StopWorkScreen> {
  static const _maxPhotos = 5;

  final _formKey = GlobalKey<FormState>();
  final _descripcion = TextEditingController();
  final _monto = TextEditingController();
  final _picker = ImagePicker();
  final List<File> _photos = [];

  String? _motivo;
  bool _submitting = false;
  ServiceModel? _service;

  @override
  void initState() {
    super.initState();
    context.read<ServiceRepository>().getService(widget.serviceId).then((s) {
      if (mounted) setState(() => _service = s);
    });
  }

  @override
  void dispose() {
    _descripcion.dispose();
    _monto.dispose();
    super.dispose();
  }

  double get _approved => _service?.costoFinal ?? 0;

  Future<void> _addPhoto(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 90,
    );
    if (picked != null && mounted) {
      setState(() => _photos.add(File(picked.path)));
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Agrega al menos una foto como evidencia.'),
        backgroundColor: AppTheme.errorColor,
      ));
      return;
    }
    final monto = double.parse(_monto.text.replaceAll(',', ''));

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Detener el trabajo',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        content: Text(
          'El cliente recibirá el motivo, las fotos y tu propuesta de cobrar '
          '${CurrencyFormatter.format(monto)}. Si no está de acuerdo, ServiTec '
          'revisará el caso y definirá el monto final.',
          style: GoogleFonts.plusJakartaSans(height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Volver')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Detener', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final images = await context
          .read<StorageRepository>()
          .uploadServicePhotos('${widget.serviceId}_detencion', _photos);
      if (!mounted) return;
      await context.read<ServiceFlowRepository>().stopWork(
            servicioId: widget.serviceId,
            motivo: _motivo!,
            descripcion: _descripcion.text.trim(),
            fotos: images.map((i) => i.url).toList(),
            montoPropuesto: monto,
          );
      messenger.showSnackBar(const SnackBar(
        content: Text('Trabajo detenido. Le avisamos al cliente.'),
        backgroundColor: AppTheme.successColor,
      ));
      if (mounted) context.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(e is FlowException ? e.message : 'Error: $e'),
        backgroundColor: AppTheme.errorColor,
      ));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  InputDecoration _decoration(String label, {String? helper, String? prefix}) =>
      InputDecoration(
        labelText: label,
        helperText: helper,
        helperMaxLines: 3,
        prefixText: prefix,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: BorderSide.none,
        ),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Detener trabajo',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: _service == null
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withValues(alpha: 0.06),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusLarge),
                    ),
                    child: Text(
                      'Usa esta opción solo si continuar no es seguro o sería '
                      'técnicamente incorrecto. Si puedes terminar el trabajo '
                      'aprobado originalmente, elige "Continuar con el trabajo '
                      'original".',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13, height: 1.5, color: AppTheme.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _label('Motivo'),
                  DropdownButtonFormField<String>(
                    initialValue: _motivo,
                    decoration: _decoration('Selecciona el motivo'),
                    items: WorkStop.reasons.entries
                        .map((e) =>
                            DropdownMenuItem(value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) => setState(() => _motivo = v),
                    validator: (v) => v == null ? 'Selecciona un motivo' : null,
                  ),
                  const SizedBox(height: 20),
                  _label('Explicación'),
                  TextFormField(
                    controller: _descripcion,
                    maxLines: 4,
                    maxLength: 1000,
                    decoration: _decoration(
                      'Qué encontraste y por qué no se puede continuar',
                    ),
                    validator: (v) => (v?.trim().length ?? 0) < 10
                        ? 'Explica con más detalle'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _label('Fotos de evidencia (${_photos.length}/$_maxPhotos)'),
                  SizedBox(
                    height: 96,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        if (_photos.length < _maxPhotos) ...[
                          _PhotoButton(
                            icon: Icons.photo_camera_outlined,
                            label: 'Cámara',
                            onTap: () => _addPhoto(ImageSource.camera),
                          ),
                          const SizedBox(width: 8),
                          _PhotoButton(
                            icon: Icons.photo_library_outlined,
                            label: 'Galería',
                            onTap: () => _addPhoto(ImageSource.gallery),
                          ),
                        ],
                        for (var i = 0; i < _photos.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusMedium),
                                  child: Image.file(_photos[i],
                                      width: 96, height: 96, fit: BoxFit.cover),
                                ),
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _photos.removeAt(i)),
                                    child: const CircleAvatar(
                                      radius: 12,
                                      backgroundColor: Colors.black54,
                                      child: Icon(Icons.close,
                                          size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _label('Monto por el trabajo realizado'),
                  TextFormField(
                    controller: _monto,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: _decoration(
                      'Monto en MXN',
                      prefix: '\$ ',
                      helper:
                          'Máximo ${CurrencyFormatter.format(_approved)}, el monto '
                          'que el cliente aprobó. Pon 0 si no corresponde cobrar nada.',
                    ),
                    validator: (v) {
                      final m = double.tryParse(v ?? '');
                      if (m == null || m < 0) return 'Ingresa un monto válido';
                      if (m > _approved) {
                        return 'No puede ser mayor a ${CurrencyFormatter.format(_approved)}';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.pan_tool_outlined,
                              color: Colors.white),
                      label: Text(
                        _submitting ? 'Enviando…' : 'Detener y avisar al cliente',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorColor,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMedium),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _PhotoButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PhotoButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: Container(
        width: 96,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border:
              Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.primaryColor),
            const SizedBox(height: 4),
            Text(label,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor)),
          ],
        ),
      ),
    );
  }
}
