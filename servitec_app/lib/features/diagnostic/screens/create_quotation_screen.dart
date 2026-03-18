import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/quotation_model.dart';
import '../../../data/repositories/storage_repository.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';

class CreateQuotationScreen extends StatefulWidget {
  final String serviceId;

  const CreateQuotationScreen({super.key, required this.serviceId});

  @override
  State<CreateQuotationScreen> createState() => _CreateQuotationScreenState();
}

class _CreateQuotationScreenState extends State<CreateQuotationScreen> {
  final _notesController = TextEditingController();
  final List<_ItemEntry> _items = [];
  final List<File> _diagnosticPhotos = [];
  bool _submitting = false;
  final _picker = ImagePicker();

  double get _subtotal =>
      _items.fold(0, (sum, item) => sum + item.subtotal);
  double get _tax => _subtotal * 0.16; // 16% IVA
  double get _total => _subtotal + _tax;

  void _addItem() {
    setState(() {
      _items.add(_ItemEntry());
    });
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1200,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _diagnosticPhotos.add(File(picked.path)));
    }
  }

  Future<void> _submit() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un item')),
      );
      return;
    }

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    setState(() => _submitting = true);

    try {
      // Upload diagnostic photos
      List<String> photoUrls = [];
      if (_diagnosticPhotos.isNotEmpty) {
        final storageRepo = context.read<StorageRepository>();
        photoUrls = await storageRepo.uploadServicePhotos(
          '${widget.serviceId}_diagnostico',
          _diagnosticPhotos,
        );
      }

      final quotation = QuotationModel(
        id: '',
        servicioId: widget.serviceId,
        tecnicoId: authState.user.uid,
        items: _items
            .map((e) => QuotationItem(
                  descripcion: e.descController.text.trim(),
                  tipo: e.tipo,
                  cantidad: int.tryParse(e.cantController.text) ?? 1,
                  precioUnitario:
                      double.tryParse(e.priceController.text) ?? 0,
                  subtotal: e.subtotal,
                ))
            .toList(),
        subtotal: _subtotal,
        impuestos: _tax,
        total: _total,
        estado: 'pendiente',
        notasTecnico: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        fotosDiagnostico: photoUrls,
        fechaCreacion: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('cotizaciones')
          .add(quotation.toFirestore());

      // Update service state
      await FirebaseFirestore.instance
          .collection('servicios')
          .doc(widget.serviceId)
          .update({
        'estado': 'cotizacion_enviada',
        'updatedAt': Timestamp.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cotización enviada al cliente'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Crear Cotización')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Items header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Items', style: theme.textTheme.titleMedium),
                TextButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar'),
                ),
              ],
            ),

            if (_items.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.dividerColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Agrega items de mano de obra, materiales o piezas',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: AppTheme.textTertiary),
                ),
              ),

            // Item list
            ...List.generate(_items.length, (index) {
              final item = _items[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('Item ${index + 1}',
                                style: theme.textTheme.titleSmall),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: AppTheme.errorColor, size: 20),
                            onPressed: () => _removeItem(index),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: item.descController,
                        decoration: const InputDecoration(
                          labelText: 'Descripción',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              value: item.tipo,
                              decoration: const InputDecoration(
                                labelText: 'Tipo',
                                isDense: true,
                              ),
                              items: const [
                                DropdownMenuItem(
                                    value: 'mano_obra',
                                    child: Text('Mano de obra')),
                                DropdownMenuItem(
                                    value: 'material',
                                    child: Text('Material')),
                                DropdownMenuItem(
                                    value: 'pieza', child: Text('Pieza')),
                              ],
                              onChanged: (v) =>
                                  setState(() => item.tipo = v ?? 'material'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: item.cantController,
                              decoration: const InputDecoration(
                                labelText: 'Cant.',
                                isDense: true,
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: item.priceController,
                              decoration: const InputDecoration(
                                labelText: 'Precio',
                                prefixText: '\$',
                                isDense: true,
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Subtotal: \$${item.subtotal.toStringAsFixed(2)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 16),

            // Diagnostic photos
            Text('Fotos del Diagnóstico', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  GestureDetector(
                    onTap: _pickPhoto,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color:
                                AppTheme.primaryColor.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.add_a_photo_outlined,
                          color: AppTheme.primaryColor),
                    ),
                  ),
                  ..._diagnosticPhotos.map((f) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(f,
                              width: 80, height: 80, fit: BoxFit.cover),
                        ),
                      )),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Notes
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notas / Observaciones',
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 24),

            // Totals
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  _TotalRow(label: 'Subtotal', amount: _subtotal),
                  const SizedBox(height: 4),
                  _TotalRow(label: 'IVA (16%)', amount: _tax),
                  const Divider(height: 16),
                  _TotalRow(label: 'Total', amount: _total, isBold: true),
                ],
              ),
            ),

            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send),
              label: const Text('Enviar Cotización al Cliente'),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _ItemEntry {
  final descController = TextEditingController();
  final cantController = TextEditingController(text: '1');
  final priceController = TextEditingController();
  String tipo = 'material';

  double get subtotal {
    final cant = int.tryParse(cantController.text) ?? 0;
    final price = double.tryParse(priceController.text) ?? 0;
    return cant * price;
  }

  void dispose() {
    descController.dispose();
    cantController.dispose();
    priceController.dispose();
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isBold;

  const _TotalRow({
    required this.label,
    required this.amount,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: isBold
                ? Theme.of(context).textTheme.titleSmall
                : Theme.of(context).textTheme.bodyMedium),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            fontSize: isBold ? 18 : 14,
            color: isBold ? AppTheme.primaryColor : null,
          ),
        ),
      ],
    );
  }
}
