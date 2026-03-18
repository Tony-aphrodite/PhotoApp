import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/quotation_model.dart';

class ReviewQuotationScreen extends StatelessWidget {
  final String quotationId;

  const ReviewQuotationScreen({super.key, required this.quotationId});

  Future<void> _respond(BuildContext context, String response) async {
    final firestore = FirebaseFirestore.instance;

    final doc = await firestore.collection('cotizaciones').doc(quotationId).get();
    final servicioId = doc.data()?['servicioId'];

    await firestore.collection('cotizaciones').doc(quotationId).update({
      'estado': response,
      'fechaRespuesta': Timestamp.now(),
    });

    if (servicioId != null) {
      final newStatus =
          response == 'aprobada' ? 'en_reparacion' : 'cotizacion_rechazada';
      await firestore.collection('servicios').doc(servicioId).update({
        'estado': newStatus,
        'updatedAt': Timestamp.now(),
        if (response == 'aprobada')
          'costoFinal': (doc.data()?['total'] as num?)?.toDouble(),
      });
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response == 'aprobada'
              ? 'Cotización aprobada. El técnico procederá con la reparación.'
              : 'Cotización rechazada.'),
          backgroundColor:
              response == 'aprobada' ? AppTheme.successColor : AppTheme.errorColor,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Cotización')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('cotizaciones')
            .doc(quotationId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final quotation = QuotationModel.fromFirestore(snapshot.data!);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status
                if (quotation.estado != 'pendiente')
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: quotation.estado == 'aprobada'
                          ? AppTheme.successColor.withValues(alpha: 0.1)
                          : AppTheme.errorColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      quotation.estado == 'aprobada'
                          ? 'Cotización Aprobada'
                          : 'Cotización Rechazada',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: quotation.estado == 'aprobada'
                            ? AppTheme.successColor
                            : AppTheme.errorColor,
                      ),
                    ),
                  ),

                // Diagnostic photos
                if (quotation.fotosDiagnostico.isNotEmpty) ...[
                  Text('Fotos del Diagnóstico',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: quotation.fotosDiagnostico.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: quotation.fotosDiagnostico[i],
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Technician notes
                if (quotation.notasTecnico != null) ...[
                  Text('Notas del Técnico',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.dividerColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(quotation.notasTecnico!,
                        style: theme.textTheme.bodyMedium),
                  ),
                  const SizedBox(height: 20),
                ],

                // Items
                Text('Desglose', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),

                ...quotation.items.map((item) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _tipoColor(item.tipo)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _tipoLabel(item.tipo),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _tipoColor(item.tipo),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.descripcion,
                                      style: theme.textTheme.bodyMedium),
                                  Text(
                                    '${item.cantidad} x \$${item.precioUnitario.toStringAsFixed(2)}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '\$${item.subtotal.toStringAsFixed(2)}',
                              style: theme.textTheme.titleSmall,
                            ),
                          ],
                        ),
                      ),
                    )),

                const SizedBox(height: 16),

                // Totals
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _Row('Subtotal', quotation.subtotal),
                      const SizedBox(height: 4),
                      _Row('IVA', quotation.impuestos),
                      const Divider(height: 16),
                      _Row('Total', quotation.total, bold: true),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Action buttons
                if (quotation.estado == 'pendiente') ...[
                  ElevatedButton.icon(
                    onPressed: () => _respond(context, 'aprobada'),
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text('Aprobar (\$${quotation.total.toStringAsFixed(2)})'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _respond(context, 'rechazada'),
                    icon: const Icon(Icons.cancel_outlined,
                        color: AppTheme.errorColor),
                    label: const Text('Rechazar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorColor,
                      side: const BorderSide(color: AppTheme.errorColor),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Color _tipoColor(String tipo) {
    switch (tipo) {
      case 'mano_obra':
        return AppTheme.infoColor;
      case 'material':
        return AppTheme.warningColor;
      case 'pieza':
        return AppTheme.primaryColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _tipoLabel(String tipo) {
    switch (tipo) {
      case 'mano_obra':
        return 'Mano de obra';
      case 'material':
        return 'Material';
      case 'pieza':
        return 'Pieza';
      default:
        return tipo;
    }
  }
}

class _Row extends StatelessWidget {
  final String label;
  final double amount;
  final bool bold;

  const _Row(this.label, this.amount, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: bold
                ? Theme.of(context).textTheme.titleSmall
                : Theme.of(context).textTheme.bodyMedium),
        Text('\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              fontSize: bold ? 18 : 14,
              color: bold ? AppTheme.primaryColor : null,
            )),
      ],
    );
  }
}
