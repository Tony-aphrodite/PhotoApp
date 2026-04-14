import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import '../../../core/theme/app_theme.dart';
import '../../../data/models/service_model.dart';
import '../../../data/repositories/payment_repository.dart';
import '../../../data/repositories/service_repository.dart';
import '../../../data/repositories/config_repository.dart';

class PaymentScreen extends StatefulWidget {
  final String serviceId;

  const PaymentScreen({super.key, required this.serviceId});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _loading = true;
  bool _processing = false;
  ServiceModel? _service;
  CommissionBreakdown? _breakdown;

  @override
  void initState() {
    super.initState();
    _loadService();
  }

  Future<void> _loadService() async {
    try {
      final service = await context
          .read<ServiceRepository>()
          .getService(widget.serviceId);

      final configRepo = context.read<ConfigRepository>();
      final comisionConfig = await configRepo.getComisionConfig();

      final paymentRepo = context.read<PaymentRepository>();
      final amount = service.costoFinal ?? service.estimacionCosto ?? 0;
      final breakdown = paymentRepo.calculateCommission(
        montoTotal: amount,
        porcentajePlataforma: comisionConfig['porcentajePlataforma'] ?? 15.0,
      );

      if (mounted) {
        setState(() {
          _service = service;
          _breakdown = breakdown;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _processPayment() async {
    if (_service == null || _breakdown == null) return;

    setState(() => _processing = true);

    try {
      final paymentRepo = context.read<PaymentRepository>();

      // 1. Create PaymentIntent via Cloud Function
      final clientSecret = await paymentRepo.createPaymentIntent(
        servicioId: _service!.id,
        amount: _breakdown!.montoTotal,
        currency: 'usd',
      );

      // 2. Initialize payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'ServiTec',
          style: ThemeMode.system,
        ),
      );

      // 3. Present payment sheet
      await Stripe.instance.presentPaymentSheet();

      // 4. Payment succeeded - record transaction
      await paymentRepo.recordPayment(
        servicioId: _service!.id,
        clienteId: _service!.clienteId,
        tecnicoId: _service!.tecnicoId!,
        montoTotal: _breakdown!.montoTotal,
        comisionPlataforma: _breakdown!.comisionPlataforma,
        comisionStripe: _breakdown!.comisionStripe,
        montoTecnico: _breakdown!.montoTecnico,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pago exitoso'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        context.pop();
      }
    } on StripeException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.error.localizedMessage ?? 'Error en el pago'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
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
      if (mounted) setState(() => _processing = false);
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
          'Pagar Servicio',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : _service == null
              ? Center(
                  child: Text(
                    'Servicio no encontrado',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Service info card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusLarge),
                          boxShadow: AppTheme.softShadow,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF0D7377),
                                    Color(0xFF14BDAC),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.build_outlined,
                                  color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _service!.titulo,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tecnico: ${_service!.tecnicoNombre ?? "N/A"}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Payment breakdown card
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
                                  'Desglose de Pago',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            if (_breakdown != null) ...[
                              _BreakdownRow(
                                label: 'Costo del servicio',
                                amount: _breakdown!.montoTotal,
                                isBold: false,
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: Divider(
                                    color: AppTheme.dividerColor, height: 1),
                              ),
                              _BreakdownRow(
                                label:
                                    'Comision plataforma (${_breakdown!.porcentajePlataforma.toStringAsFixed(0)}%)',
                                amount: _breakdown!.comisionPlataforma,
                                isBold: false,
                                isSubtract: true,
                              ),
                              const SizedBox(height: 10),
                              _BreakdownRow(
                                label: 'Comision procesamiento',
                                amount: _breakdown!.comisionStripe,
                                isBold: false,
                                isSubtract: true,
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: Divider(
                                    color: AppTheme.dividerColor, height: 1),
                              ),
                              _BreakdownRow(
                                label: 'Pago al tecnico',
                                amount: _breakdown!.montoTecnico,
                                isBold: false,
                                color: AppTheme.successColor,
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Total card with gradient
                      if (_breakdown != null)
                        Container(
                          padding: const EdgeInsets.all(24),
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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total a pagar',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color:
                                          Colors.white.withValues(alpha: 0.7),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '\$${_breakdown!.montoTotal.toStringAsFixed(2)}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.payment_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 20),

                      // Security badges
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusLarge),
                          boxShadow: AppTheme.softShadow,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _SecurityBadge(
                              icon: Icons.lock_outline_rounded,
                              label: 'Pago\nSeguro',
                            ),
                            Container(
                              width: 1,
                              height: 36,
                              color: AppTheme.dividerColor,
                            ),
                            _SecurityBadge(
                              icon: Icons.verified_user_outlined,
                              label: 'Datos\nProtegidos',
                            ),
                            Container(
                              width: 1,
                              height: 36,
                              color: AppTheme.dividerColor,
                            ),
                            _SecurityBadge(
                              icon: Icons.credit_card_outlined,
                              label: 'Procesado\npor Stripe',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Pay button
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0D7377), Color(0xFF14BDAC)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMedium),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF14BDAC)
                                  .withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _processing ? null : _processPayment,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMedium),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_processing)
                                    const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  else
                                    const Icon(Icons.payment_rounded,
                                        color: Colors.white, size: 22),
                                  const SizedBox(width: 10),
                                  Text(
                                    _processing
                                        ? 'Procesando...'
                                        : 'Pagar \$${_breakdown?.montoTotal.toStringAsFixed(2) ?? "0.00"}',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontSize: 17,
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

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}

class _SecurityBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SecurityBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 22, color: AppTheme.primaryColor),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isBold;
  final bool isSubtract;
  final Color? color;

  const _BreakdownRow({
    required this.label,
    required this.amount,
    this.isBold = false,
    this.isSubtract = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: isBold ? 15 : 14,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: isBold ? AppTheme.textPrimary : AppTheme.textSecondary,
            ),
          ),
        ),
        Text(
          '${isSubtract ? "-" : ""}\$${amount.toStringAsFixed(2)}',
          style: GoogleFonts.plusJakartaSans(
            fontSize: isBold ? 17 : 14,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            color:
                color ?? (isSubtract ? AppTheme.textTertiary : AppTheme.textPrimary),
          ),
        ),
      ],
    );
  }
}
