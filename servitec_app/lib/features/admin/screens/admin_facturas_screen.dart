import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/factura_model.dart';
import '../../../data/repositories/factura_repository.dart';

/// Every CFDI on the platform, for the admin.
///
/// Técnicos already see their own under Ganancias → Facturas; this is the
/// cross-cutting view an accountant needs — all service invoices and all
/// monthly commission invoices, with the PDF and XML one tap away.
class AdminFacturasScreen extends StatefulWidget {
  const AdminFacturasScreen({super.key});

  @override
  State<AdminFacturasScreen> createState() => _AdminFacturasScreenState();
}

class _AdminFacturasScreenState extends State<AdminFacturasScreen> {
  /// null = todas
  String? _tipo;
  late Stream<List<FacturaModel>> _stream;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    _stream = context.read<FacturaRepository>().streamAll(tipo: _tipo);
  }

  void _onTipo(String? tipo) {
    if (tipo == _tipo) return;
    setState(() {
      _tipo = tipo;
      _subscribe();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Facturas (CFDI)',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                _Chip(label: 'Todas', selected: _tipo == null, onTap: () => _onTipo(null)),
                const SizedBox(width: 8),
                _Chip(
                  label: 'Servicios',
                  selected: _tipo == FacturaModel.tipoTecnicoCliente,
                  onTap: () => _onTipo(FacturaModel.tipoTecnicoCliente),
                ),
                const SizedBox(width: 8),
                _Chip(
                  label: 'Comisiones',
                  selected: _tipo == FacturaModel.tipoServitecComision,
                  onTap: () => _onTipo(FacturaModel.tipoServitecComision),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<FacturaModel>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryColor),
                  );
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final facturas = snapshot.data ?? const <FacturaModel>[];
                if (facturas.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 48, color: AppTheme.textTertiary),
                          const SizedBox(height: 14),
                          Text(
                            'Aún no hay facturas',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Se generan automáticamente al cobrar un servicio y el día 1 de cada mes para las comisiones.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: AppTheme.textTertiary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Running total for the visible set — what an accountant asks
                // for first.
                final total = facturas.fold<double>(0, (a, f) => a + f.total);

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  children: [
                    _TotalBar(count: facturas.length, total: total),
                    const SizedBox(height: 12),
                    ...facturas.map((f) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _FacturaRow(factura: f),
                        )),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalBar extends StatelessWidget {
  final int count;
  final double total;
  const _TotalBar({required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            '$count factura${count == 1 ? '' : 's'}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
          const Spacer(),
          Text(
            CurrencyFormatter.format(total),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _FacturaRow extends StatelessWidget {
  final FacturaModel factura;
  const _FacturaRow({required this.factura});

  Future<void> _open(BuildContext context, String? url, String label) async {
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label no disponible para esta factura.')),
      );
      return;
    }
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el $label.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isComision = factura.isComision;
    final accent = isComision ? AppTheme.accentColor : AppTheme.primaryColor;
    final fecha = factura.fechaTimbrado ?? factura.createdAt;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isComision ? Icons.percent_rounded : Icons.receipt_long_rounded,
                size: 18,
                color: accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isComision
                      ? 'Comisión ServiTec${factura.periodo != null ? ' · ${factura.periodo}' : ''}'
                      : 'CFDI de servicio',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Text(
                CurrencyFormatter.format(factura.total),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${DateFormat('dd/MM/yyyy HH:mm').format(fecha)}'
            '${factura.folioFiscal != null ? '  ·  ${factura.folioFiscal!.substring(0, 8)}…' : ''}'
            '${factura.isCancelled ? '  ·  CANCELADA' : ''}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: factura.isCancelled ? AppTheme.errorColor : AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _SmallBtn(
                icon: Icons.picture_as_pdf_outlined,
                label: 'PDF',
                color: accent,
                onTap: () => _open(context, factura.pdfUrl, 'PDF'),
              ),
              const SizedBox(width: 8),
              _SmallBtn(
                icon: Icons.code_rounded,
                label: 'XML',
                color: AppTheme.textSecondary,
                onTap: () => _open(context, factura.xmlUrl, 'XML'),
              ),
              if (factura.servicioId != null) ...[
                const SizedBox(width: 8),
                _SmallBtn(
                  icon: Icons.open_in_new_rounded,
                  label: 'Servicio',
                  color: AppTheme.textSecondary,
                  onTap: () => context.push('/service/${factura.servicioId}'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SmallBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : AppTheme.backgroundLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
