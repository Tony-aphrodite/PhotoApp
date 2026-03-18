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
  PlatformStats? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await context.read<PaymentRepository>().getPlatformStats();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Finanzas')),
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
                    // Revenue card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1A1D29), Color(0xFF2D3142)],
                        ),
                        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
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
                            value: '\$${_stats?.totalRevenue.toStringAsFixed(2) ?? "0.00"}',
                            icon: Icons.trending_up,
                            color: AppTheme.successColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricCard(
                            label: 'Pagado a Técnicos',
                            value: '\$${_stats?.totalPaidToTechnicians.toStringAsFixed(2) ?? "0.00"}',
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
                            label: 'Comisión Este Mes',
                            value: '\$${_stats?.monthCommission.toStringAsFixed(2) ?? "0.00"}',
                            icon: Icons.calendar_month,
                            color: AppTheme.warningColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricCard(
                            label: 'Tx Este Mes',
                            value: '${_stats?.monthTransactions ?? 0}',
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
                                title: 'Plataforma\n${(_stats!.totalCommission / _stats!.totalRevenue * 100).toStringAsFixed(1)}%',
                                color: AppTheme.primaryColor,
                                radius: 60,
                                titleStyle: const TextStyle(
                                    fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                              PieChartSectionData(
                                value: _stats!.totalPaidToTechnicians,
                                title: 'Técnicos\n${(_stats!.totalPaidToTechnicians / _stats!.totalRevenue * 100).toStringAsFixed(1)}%',
                                color: AppTheme.successColor,
                                radius: 60,
                                titleStyle: const TextStyle(
                                    fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                              PieChartSectionData(
                                value: _stats!.totalRevenue -
                                    _stats!.totalCommission -
                                    _stats!.totalPaidToTechnicians,
                                title: 'Stripe',
                                color: AppTheme.textTertiary,
                                radius: 50,
                                titleStyle: const TextStyle(
                                    fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Recent transactions
                    Text('Transacciones Recientes',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),

                    StreamBuilder<List<TransactionModel>>(
                      stream: context
                          .read<PaymentRepository>()
                          .getAllTransactions(),
                      builder: (context, snapshot) {
                        final transactions = snapshot.data ?? [];

                        if (transactions.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(
                                'No hay transacciones',
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(color: AppTheme.textSecondary),
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
                              const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final tx = transactions[index];
                            return Card(
                              margin: EdgeInsets.zero,
                              child: ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: tx.estado == 'completado'
                                      ? AppTheme.successColor.withValues(alpha: 0.1)
                                      : AppTheme.warningColor.withValues(alpha: 0.1),
                                  child: Icon(
                                    tx.estado == 'completado'
                                        ? Icons.check
                                        : Icons.pending,
                                    size: 18,
                                    color: tx.estado == 'completado'
                                        ? AppTheme.successColor
                                        : AppTheme.warningColor,
                                  ),
                                ),
                                title: Text(
                                  '\$${tx.montoTotal.toStringAsFixed(2)}',
                                  style: theme.textTheme.titleSmall,
                                ),
                                subtitle: Text(
                                  'Comisión: \$${tx.comisionPlataforma.toStringAsFixed(2)} | Técnico: \$${tx.montoTecnico.toStringAsFixed(2)}',
                                  style: theme.textTheme.bodySmall,
                                ),
                                trailing: Text(
                                  DateFormat('dd/MM\nHH:mm')
                                      .format(tx.createdAt),
                                  style: theme.textTheme.bodySmall,
                                  textAlign: TextAlign.right,
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
