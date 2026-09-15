import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/service_card.dart';
import '../../../data/models/quotation_model.dart';
import '../../../data/models/service_model.dart';
import '../../../data/models/work_stop.dart';
import '../../../data/repositories/service_flow_repository.dart';

/// Everything about a service's quotation and work flow on its detail screen:
/// the quotation history, a stopped job's evidence, and the one or two actions
/// that make sense for this viewer in this state.
///
/// Each action calls a Cloud Function; the screen above listens to the service
/// document, so the panel redraws itself once the server has moved the state.
class ServiceFlowPanel extends StatefulWidget {
  final ServiceModel service;
  final String viewerUid;
  final bool isClient;
  final bool isTechnician;
  final bool isAdmin;

  const ServiceFlowPanel({
    super.key,
    required this.service,
    required this.viewerUid,
    required this.isClient,
    required this.isTechnician,
    required this.isAdmin,
  });

  @override
  State<ServiceFlowPanel> createState() => _ServiceFlowPanelState();
}

class _ServiceFlowPanelState extends State<ServiceFlowPanel> {
  late Stream<List<QuotationModel>> _quotations;
  bool _busy = false;

  ServiceModel get s => widget.service;
  ServiceFlowRepository get _flow => context.read<ServiceFlowRepository>();

  @override
  void initState() {
    super.initState();
    _quotations = _flow.streamQuotations(
      servicioId: s.id,
      // Admins read every cotización; participants must filter by themselves.
      participantUid: widget.isAdmin && !widget.isClient && !widget.isTechnician
          ? null
          : widget.viewerUid,
      asTecnico: widget.isTechnician,
    );
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(
          SnackBar(content: Text(done), backgroundColor: AppTheme.successColor));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(e is FlowException ? e.message : 'Error: $e'),
        backgroundColor: AppTheme.errorColor,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String body, {String ok = 'Confirmar'}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
        title: Text(title,
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        content: Text(body,
            style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textSecondary, height: 1.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Volver')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            child: Text(ok, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return result == true;
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _workAction(String accion) async {
    final approved = CurrencyFormatter.format(s.costoFinal ?? 0);
    final (title, body, done) = switch (accion) {
      'iniciar' => (
          'Iniciar trabajo',
          'Confirma que estás en el domicilio y empiezas el trabajo aprobado ($approved).',
          'Trabajo iniciado.'
        ),
      'continuar_original' => (
          'Continuar con el trabajo original',
          'Terminarás solo el trabajo que el cliente aprobó originalmente, por $approved. '
              'Hazlo únicamente si es técnicamente posible y seguro.',
          'Continúas con el trabajo original.'
        ),
      _ => (
          'Marcar como terminado',
          'El cliente deberá pagar $approved, el monto que aprobó.',
          'Trabajo terminado. Le avisamos al cliente para que pague.'
        ),
    };
    if (!await _confirm(title, body)) return;
    await _run(() async {
      await _flow.workAction(s.id, accion);
      if (accion == 'iniciar') {
        await AnalyticsService.logServiceStarted(servicioId: s.id);
      } else if (accion == 'completar') {
        await AnalyticsService.logServiceCompleted(servicioId: s.id);
      }
    }, done);
  }

  Future<void> _acceptStop(WorkStop stop) async {
    final charged = stop.montoPropuesto >= 10;
    final ok = await _confirm(
      charged ? 'Aceptar monto' : 'Aceptar cierre',
      charged
          ? 'Aceptas pagar ${CurrencyFormatter.format(stop.montoPropuesto)} por el trabajo realizado.'
          : 'El servicio se cerrará sin cobro.',
      ok: 'Aceptar',
    );
    if (!ok) return;
    await _run(() => _flow.respondStop(servicioId: s.id, aceptar: true),
        charged ? 'Monto aceptado. Ya puedes pagar el servicio.' : 'Servicio cerrado.');
  }

  Future<void> _disputeStop() async {
    final comment = await _askText(
      title: 'No estoy de acuerdo',
      hint: 'Cuéntanos por qué no estás de acuerdo con el monto',
      ok: 'Enviar a ServiTec',
    );
    if (comment == null) return;
    await _run(
      () => _flow.respondStop(servicioId: s.id, aceptar: false, comentario: comment),
      'Enviado. ServiTec revisará el caso.',
    );
  }

  Future<void> _resolveDispute(WorkStop stop) async {
    final monto = TextEditingController(
        text: stop.montoPropuesto.toStringAsFixed(2));
    final nota = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Resolver disputa',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: monto,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                ],
                decoration: InputDecoration(
                  labelText: 'Monto final (MXN)',
                  prefixText: '\$ ',
                  helperText:
                      'Máximo ${CurrencyFormatter.format(stop.montoAprobadoPrevio)}. Menos de \$10 cierra sin cobro.',
                  helperMaxLines: 2,
                ),
                validator: (v) {
                  final m = double.tryParse(v ?? '');
                  if (m == null || m < 0) return 'Monto inválido';
                  if (m > stop.montoAprobadoPrevio) return 'Supera lo aprobado';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: nota,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Nota para cliente y técnico'),
                validator: (v) =>
                    (v?.trim().length ?? 0) < 5 ? 'Explica la resolución' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Resolver'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(
      () => _flow.resolveDispute(
        servicioId: s.id,
        monto: double.parse(monto.text),
        nota: nota.text.trim(),
      ),
      'Disputa resuelta.',
    );
  }

  Future<String?> _askText(
      {required String title, required String hint, required String ok}) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title,
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            maxLines: 4,
            maxLength: 1000,
            decoration: InputDecoration(hintText: hint),
            validator: (v) =>
                (v?.trim().length ?? 0) < 5 ? 'Escribe un poco más' : null,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: Text(ok),
          ),
        ],
      ),
    );
    return result == true ? controller.text.trim() : null;
  }

  // ---------------------------------------------------------------------------
  // Layout
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      _QuotationHistory(stream: _quotations),
      if (s.detencion != null) _StopCard(stop: s.detencion!, resolucionNota: s.resolucionNota),
      ..._actions(),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final c in children) ...[c, const SizedBox(height: 12)],
      ],
    );
  }

  List<Widget> _actions() {
    final approved = CurrencyFormatter.format(s.costoFinal ?? 0);

    if (widget.isTechnician) {
      switch (s.estado) {
        case AppConstants.statusAssigned:
          return [
            _Note('Revisa la solicitud y envía tu cotización. El cliente debe aprobarla antes de que inicies.'),
            _Primary('Enviar cotización', Icons.request_quote_outlined,
                () => context.push('/quotation/create/${s.id}')),
          ];
        case AppConstants.statusQuoteRejected:
          return [
            _Note('El cliente rechazó la cotización. Puedes enviar una nueva.'),
            _Primary('Enviar nueva cotización', Icons.request_quote_outlined,
                () => context.push('/quotation/create/${s.id}')),
          ];
        case AppConstants.statusQuoteSent:
        case AppConstants.statusRevisionSent:
          return [_Note('Esperando la respuesta del cliente a tu cotización.')];
        case AppConstants.statusQuoteApproved:
        case 'en_reparacion':
          return [
            _Primary('Iniciar trabajo ($approved)', Icons.play_arrow_rounded,
                _busy ? null : () => _workAction('iniciar')),
          ];
        case AppConstants.statusInProgress:
          return [
            _Primary('Marcar como terminado', Icons.check_circle_outline_rounded,
                _busy ? null : () => _workAction('completar')),
            _Secondary('Encontré un problema adicional', Icons.edit_note_rounded,
                () => context.push('/quotation/create/${s.id}?revision=1')),
            _Danger('Detener trabajo', () => context.push('/service/${s.id}/stop')),
          ];
        case AppConstants.statusRevisionRejected:
          return [
            _Note('El cliente rechazó la cotización revisada. Termina solo el trabajo aprobado ($approved) '
                'si es técnicamente posible y seguro; si no, detén el trabajo y documenta el motivo.'),
            _Primary('Continuar con el trabajo original', Icons.play_arrow_rounded,
                _busy ? null : () => _workAction('continuar_original')),
            _Secondary('Enviar otra cotización revisada', Icons.edit_note_rounded,
                () => context.push('/quotation/create/${s.id}?revision=1')),
            _Danger('Detener trabajo', () => context.push('/service/${s.id}/stop')),
          ];
        case AppConstants.statusStopped:
          return [_Note('Esperando que el cliente acepte el monto propuesto.')];
        case AppConstants.statusDisputed:
          return [_Note('El cliente no aceptó el monto. ServiTec está revisando el caso.')];
      }
      return const [];
    }

    if (widget.isClient) {
      switch (s.estado) {
        case AppConstants.statusQuoteSent:
        case AppConstants.statusRevisionSent:
          final pending = s.cotizacionPendienteId;
          return [
            _Note(s.estado == AppConstants.statusRevisionSent
                ? 'El técnico encontró algo adicional y envió una cotización revisada. Tu aprobación es necesaria para continuar.'
                : 'El técnico envió su cotización. Revísala para aprobarla o rechazarla.'),
            if (pending != null)
              _Primary('Revisar cotización', Icons.receipt_long_outlined,
                  () => context.push('/quotation/review/$pending')),
          ];
        case AppConstants.statusStopped:
          final stop = s.detencion;
          if (stop == null) return const [];
          return [
            _Primary(
              stop.montoPropuesto >= 10
                  ? 'Aceptar ${CurrencyFormatter.format(stop.montoPropuesto)}'
                  : 'Aceptar cierre sin cobro',
              Icons.check_rounded,
              _busy ? null : () => _acceptStop(stop),
            ),
            _Secondary('No estoy de acuerdo', Icons.flag_outlined,
                _busy ? null : _disputeStop),
          ];
        case AppConstants.statusDisputed:
          return [_Note('ServiTec está revisando el caso y definirá el monto final.')];
        case AppConstants.statusCompleted:
        case AppConstants.statusPaymentPending:
          return [
            _Primary('Pagar $approved', Icons.payment_rounded,
                () => context.push('/payment/${s.id}'),
                color: AppTheme.successColor),
          ];
      }
      return const [];
    }

    if (widget.isAdmin && s.estado == AppConstants.statusDisputed && s.detencion != null) {
      return [
        _Primary('Resolver disputa', Icons.gavel_rounded,
            _busy ? null : () => _resolveDispute(s.detencion!)),
      ];
    }
    return const [];
  }
}

