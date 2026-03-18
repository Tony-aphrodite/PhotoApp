import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/storage_repository.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';

class TechnicianDocumentsScreen extends StatefulWidget {
  const TechnicianDocumentsScreen({super.key});

  @override
  State<TechnicianDocumentsScreen> createState() =>
      _TechnicianDocumentsScreenState();
}

class _TechnicianDocumentsScreenState extends State<TechnicianDocumentsScreen> {
  final _picker = ImagePicker();
  final Map<String, File?> _documents = {
    'INE': null,
    'CURP': null,
    'Comprobante de Domicilio': null,
  };
  final List<File> _certifications = [];
  bool _uploading = false;
  String? _currentStatus;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(authState.user.uid)
        .get();
    if (mounted) {
      setState(() {
        _currentStatus = doc.data()?['estadoValidacion'] ?? 'pendiente';
      });
    }
  }

  Future<void> _pickDocument(String docType) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _documents[docType] = File(picked.path));
    }
  }

  Future<void> _addCertification() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _certifications.add(File(picked.path)));
    }
  }

  Future<void> _submit() async {
    // Validate required docs
    if (_documents.values.any((f) => f == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sube todos los documentos requeridos')),
      );
      return;
    }

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;
    final uid = authState.user.uid;

    setState(() => _uploading = true);

    try {
      final storageRepo = context.read<StorageRepository>();
      final updates = <String, dynamic>{};

      // Upload each document
      for (final entry in _documents.entries) {
        if (entry.value != null) {
          final key = entry.key.replaceAll(' ', '_').toLowerCase();
          final url = await storageRepo.uploadProfilePhoto(
            '$uid/documentos/$key',
            entry.value!,
          );
          updates['documento${entry.key.replaceAll(' ', '')}'] = url;
        }
      }

      // Upload certifications
      if (_certifications.isNotEmpty) {
        final certUrls = await storageRepo.uploadServicePhotos(
          '$uid/certificaciones',
          _certifications,
        );
        updates['certificaciones'] = certUrls;
      }

      updates['estadoValidacion'] = 'pendiente';
      updates['fechaEnvioDocumentos'] = Timestamp.now();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update(updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Documentos enviados. Te notificaremos cuando sean aprobados.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        setState(() => _currentStatus = 'pendiente');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis Documentos')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status banner
            if (_currentStatus != null)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: _statusColor(_currentStatus!)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _statusColor(_currentStatus!)
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(_statusIcon(_currentStatus!),
                        color: _statusColor(_currentStatus!)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _statusMessage(_currentStatus!),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _statusColor(_currentStatus!),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Required documents
            Text('Documentos Requeridos',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),

            ..._documents.entries.map((entry) => _DocumentTile(
                  title: entry.key,
                  file: entry.value,
                  onPick: () => _pickDocument(entry.key),
                  required: true,
                )),

            const SizedBox(height: 20),

            // Certifications (optional)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Certificaciones (opcional)',
                    style: theme.textTheme.titleMedium),
                TextButton.icon(
                  onPressed: _addCertification,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_certifications.isEmpty)
              Text(
                'Agrega certificaciones para mejorar tu perfil',
                style: theme.textTheme.bodySmall,
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _certifications.asMap().entries.map((entry) {
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(entry.value,
                          width: 80, height: 80, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () => setState(
                            () => _certifications.removeAt(entry.key)),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                              color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),

            const SizedBox(height: 32),

            ElevatedButton.icon(
              onPressed: _uploading ? null : _submit,
              icon: _uploading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.upload_file),
              label: const Text('Enviar Documentos para Revisión'),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'aprobado':
        return AppTheme.successColor;
      case 'rechazado':
        return AppTheme.errorColor;
      default:
        return AppTheme.warningColor;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'aprobado':
        return Icons.verified;
      case 'rechazado':
        return Icons.cancel;
      default:
        return Icons.hourglass_empty;
    }
  }

  String _statusMessage(String status) {
    switch (status) {
      case 'aprobado':
        return 'Documentos aprobados. Tu cuenta está verificada.';
      case 'rechazado':
        return 'Documentos rechazados. Por favor, sube nuevamente.';
      default:
        return 'Documentos en revisión. Te notificaremos pronto.';
    }
  }
}

class _DocumentTile extends StatelessWidget {
  final String title;
  final File? file;
  final VoidCallback onPick;
  final bool required;

  const _DocumentTile({
    required this.title,
    this.file,
    required this.onPick,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: file != null
                ? AppTheme.successColor.withValues(alpha: 0.1)
                : AppTheme.dividerColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            file != null ? Icons.check_circle : Icons.description_outlined,
            color: file != null ? AppTheme.successColor : AppTheme.textTertiary,
          ),
        ),
        title: Text(title),
        subtitle: Text(
          file != null ? 'Documento cargado' : 'Requerido',
          style: TextStyle(
            color: file != null ? AppTheme.successColor : AppTheme.textTertiary,
            fontSize: 12,
          ),
        ),
        trailing: TextButton(
          onPressed: onPick,
          child: Text(file != null ? 'Cambiar' : 'Subir'),
        ),
      ),
    );
  }
}
