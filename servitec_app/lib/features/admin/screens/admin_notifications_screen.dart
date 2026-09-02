import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';

/// Compose and send a push notification to an audience, with a history of
/// what has been sent.
///
/// The send itself happens in the `sendAdminBroadcast` callable, which
/// re-checks the caller is an admin, resolves the audience, fans out via FCM
/// and writes the history row. This screen never touches FCM or user tokens.
class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  String _audience = 'todos';
  bool _sending = false;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _history;

  static const _audiences = <String, String>{
    'todos': 'Todos los usuarios',
    'clientes': 'Solo clientes',
    'tecnicos': 'Solo técnicos',
  };

  @override
  void initState() {
    super.initState();
    _history = FirebaseFirestore.instance
        .collection('notificaciones_admin')
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un título y un mensaje.')),
      );
      return;
    }

    // A broadcast cannot be unsent. Make the admin read the audience back.
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: Text('Enviar notificación',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        content: Text(
          'Se enviará a: ${_audiences[_audience]}.\n\n"$title"\n$body',
          style: GoogleFonts.plusJakartaSans(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('sendAdminBroadcast')
          .call<Map<String, dynamic>>({
        'audience': _audience,
        'title': title,
        'body': body,
      });
      final n = res.data['recipientCount'] ?? 0;
      _title.clear();
      _body.clear();
      messenger.showSnackBar(SnackBar(
        content: Text('Enviada a $n usuario${n == 1 ? '' : 's'}.'),
        backgroundColor: AppTheme.successColor,
      ));
    } on FirebaseFunctionsException catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(e.message ?? 'No se pudo enviar (${e.code}).'),
        backgroundColor: AppTheme.errorColor,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('No se pudo enviar: $e'),
        backgroundColor: AppTheme.errorColor,
      ));
    } finally {
      if (mounted) setState(() => _sending = false);
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
          'Notificaciones',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              boxShadow: AppTheme.softShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nueva notificación',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _audience,
                  decoration: const InputDecoration(labelText: 'Enviar a'),
                  items: _audiences.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) => setState(() => _audience = v ?? 'todos'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _title,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Título'),
                ),
                TextField(
                  controller: _body,
                  maxLength: 400,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Mensaje'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(_sending ? 'Enviando…' : 'Enviar'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Historial',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _history,
            builder: (context, snap) {
              final docs = snap.data?.docs ?? const [];
              if (docs.isEmpty) {
                return Text('Aún no se ha enviado ninguna.',
                    style: GoogleFonts.plusJakartaSans(color: AppTheme.textTertiary));
              }
              return Column(
                children: docs.map((d) {
                  final m = d.data();
                  final when = (m['createdAt'] as Timestamp?)?.toDate();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m['title'] ?? '',
                            style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(m['body'] ?? '',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 13, color: AppTheme.textSecondary)),
                        const SizedBox(height: 6),
                        Text(
                          '${_audiences[m['audience']] ?? m['audience']}  ·  ${m['recipientCount'] ?? 0} destinatarios'
                          '${when != null ? '  ·  ${DateFormat('dd/MM HH:mm').format(when)}' : ''}',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 11, color: AppTheme.textTertiary),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
