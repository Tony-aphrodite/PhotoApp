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

    try {
      final stats = await context
          .read<PaymentRepository>()
          .getTechnicianEarnings(authState.user.uid);
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
                    // Main earnings card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
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
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Month stats
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Este Mes',
                            value: '\$${_stats?.monthEarned.toStringAsFixed(2) ?? "0.00"}',
                            icon: Icons.calendar_month,
                            color: AppTheme.successColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'Servicios Mes',
                            value: '${_stats?.monthServices ?? 0}',
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
                            label: 'Comisión Deducida',
                            value: '\$${_stats?.totalCommission.toStringAsFixed(2) ?? "0.00"}',
                            icon: Icons.receipt_long,
                            color: AppTheme.warningColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'Calificación',
                            value: '${user.calificacionPromedio?.toStringAsFixed(1) ?? "0.0"}',
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
                          .getTechnicianTransactions(user.uid),
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
                                      size: 48,
                                      color: AppTheme.textTertiary),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No hay transacciones aún',
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
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
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.successColor
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.payment,
                                      color: AppTheme.successColor),
                                ),
                                title: Text(
                                  '+\$${tx.montoTecnico.toStringAsFixed(2)}',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: AppTheme.successColor,
                                  ),
                                ),
                                subtitle: Text(
                                  'Total: \$${tx.montoTotal.toStringAsFixed(2)} | Comisión: \$${tx.comisionPlataforma.toStringAsFixed(2)}',
                                  style: theme.textTheme.bodySmall,
                                ),
                                trailing: Text(
                                  DateFormat('dd/MM').format(tx.createdAt),
                                  style: theme.textTheme.bodySmall,
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