class _QuotationHistory extends StatelessWidget {
  final Stream<List<QuotationModel>> stream;

  const _QuotationHistory({required this.stream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<QuotationModel>>(
      stream: stream,
      builder: (context, snap) {
        final list = snap.data ?? const <QuotationModel>[];
        if (list.isEmpty) return const SizedBox.shrink();
        return _Card(
          title: 'Cotizaciones',
          icon: Icons.receipt_long_outlined,
          child: Column(
            children: [
              for (final q in list)
                InkWell(
                  onTap: () => context.push('/quotation/review/${q.id}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                q.isRevision
                                    ? 'Revisión · versión ${q.version}'
                                    : 'Cotización · versión ${q.version}',
                                style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary),
                              ),
                              Text(
                                _estadoLabel(q.estado),
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12, color: _estadoColor(q.estado)),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(q.total),
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            decoration: q.estado == 'rechazada'
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppTheme.textTertiary),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static String _estadoLabel(String e) => switch (e) {
        'aprobada' => 'Aprobada',
        'rechazada' => 'Rechazada',
        _ => 'Esperando respuesta',
      };

  static Color _estadoColor(String e) => switch (e) {
        'aprobada' => AppTheme.successColor,
        'rechazada' => AppTheme.errorColor,
        _ => AppTheme.warningColor,
      };
}

class _StopCard extends StatelessWidget {
  final WorkStop stop;
  final String? resolucionNota;

  const _StopCard({required this.stop, this.resolucionNota});

  @override
  Widget build(BuildContext context) {
    final text = GoogleFonts.plusJakartaSans(
        fontSize: 13, height: 1.5, color: AppTheme.textSecondary);
    return _Card(
      title: 'Trabajo detenido',
      icon: Icons.pan_tool_outlined,
      accent: AppTheme.errorColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(stop.motivoLabel,
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          Text(stop.descripcion, style: text),
          if (stop.fotos.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: stop.fotos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => GestureDetector(
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      child: InteractiveViewer(
                          child: ServiceCard.buildImage(stop.fotos[i])),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    child: SizedBox(
                        width: 80,
                        height: 80,
                        child: ServiceCard.buildImage(stop.fotos[i])),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Monto aprobado: ${CurrencyFormatter.format(stop.montoAprobadoPrevio)} · '
            'Propuesto por lo realizado: ${CurrencyFormatter.format(stop.montoPropuesto)}',
            style: text.copyWith(color: AppTheme.textPrimary),
          ),
          if (stop.comentarioCliente != null) ...[
            const SizedBox(height: 8),
            Text('Comentario del cliente: ${stop.comentarioCliente}', style: text),
          ],
          if (resolucionNota != null) ...[
            const SizedBox(height: 8),
            Text('Resolución de ServiTec: $resolucionNota',
                style: text.copyWith(color: AppTheme.textPrimary)),
          ],
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Color accent;

  const _Card({
    required this.title,
    required this.icon,
    required this.child,
    this.accent = AppTheme.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 8),
              Text(title,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final String text;
  const _Note(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.infoColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 18, color: AppTheme.infoColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, height: 1.5, color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }
}

class _Primary extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;

  const _Primary(this.label, this.icon, this.onPressed,
      {this.color = AppTheme.primaryColor});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(label,
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700, color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
        ),
      ),
    );
  }
}

class _Secondary extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _Secondary(this.label, this.icon, this.onPressed);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label,
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.primaryColor,
          side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
        ),
      ),
    );
  }
}

class _Danger extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _Danger(this.label, this.onPressed);

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.pan_tool_outlined, size: 18),
      label: Text(label,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
      style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
    );
  }
}
