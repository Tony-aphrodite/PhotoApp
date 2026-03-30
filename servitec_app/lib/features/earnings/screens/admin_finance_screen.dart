import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/repositories/payment_repository.dart';

class AdminFinanceScreen extends StatefulWidget {
  const AdminFinanceScreen({super.key});

  @override
  State<AdminFinanceScreen> createState() => _AdminFinanceScreenState();
}

class _AdminFinanceScreenState extends State<AdminFinanceScreen> {
  EarningPeriod _selectedPeriod = EarningPeriod.month;
  PlatformStats? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final stats = await context
          .read<PaymentRepository>()
          .getPlatformStats(period: _selectedPeriod);
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

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard Financiero')),
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
                          Icon(Icons.filter_list,
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

                    // Revenue card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1A1D29), Color(0xFF2D3142)],
                        ),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusLarge),
                      ),
                      child: Column(
                        children: [
                          Text('Comisión Total',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: Colors.white60)),
                          const SizedBox(height: 8),
                          Text(
                            '\$${_stats?.totalCommission.toStringAsFixed(2) ?? "0.00"}',
                            style: theme.textTheme.displayMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_stats?.totalTransactions ?? 0} transacciones',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: Colors.white54),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedPeriod.label,
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: Colors.white30),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Stats grid
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            label: 'Ingresos Totales',
                            value:
                                '\$${_stats?.totalRevenue.toStringAsFixed(2) ?? "0.00"}',
                            icon: Icons.trending_up,
                            color: AppTheme.successColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricCard(
                            label: 'Pagado a Técnicos',
                            value:
                                '\$${_stats?.totalPaidToTechnicians.toStringAsFixed(2) ?? "0.00"}',
                            icon: Icons.people,
                            color: AppTheme.infoColor,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            label: 'Comisión Plataforma',
                            value:
                                '\$${_stats?.totalCommission.toStringAsFixed(2) ?? "0.00"}',
                            icon: Icons.account_balance,
                            color: AppTheme.warningColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricCard(
                            label: 'Transacciones',
                            value: '${_stats?.totalTransactions ?? 0}',
                            icon: Icons.receipt,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Revenue distribution pie chart
                    if (_stats != null && _stats!.totalRevenue > 0) ...[
                      Text('Distribución de Ingresos',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                            sections: [
                              PieChartSectionData(
                                value: _stats!.totalCommission,
                                title:
                                    'Plataforma\n${(_stats!.totalCommission / _stats!.totalRevenue * 100).toStringAsFixed(1)}%',
                                color: AppTheme.primaryColor,
                                radius: 60,
                                titleStyle: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600),
                              ),
                              PieChartSectionData(
                                value: _stats!.totalPaidToTechnicians,
                                title:
                                    'Técnicos\n${(_stats!.totalPaidToTechnicians / _stats!.totalRevenue * 100).toStringAsFixed(1)}%',
                                color: AppTheme.successColor,
                                radius: 60,
                                titleStyle: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600),
                              ),
                              PieChartSectionData(
                                value: _stats!.totalRevenue -
                                    _stats!.totalCommission -
                                    _stats!.totalPaidToTechnicians,
                                title: 'Stripe',
                                color: AppTheme.textTertiary,
                                radius: 50,
                                titleStyle: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Recent transactions with full breakdown
                    Text('Transacciones Recientes',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),

                    StreamBuilder<List<TransactionModel>>(
                      stream: context
                          .read<PaymentRepository>()
                          .getAllTransactionsByPeriod(_selectedPeriod),
                      builder: (context, snapshot) {
                        final transactions = snapshot.data ?? [];

                        if (transactions.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(
                                'No hay transacciones en este período',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.textSecondary),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: transactions.length > 20
                              ? 20
                              : transactions.length,
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
                                          DateFormat('dd/MM/yyyy HH:mm')
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
                                            color: tx.estado == 'completado'
                                                ? AppTheme.successColor
                                                    .withValues(alpha: 0.1)
                                                : AppTheme.warningColor
                                                    .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            tx.estado == 'completado'
                                                ? '✅ Completada'
                                                : '⏳ Pendiente',
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                    color: tx.estado ==
                                                            'completado'
                                                        ? AppTheme.successColor
                                                        : AppTheme
                                                            .warningColor),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 16),
                                    _TxRow(
                                        label: 'Total Cobrado',
                                        value:
                                            '\$${tx.montoTotal.toStringAsFixed(2)}'),
                                    _TxRow(
                                      label: 'Tu Comisión (15%)',
                                      value:
                                          '+\$${tx.comisionPlataforma.toStringAsFixed(2)}',
                                      color: AppTheme.successColor,
                                    ),
                                    _TxRow(
                                      label: 'Stripe (2.9%+\$0.30)',
                                      value:
                                          '-\$${tx.comisionStripe.toStringAsFixed(2)}',
                                      color: AppTheme.textSecondary,
                                    ),
                                    _TxRow(
                                      label: 'Pagado al Técnico',
                                      value:
                                          '\$${tx.montoTecnico.toStringAsFixed(2)}',
                                      color: AppTheme.infoColor,
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

class _TxRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool bold;

  const _TxRow(
      {required this.label, required this.value, this.color, this.bold = false});

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
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
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
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
