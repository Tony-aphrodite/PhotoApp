import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/repositories/payment_repository.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';

class TechnicianEarningsScreen extends StatefulWidget {
  const TechnicianEarningsScreen({super.key});

  @override
  State<TechnicianEarningsScreen> createState() =>
      _TechnicianEarningsScreenState();
}

class _TechnicianEarningsScreenState extends State<TechnicianEarningsScreen> {
  EarningPeriod _selectedPeriod = EarningPeriod.month;
  EarningStats? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    setState(() => _loading = true);

    try {
      final stats = await context
          .read<PaymentRepository>()
          .getTechnicianEarnings(authState.user.uid, period: _selectedPeriod);
      if (mounted) {
        setState(() {
          _stats = stats;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onPeriodChanged(EarningPeriod? period) {
    if (period == null || period == _selectedPeriod) return;
    setState(() => _selectedPeriod = period);
    _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = context.watch<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return const SizedBox();
    final user = authState.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Mis Ganancias')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Period selector
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                        border: Border.all(color: AppTheme.dividerColor),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 18, color: AppTheme.textSecondary),
                          const SizedBox(width: 8),
                          Text('Período:',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.textSecondary)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<EarningPeriod>(
                                value: _selectedPeriod,
                                isExpanded: true,
                                items: EarningPeriod.values
                                    .map((p) => DropdownMenuItem(
                                          value: p,
                                          child: Text(p.label),
                                        ))
                                    .toList(),
                                onChanged: _onPeriodChanged,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Main earnings card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.secondaryColor
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusLarge),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Total Ganado',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '\$${_stats?.totalEarned.toStringAsFixed(2) ?? "0.00"}',
                            style: theme.textTheme.displayMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_stats?.totalServices ?? 0} servicios completados',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white60,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedPeriod.label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Stats grid
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Neto Recibido',
                            value:
                                '\$${_stats?.totalEarned.toStringAsFixed(2) ?? "0.00"}',
                            icon: Icons.account_balance_wallet,
                            color: AppTheme.successColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'Servicios',
                            value: '${_stats?.totalServices ?? 0}',
                            icon: Icons.handyman,
                            color: AppTheme.infoColor,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Comisión Descontada',
                            value:
                                '\$${_stats?.totalCommission.toStringAsFixed(2) ?? "0.00"}',
                            icon: Icons.receipt_long,
                            color: AppTheme.warningColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'Calificación',
                            value:
                                '${user.calificacionPromedio?.toStringAsFixed(1) ?? "0.0"} ★',
                            icon: Icons.star,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Transaction history
                    Text('Historial de Pagos',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),

                    StreamBuilder<List<TransactionModel>>(
                      stream: context
                          .read<PaymentRepository>()
                          .getTechnicianTransactionsByPeriod(
                              user.uid, _selectedPeriod),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final transactions = snapshot.data ?? [];

                        if (transactions.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Icon(Icons.receipt_long_outlined,
                                      size: 48, color: AppTheme.textTertiary),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No hay transacciones en este período',
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(
                                            color: AppTheme.textSecondary),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: transactions.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final tx = transactions[index];
                            return Card(
                              margin: EdgeInsets.zero,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          DateFormat('dd/MMM/yyyy')
                                              .format(tx.createdAt),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                  color:
                                                      AppTheme.textSecondary),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.successColor
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '✅ Pagado',
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                    color:
                                                        AppTheme.successColor),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 16),
                                    _FinancialRow(
                                      label: 'Monto Total',
                                      value:
                                          '\$${tx.montoTotal.toStringAsFixed(2)}',
                                      color: theme.textTheme.bodyMedium?.color,
                                    ),
                                    _FinancialRow(
                                      label: 'Comisión Plataforma',
                                      value:
                                          '- \$${tx.comisionPlataforma.toStringAsFixed(2)}',
                                      color: AppTheme.warningColor,
                                    ),
                                    _FinancialRow(
                                      label: 'Comisión Stripe',
                                      value:
                                          '- \$${tx.comisionStripe.toStringAsFixed(2)}',
                                      color: AppTheme.textSecondary,
                                    ),
                                    const Divider(height: 12),
                                    _FinancialRow(
                                      label: 'Tu Ganancia Neta',
                                      value:
                                          '\$${tx.montoTecnico.toStringAsFixed(2)}',
                                      color: AppTheme.successColor,
                                      bold: true,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _FinancialRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool bold;

  const _FinancialRow({
    required this.label,
    required this.value,
    this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}
