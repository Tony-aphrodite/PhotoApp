import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/factura_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/repositories/factura_repository.dart';
import '../../../data/repositories/payment_repository.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';

class TechnicianEarningsScreen extends StatefulWidget {
  const TechnicianEarningsScreen({super.key});

  @override
  State<TechnicianEarningsScreen> createState() =>
      _TechnicianEarningsScreenState();
}

class _TechnicianEarningsScreenState extends State<TechnicianEarningsScreen>
    with SingleTickerProviderStateMixin {
  EarningPeriod _selectedPeriod = EarningPeriod.month;
  EarningStats? _stats;
  bool _loading = true;

  /// 0 = Ganancias, 1 = Facturas. Kept in state (rather than using a
  /// TabBarView) so both tabs stay inside the one CustomScrollView and share
  /// the gradient header.
  late final TabController _tabController;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _tabIndex) {
        setState(() => _tabIndex = _tabController.index);
      }
    });
    _loadStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    final authState = context.watch<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return const SizedBox();
    final user = authState.user;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
                strokeWidth: 2.5,
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadStats,
              color: AppTheme.primaryColor,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Premium gradient header
                  SliverAppBar(
                    expandedHeight: 200,
                    pinned: true,
                    backgroundColor: const Color(0xFF0A2E36),
                    surfaceTintColor: Colors.transparent,
                    title: Text(
                      'Mis Ganancias',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
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
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'Total Ganado',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.6),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _stats != null
                                      ? CurrencyFormatter.format(
                                          _stats!.totalEarned)
                                      : '\$0.00 MXN',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -1.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${_stats?.totalServices ?? 0} servicios completados',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color:
                                          Colors.white.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    bottom: TabBar(
                      controller: _tabController,
                      indicatorColor: Colors.white,
                      indicatorWeight: 3,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
                      labelStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      unselectedLabelStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      tabs: const [
                        Tab(text: 'Ganancias'),
                        Tab(text: 'Facturas'),
                      ],
                    ),
                  ),

                  // Body content
                  if (_tabIndex == 0)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Period pill selector
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: AppTheme.softShadow,
                            ),
                            child: Row(
                              children: EarningPeriod.values.map((period) {
                                final isSelected =
                                    period == _selectedPeriod;
                                return Expanded(
                                  child: GestureDetector(
                                    onTap: () => _onPeriodChanged(period),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      decoration: BoxDecoration(
                                        gradient: isSelected
                                            ? const LinearGradient(
                                                colors: [
                                                  Color(0xFF0D7377),
                                                  Color(0xFF14BDAC),
                                                ],
                                              )
                                            : null,
                                        borderRadius:
                                            BorderRadius.circular(11),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: AppTheme
                                                      .secondaryColor
                                                      .withValues(
                                                          alpha: 0.3),
                                                  blurRadius: 8,
                                                  offset:
                                                      const Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Center(
                                        child: Text(
                                          period.label,
                                          style:
                                              GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: isSelected
                                                ? Colors.white
                                                : AppTheme.textSecondary,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Stats grid
                          Row(
                            children: [
                              Expanded(
                                child: _PremiumStatCard(
                                  label: 'Neto Recibido',
                                  value: _stats != null
                                      ? CurrencyFormatter.format(
                                          _stats!.totalEarned)
                                      : '\$0.00 MXN',
                                  icon: Icons.account_balance_wallet_rounded,
                                  gradientColors: const [
                                    Color(0xFF00C853),
                                    Color(0xFF69F0AE),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _PremiumStatCard(
                                  label: 'Servicios',
                                  value: '${_stats?.totalServices ?? 0}',
                                  icon: Icons.handyman_rounded,
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
                                child: _PremiumStatCard(
                                  label: 'Comision',
                                  value: _stats != null
                                      ? CurrencyFormatter.format(
                                          _stats!.totalCommission)
                                      : '\$0.00 MXN',
                                  icon: Icons.receipt_long_rounded,
                                  gradientColors: const [
                                    Color(0xFFFFAB00),
                                    Color(0xFFFFD54F),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _PremiumStatCard(
                                  label: 'Calificacion',
                                  value:
                                      '${user.calificacionPromedio?.toStringAsFixed(1) ?? "0.0"}',
                                  icon: Icons.star_rounded,
                                  gradientColors: const [
                                    Color(0xFFFF6B35),
                                    Color(0xFFFF8F65),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 28),

                          // Transaction history header
                          Row(
                            children: [
                              Container(
                                width: 4,
                                height: 20,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFF0D7377),
                                      Color(0xFF14BDAC),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Historial de Pagos',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          StreamBuilder<List<TransactionModel>>(
                            stream: context
                                .read<PaymentRepository>()
                                .getTechnicianTransactionsByPeriod(
                                    user.uid, _selectedPeriod),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(32),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                    ),
                                  ),
                                );
                              }

                              final transactions = snapshot.data ?? [];

                              if (transactions.isEmpty) {
                                return Container(
                                  padding: const EdgeInsets.all(40),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: AppTheme.softShadow,
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 64,
                                        height: 64,
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor
                                              .withValues(alpha: 0.06),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.receipt_long_outlined,
                                          size: 30,
                                          color: AppTheme.primaryColor
                                              .withValues(alpha: 0.35),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No hay transacciones',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimary,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'No hay transacciones en este periodo',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          color: AppTheme.textTertiary,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return ListView.separated(
                                shrinkWrap: true,
                                physics:
                                    const NeverScrollableScrollPhysics(),
                                itemCount: transactions.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final tx = transactions[index];
                                  return _TransactionCard(tx: tx);
                                },
                              );
                            },
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),

                  if (_tabIndex == 1)
                    _FacturasSliver(tecnicoUid: user.uid),
                ],
              ),
            ),
    );
  }
}

/// Facturas tab — the técnico's CFDIs.
///
/// Two kinds land here, distinguished by [FacturaModel.tipo]:
/// the CFDI they issued to a client for a service, and the monthly CFDI
/// ServiTec issues to them for the platform commission. Both are stamped by
/// Cloud Functions, never by the app, so this view is read-only.
class _FacturasSliver extends StatelessWidget {
  final String tecnicoUid;

  const _FacturasSliver({required this.tecnicoUid});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: StreamBuilder<List<FacturaModel>>(
          stream: context.read<FacturaRepository>().streamByTecnico(tecnicoUid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
              );
            }

            if (snapshot.hasError) {
              return _FacturasEmpty(
                icon: Icons.error_outline_rounded,
                title: 'No se pudieron cargar tus facturas',
                subtitle: 'Desliza hacia abajo para reintentar.',
              );
            }

            final facturas = snapshot.data ?? const <FacturaModel>[];
            if (facturas.isEmpty) {
              return const _FacturasEmpty(
                icon: Icons.receipt_long_outlined,
                title: 'Aún no tienes facturas',
                subtitle:
                    'Cuando un cliente pague un servicio, el CFDI aparecerá aquí automáticamente.',
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: facturas.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _FacturaCard(factura: facturas[index]),
            );
          },
        ),
      ),
    );
  }
}

class _FacturasEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FacturasEmpty({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 44, color: AppTheme.textTertiary),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppTheme.textTertiary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _FacturaCard extends StatelessWidget {
  final FacturaModel factura;

  const _FacturaCard({required this.factura});

  Future<void> _open(BuildContext context, String? url, String label) async {
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label no disponible para esta factura.')),
      );
      return;
    }
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el $label.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isComision = factura.isComision;
    final fecha = factura.fechaTimbrado ?? factura.createdAt;

    // The commission CFDI is money going out, the service CFDI money coming
    // in — colour-code so a técnico can tell them apart at a glance.
    final accent = isComision ? AppTheme.accentColor : AppTheme.primaryColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isComision
                      ? Icons.percent_rounded
                      : Icons.receipt_long_rounded,
                  size: 20,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isComision
                          ? 'Comisión ServiTec${factura.periodo != null ? ' · ${factura.periodo}' : ''}'
                          : 'CFDI por servicio',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('dd/MM/yyyy · HH:mm').format(fecha),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(factura.total),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                  if (factura.isCancelled)
                    Text(
                      'Cancelada',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.errorColor,
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (factura.folioFiscal != null) ...[
            const SizedBox(height: 12),
            Text(
              'Folio fiscal',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textTertiary,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 2),
            SelectableText(
              factura.folioFiscal!,
              style: GoogleFonts.robotoMono(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _open(context, factura.pdfUrl, 'PDF'),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('PDF'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    side: BorderSide(color: accent.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _open(context, factura.xmlUrl, 'XML'),
                  icon: const Icon(Icons.code_rounded, size: 18),
                  label: const Text('XML'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: BorderSide(
                      color: AppTheme.textTertiary.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PremiumStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final List<Color> gradientColors;

  const _PremiumStatCard({
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
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: gradientColors.first.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final TransactionModel tx;

  const _TransactionCard({required this.tx});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.receipt_rounded,
                      size: 18,
                      color: AppTheme.successColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    DateFormat('dd MMM yyyy').format(tx.createdAt),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      AppTheme.successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Pagado',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.successColor,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 1,
            color: AppTheme.dividerColor,
          ),
          const SizedBox(height: 14),
          _FinancialRow(
            label: 'Monto Total',
            value: CurrencyFormatter.compact(tx.montoTotal),
            color: AppTheme.textPrimary,
          ),
          const SizedBox(height: 6),
          _FinancialRow(
            label: 'Comision Plataforma',
            value: '- ${CurrencyFormatter.compact(tx.comisionPlataforma)}',
            color: AppTheme.warningColor,
          ),
          const SizedBox(height: 6),
          _FinancialRow(
            label: 'Comision Stripe',
            value: '- ${CurrencyFormatter.compact(tx.comisionStripe)}',
            color: AppTheme.textTertiary,
          ),
          const SizedBox(height: 10),
          Container(
            height: 1,
            color: AppTheme.dividerColor,
          ),
          const SizedBox(height: 10),
          _FinancialRow(
            label: 'Tu Ganancia Neta',
            value: CurrencyFormatter.compact(tx.montoTecnico),
            color: AppTheme.successColor,
            bold: true,
          ),
        ],
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: bold ? AppTheme.textPrimary : AppTheme.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: color ?? AppTheme.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}
