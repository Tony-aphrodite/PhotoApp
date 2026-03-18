import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
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
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor),
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
      // In production, this would be handled by webhook
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Pagar Servicio')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _service == null
              ? const Center(child: Text('Servicio no encontrado'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Service info
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_service!.titulo,
                                  style: theme.textTheme.titleLarge),
                              const SizedBox(height: 4),
                              Text(
                                'Técnico: ${_service!.tecnicoNombre ?? "N/A"}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Payment breakdown
                      Text('Desglose de Pago',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),

                      if (_breakdown != null) ...[
                        _BreakdownRow(
                          label: 'Costo del servicio',
                          amount: _breakdown!.montoTotal,
                          isBold: false,
                        ),
                        const Divider(height: 24),
                        _BreakdownRow(
                          label: 'Comisión plataforma (${_breakdown!.porcentajePlataforma.toStringAsFixed(0)}%)',
                          amount: _breakdown!.comisionPlataforma,
                          isBold: false,
                          isSubtract: true,
                        ),
                        const SizedBox(height: 8),
                        _BreakdownRow(
                          label: 'Comisión procesamiento',
                          amount: _breakdown!.comisionStripe,
                          isBold: false,
                          isSubtract: true,
                        ),
                        const Divider(height: 24),
                        _BreakdownRow(
                          label: 'Pago al técnico',
                          amount: _breakdown!.montoTecnico,
                          isBold: false,
                          color: AppTheme.successColor,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.08),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMedium),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total a pagar',
                                  style: theme.textTheme.titleMedium),
                              Text(
                                '\$${_breakdown!.montoTotal.toStringAsFixed(2)}',
                                style:
                                    theme.textTheme.headlineMedium?.copyWith(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Security note
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline,
                              size: 14, color: AppTheme.textTertiary),
                          const SizedBox(width: 4),
                          Text(
                            'Pago seguro procesado por Stripe',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Pay button
                      ElevatedButton.icon(
                        onPressed: _processing ? null : _processPayment,
                        icon: _processing
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.payment),
                        label: Text(_processing
                            ? 'Procesando...'
                            : 'Pagar \$${_breakdown?.montoTotal.toStringAsFixed(2) ?? "0.00"}'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ],
                  ),
                ),
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
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isBold
              ? theme.textTheme.titleSmall
              : theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
        ),
        Text(
          '${isSubtract ? "-" : ""}\$${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: color ?? (isSubtract ? AppTheme.textTertiary : null),
          ),
        ),
      ],
    );
  }
}
