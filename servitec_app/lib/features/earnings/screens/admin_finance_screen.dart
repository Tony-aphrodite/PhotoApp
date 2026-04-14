import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
                strokeWidth: 3,
              ),
            )
          : RefreshIndicator(
              color: AppTheme.primaryColor,
              onRefresh: _loadStats,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // --- Premium Header ---
                  SliverAppBar(
                    expandedHeight: 130,
                    floating: true,
                    pinned: true,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        padding:
                            const EdgeInsets.fromLTRB(24, 70, 24, 16),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF0A2E36),
                              Color(0xFF0D5C61),
                              Color(0xFF14BDAC),
                            ],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Dashboard Financiero',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Resumen de ingresos y comisiones',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color:
                                    Colors.white.withValues(alpha: 0.6),
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // --- Period Selector ---
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withValues(alpha: 0.04),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.filter_list_rounded,
                                    size: 18,
                                    color: AppTheme.textTertiary),
                                const SizedBox(width: 8),
                                Text(
                                  'Periodo:',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: DropdownButtonHideUnderline(
                                    child:
                                        DropdownButton<EarningPeriod>(
                                      value: _selectedPeriod,
                                      isExpanded: true,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                      ),
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

                          // --- Revenue Card with Gradient ---
                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF0A2E36),
                                  Color(0xFF0D5C61),
                                  Color(0xFF14BDAC),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0A2E36)
                                      .withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white
                                        .withValues(alpha: 0.12),
                                    borderRadius:
                                        BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _selectedPeriod.label,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Comision Total',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '\$${_stats?.totalCommission.toStringAsFixed(2) ?? "0.00"}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_stats?.totalTransactions ?? 0} transacciones',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    color: Colors.white
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // --- Stats Grid ---
                          Row(
                            children: [
                              Expanded(
                                child: _MetricCard(
                                  label: 'Ingresos Totales',
                                  value:
                                      '\$${_stats?.totalRevenue.toStringAsFixed(2) ?? "0.00"}',
                                  icon: Icons.trending_up_rounded,
                                  gradientColors: const [
                                    Color(0xFF00C853),
                                    Color(0xFF69F0AE),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _MetricCard(
                                  label: 'Pagado a Tecnicos',
                                  value:
                                      '\$${_stats?.totalPaidToTechnicians.toStringAsFixed(2) ?? "0.00"}',
                                  icon: Icons.people_rounded,
                                  gradientColors: const [
                                    Color(0xFF2979FF),
                                    Color(0xFF82B1FF),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                child: _MetricCard(
                                  label: 'Comision Plataforma',
                                  value:
                                      '\$${_stats?.totalCommission.toStringAsFixed(2) ?? "0.00"}',
                                  icon: Icons.account_balance_rounded,
                                  gradientColors: const [
                                    Color(0xFFFF9800),
                                    Color(0xFFFFB74D),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _MetricCard(
                                  label: 'Transacciones',
                                  value:
                                      '${_stats?.totalTransactions ?? 0}',
                                  icon: Icons.receipt_long_rounded,
                                  gradientColors: const [
                                    Color(0xFF0D7377),
                                    Color(0xFF14BDAC),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 28),

                          // --- Pie Chart ---
                          if (_stats != null &&
                              _stats!.totalRevenue > 0) ...[
                            Text(
                              'Distribucion de Ingresos',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withValues(alpha: 0.04),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: SizedBox(
                                height: 220,
                                child: PieChart(
                                  PieChartData(
                                    sectionsSpace: 3,
                                    centerSpaceRadius: 45,
                                    sections: [
                                      PieChartSectionData(
                                        value:
                                            _stats!.totalCommission,
                                        title:
                                            'Plataforma\n${(_stats!.totalCommission / _stats!.totalRevenue * 100).toStringAsFixed(1)}%',
                                        color:
                                            const Color(0xFF0A6B6E),
                                        radius: 65,
                                        titleStyle:
                                            GoogleFonts.plusJakartaSans(
                                          fontSize: 10,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      PieChartSectionData(
                                        value: _stats!
                                            .totalPaidToTechnicians,
                                        title:
                                            'Tecnicos\n${(_stats!.totalPaidToTechnicians / _stats!.totalRevenue * 100).toStringAsFixed(1)}%',
                                        color:
                                            const Color(0xFF14BDAC),
                                        radius: 65,
                                        titleStyle:
                                            GoogleFonts.plusJakartaSans(
                                          fontSize: 10,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      PieChartSectionData(
                                        value: _stats!.totalRevenue -
                                            _stats!.totalCommission -
                                            _stats!
                                                .totalPaidToTechnicians,
                                        title: 'Stripe',
                                        color:
                                            const Color(0xFFFF6B35),
                                        radius: 55,
                                        titleStyle:
                                            GoogleFonts.plusJakartaSans(
                                          fontSize: 10,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Legend
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withValues(alpha: 0.04),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _LegendItem(
                                      color: const Color(0xFF0A6B6E),
                                      label: 'Plataforma'),
                                  _LegendItem(
                                      color: const Color(0xFF14BDAC),
                                      label: 'Tecnicos'),
                                  _LegendItem(
                                      color: const Color(0xFFFF6B35),
                                      label: 'Stripe'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),
                          ],

                          // --- Recent Transactions ---
                          Text(
                            'Transacciones Recientes',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 12),

                          StreamBuilder<List<TransactionModel>>(
                            stream: context
                                .read<PaymentRepository>()
                                .getAllTransactionsByPeriod(
                                    _selectedPeriod),
                            builder: (context, snapshot) {
                              final transactions =
                                  snapshot.data ?? [];

                              if (transactions.isEmpty) {
                                return Container(
                                  padding: const EdgeInsets.all(32),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.04),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      'No hay transacciones en este periodo',
                                      style:
                                          GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        color:
                                            AppTheme.textSecondary,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                );
                              }

                              return ListView.builder(
                                shrinkWrap: true,
                                physics:
                                    const NeverScrollableScrollPhysics(),
                                itemCount:
                                    transactions.length > 20
                                        ? 20
                                        : transactions.length,
                                itemBuilder: (context, index) {
                                  final tx = transactions[index];
                                  return Container(
                                    margin:
                                        const EdgeInsets.only(
                                            bottom: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius:
                                          BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(
                                                  alpha: 0.04),
                                          blurRadius: 16,
                                          offset:
                                              const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Padding(
                                      padding:
                                          const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment
                                                .start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment
                                                    .spaceBetween,
                                            children: [
                                              Text(
                                                DateFormat(
                                                        'dd/MM/yyyy HH:mm')
                                                    .format(tx
                                                        .createdAt),
                                                style: GoogleFonts
                                                    .plusJakartaSans(
                                                  fontSize: 12,
                                                  color: AppTheme
                                                      .textTertiary,
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets
                                                        .symmetric(
                                                        horizontal:
                                                            10,
                                                        vertical:
                                                            4),
                                                decoration:
                                                    BoxDecoration(
                                                  color: tx.estado ==
                                                          'completado'
                                                      ? AppTheme
                                                          .successColor
                                                          .withValues(
                                                              alpha:
                                                                  0.1)
                                                      : AppTheme
                                                          .warningColor
                                                          .withValues(
                                                              alpha:
                                                                  0.1),
                                                  borderRadius:
                                                      BorderRadius
                                                          .circular(
                                                              20),
                                                ),
                                                child: Text(
                                                  tx.estado ==
                                                          'completado'
                                                      ? 'Completada'
                                                      : 'Pendiente',
                                                  style: GoogleFonts
                                                      .plusJakartaSans(
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight
                                                            .w700,
                                                    color: tx.estado ==
                                                            'completado'
                                                        ? AppTheme
                                                            .successColor
                                                        : AppTheme
                                                            .warningColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          Divider(
                                            height: 20,
                                            color: AppTheme
                                                .dividerColor,
                                          ),
                                          _TxRow(
                                            label:
                                                'Total Cobrado',
                                            value:
                                                '\$${tx.montoTotal.toStringAsFixed(2)}',
                                          ),
                                          _TxRow(
                                            label:
                                                'Tu Comision (15%)',
                                            value:
                                                '+\$${tx.comisionPlataforma.toStringAsFixed(2)}',
                                            color: AppTheme
                                                .successColor,
                                          ),
                                          _TxRow(
                                            label:
                                                'Stripe (2.9%+\$0.30)',
                                            value:
                                                '-\$${tx.comisionStripe.toStringAsFixed(2)}',
                                            color: AppTheme
                                                .textTertiary,
                                          ),
                                          const SizedBox(
                                              height: 4),
                                          Container(
                                            padding:
                                                const EdgeInsets
                                                    .symmetric(
                                                    horizontal: 10,
                                                    vertical: 6),
                                            decoration:
                                                BoxDecoration(
                                              color: const Color(
                                                      0xFF2979FF)
                                                  .withValues(
                                                      alpha: 0.06),
                                              borderRadius:
                                                  BorderRadius
                                                      .circular(8),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  'Pagado al Tecnico',
                                                  style: GoogleFonts
                                                      .plusJakartaSans(
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight
                                                            .w700,
                                                    color:
                                                        AppTheme
                                                            .infoColor,
                                                  ),
                                                ),
                                                Text(
                                                  '\$${tx.montoTecnico.toStringAsFixed(2)}',
                                                  style: GoogleFonts
                                                      .plusJakartaSans(
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight
                                                            .w700,
                                                    color:
                                                        AppTheme
                                                            .infoColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),

                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// --- Transaction Row ---
class _TxRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _TxRow({
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: color ?? AppTheme.textSecondary,
              letterSpacing: -0.2,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color ?? AppTheme.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Metric Card with Gradient ---
class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final List<Color> gradientColors;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Legend Item ---
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
