import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/service_card.dart';
import '../../../data/models/quotation_model.dart';
import '../../../data/repositories/service_flow_repository.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';

class ReviewQuotationScreen extends StatefulWidget {
  final String quotationId;

  const ReviewQuotationScreen({super.key, required this.quotationId});

  @override
  State<ReviewQuotationScreen> createState() => _ReviewQuotationScreenState();
}

class _ReviewQuotationScreenState extends State<ReviewQuotationScreen> {
  final PageController _photoPageController = PageController();
  int _currentPhotoPage = 0;

  @override
  void dispose() {
    _photoPageController.dispose();
    super.dispose();
  }

  bool _responding = false;

  Future<void> _respond(
      BuildContext context, QuotationModel quotation, bool aprobar) async {
    // Approving commits the cliente to a charge, so it is never one tap.
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: Text(
          aprobar ? 'Aprobar cotización' : 'Rechazar cotización',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          aprobar
              ? quotation.isRevision
                  ? 'El nuevo total del servicio será ${CurrencyFormatter.format(quotation.total)}. '
                      'El técnico continuará con el trabajo adicional y este será el monto que pagarás al terminar.'
                  : 'Aceptas pagar ${CurrencyFormatter.format(quotation.total)} al terminar el servicio. '
                      'El técnico podrá iniciar el trabajo.'
              : quotation.isRevision
                  ? 'El monto aprobado se mantiene en ${CurrencyFormatter.format(quotation.montoAnterior ?? 0)}. '
                      'El técnico decidirá si puede terminar solo el trabajo original de forma segura.'
                  : 'El técnico podrá enviarte una nueva cotización.',
          style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  aprobar ? AppTheme.successColor : AppTheme.errorColor,
            ),
            child: Text(aprobar ? 'Aprobar' : 'Rechazar',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    setState(() => _responding = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<ServiceFlowRepository>().respondQuotation(
            cotizacionId: quotation.id,
            aprobar: aprobar,
          );
      if (aprobar) {
        await AnalyticsService.logQuotationApproved(
          servicioId: quotation.servicioId,
          total: quotation.total,
        );
      } else {
        await AnalyticsService.logQuotationRejected(
            servicioId: quotation.servicioId);
      }
      messenger.showSnackBar(SnackBar(
        content: Text(aprobar ? 'Cotización aprobada.' : 'Cotización rechazada.'),
        backgroundColor: aprobar ? AppTheme.successColor : AppTheme.textSecondary,
      ));
      if (context.mounted) context.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(e is FlowException ? e.message : 'Error: $e'),
        backgroundColor: AppTheme.errorColor,
      ));
    } finally {
      if (mounted) setState(() => _responding = false);
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
          'Cotización',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('cotizaciones')
            .doc(widget.quotationId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            );
          }

          final quotation = QuotationModel.fromFirestore(snapshot.data!);
          final authState = context.read<AuthBloc>().state;
          final isCliente = authState is AuthAuthenticated &&
              authState.user.uid == quotation.clienteId;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (quotation.isRevision) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withValues(alpha: 0.08),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusLarge),
                      border: Border.all(
                          color: AppTheme.warningColor.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cotización revisada (versión ${quotation.version})',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Durante el trabajo el técnico encontró algo adicional. '
                          'Monto aprobado antes: ${CurrencyFormatter.format(quotation.montoAnterior ?? 0)} · '
                          'Nuevo total: ${CurrencyFormatter.format(quotation.total)}.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            height: 1.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Status banner
                if (!quotation.isPending)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 20),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: quotation.estado == 'aprobada'
                            ? [
                                const Color(0xFF00C853),
                                const Color(0xFF69F0AE),
                              ]
                            : [
                                AppTheme.errorColor,
                                AppTheme.errorColor.withValues(alpha: 0.7),
                              ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMedium),
                      boxShadow: [
                        BoxShadow(
                          color: (quotation.estado == 'aprobada'
                                  ? AppTheme.successColor
                                  : AppTheme.errorColor)
                              .withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          quotation.estado == 'aprobada'
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          quotation.estado == 'aprobada'
                              ? 'Cotizacion Aprobada'
                              : 'Cotizacion Rechazada',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Photo carousel
                if (quotation.fotosDiagnostico.isNotEmpty) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusLarge),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.photo_library_outlined,
                                  size: 18,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Fotos del Diagnostico',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 200,
                          child: PageView.builder(
                            controller: _photoPageController,
                            itemCount: quotation.fotosDiagnostico.length,
                            onPageChanged: (i) =>
                                setState(() => _currentPhotoPage = i),
                            itemBuilder: (_, i) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMedium),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ServiceCard.buildImage(
                                    quotation.fotosDiagnostico[i],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (quotation.fotosDiagnostico.length > 1)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                quotation.fotosDiagnostico.length,
                                (i) => AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 3),
                                  width: _currentPhotoPage == i ? 20 : 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _currentPhotoPage == i
                                        ? AppTheme.primaryColor
                                        : AppTheme.primaryColor
                                            .withValues(alpha: 0.2),
                                    borderRadius:
                                        BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Technician notes
                if (quotation.notasTecnico != null) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusLarge),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.warningColor
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.note_alt_outlined,
                                size: 18,
                                color: AppTheme.warningColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Notas del Tecnico',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          quotation.notasTecnico!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Item breakdown cards
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusLarge),
                    boxShadow: AppTheme.softShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.receipt_long_outlined,
                              size: 18,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Desglose',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...quotation.items.map((item) => Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundLight,
                              borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMedium),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _tipoColor(item.tipo)
                                        .withValues(alpha: 0.1),
                                    borderRadius:
                                        BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _tipoLabel(item.tipo),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: _tipoColor(item.tipo),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.descripcion,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${item.cantidad} x ${CurrencyFormatter.compact(item.precioUnitario)}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          color: AppTheme.textTertiary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.format(item.subtotal),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Totals gradient card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF0A2E36),
                        Color(0xFF0D5C61),
                        Color(0xFF14BDAC),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusLarge),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF14BDAC)
                            .withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _GradientRow('Subtotal', quotation.subtotal),
                      const SizedBox(height: 6),
                      _GradientRow('IVA', quotation.impuestos),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        child: Divider(
                          color: Colors.white.withValues(alpha: 0.15),
                          height: 1,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(quotation.total),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Action buttons — only the cliente answers.
                if (quotation.isPending && isCliente) ...[
                  // Approve button
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00C853), Color(0xFF69F0AE)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMedium),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.successColor
                              .withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _responding
                            ? null
                            : () => _respond(context, quotation, true),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                  Icons.check_circle_outline_rounded,
                                  color: Colors.white,
                                  size: 22),
                              const SizedBox(width: 10),
                              Text(
                                'Aprobar (${CurrencyFormatter.compact(quotation.total)})',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Reject button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _responding
                          ? null
                          : () => _respond(context, quotation, false),
                      icon: const Icon(Icons.cancel_outlined,
                          color: AppTheme.errorColor),
                      label: Text(
                        'Rechazar',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                        side: const BorderSide(color: AppTheme.errorColor),
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppTheme.radiusMedium),
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),
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

class _GradientRow extends StatelessWidget {
  final String label;
  final double amount;

  const _GradientRow(this.label, this.amount);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        Text(
          CurrencyFormatter.format(amount),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}
