import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_model.dart';

class AdminValidationScreen extends StatelessWidget {
  const AdminValidationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Validar Técnicos')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('rol', isEqualTo: 'tecnico')
            .where('estadoValidacion', isEqualTo: 'pendiente')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_outlined,
                      size: 64, color: AppTheme.textTertiary),
                  const SizedBox(height: 16),
                  Text('No hay técnicos pendientes de validación',
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(color: AppTheme.textSecondary)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final tech = UserModel.fromFirestore(docs[index]);
              final data = docs[index].data() as Map<String, dynamic>;

              return Card(
                margin: EdgeInsets.zero,
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        AppTheme.warningColor.withValues(alpha: 0.1),
                    child: const Icon(Icons.person,
                        color: AppTheme.warningColor),
                  ),
                  title: Text(tech.fullName),
                  subtitle: Text(tech.email,
                      style: theme.textTheme.bodySmall),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Documents
                          _DocLink('INE', data['documentoINE']),
                          _DocLink('CURP', data['documentoCURP']),
                          _DocLink('Comprobante',
                              data['documentoComprobantedeDomicilio']),

                          if (data['certificaciones'] != null &&
                              (data['certificaciones'] as List).isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text('Certificaciones:',
                                style: theme.textTheme.titleSmall),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 80,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: (data['certificaciones'] as List)
                                    .map((url) => Padding(
                                          padding:
                                              const EdgeInsets.only(right: 8),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: CachedNetworkImage(
                                              imageUrl: url.toString(),
                                              width: 80,
                                              height: 80,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Action buttons
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _approve(context, tech.uid),
                                  icon: const Icon(Icons.check),
                                  label: const Text('Aprobar'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.successColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _reject(context, tech.uid),
                                  icon: const Icon(Icons.close,
                                      color: AppTheme.errorColor),
                                  label: const Text('Rechazar'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.errorColor,
                                    side: const BorderSide(
                                        color: AppTheme.errorColor),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _approve(BuildContext context, String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'estadoValidacion': 'aprobado',
      'fechaValidacion': Timestamp.now(),
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Técnico aprobado'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  Future<void> _reject(BuildContext context, String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'estadoValidacion': 'rechazado',
      'fechaValidacion': Timestamp.now(),
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Técnico rechazado'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }
}

class _DocLink extends StatelessWidget {
  final String label;
  final String? url;

  const _DocLink(this.label, this.url);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            url != null ? Icons.check_circle : Icons.cancel,
            size: 18,
            color: url != null ? AppTheme.successColor : AppTheme.textTertiary,
          ),
          const SizedBox(width: 8),
          Text('$label: ',
              style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(
            url != null ? 'Subido' : 'No subido',
            style: TextStyle(
              color:
                  url != null ? AppTheme.successColor : AppTheme.textTertiary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
