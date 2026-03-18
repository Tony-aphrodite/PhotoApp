import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/location_picker.dart';
import '../../../data/models/service_model.dart';
import '../../../data/repositories/service_repository.dart';
import '../../../data/repositories/storage_repository.dart';
import '../../../data/repositories/config_repository.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';

class CreateServiceScreen extends StatefulWidget {
  final String? initialCategory;

  const CreateServiceScreen({super.key, this.initialCategory});

  @override
  State<CreateServiceScreen> createState() => _CreateServiceScreenState();
}

class _CreateServiceScreenState extends State<CreateServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();

  String? _selectedCategory;
  String _urgency = AppConstants.urgencyNormal;
  final List<File> _photos = [];
  bool _isSubmitting = false;
  final _picker = ImagePicker();

  // Tariffs from Firestore
  Map<String, TarifaInfo> _tarifas = {};
  double? _estimatedCost;

  // Location from map
  double _lat = 19.4326;
  double _lng = -99.1332;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _loadTarifas();
  }

  Future<void> _loadTarifas() async {
    try {
      final tarifas = await context.read<ConfigRepository>().getTarifas();
      if (mounted) {
        setState(() {
          _tarifas = tarifas;
          _updateEstimation();
        });
      }
    } catch (_) {
      // Tariffs unavailable - estimation will be skipped
    }
  }

  void _updateEstimation() {
    if (_selectedCategory == null || _tarifas.isEmpty) {
      setState(() => _estimatedCost = null);
      return;
    }

    final tarifa = _tarifas[_selectedCategory];
    if (tarifa == null) {
      setState(() => _estimatedCost = null);
      return;
    }

    final configRepo = context.read<ConfigRepository>();
    setState(() {
      _estimatedCost = configRepo.calculateEstimation(
        tarifaBase: tarifa.tarifaBase,
        urgencia: _urgency,
        multiplicadorUrgente: tarifa.multiplicadorUrgente,
        recargoPorKm: tarifa.recargoPorKm,
      );
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_photos.length >= AppConstants.maxPhotosPerService) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Máximo 5 fotos por servicio')),
      );
      return;
    }

    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );

    if (picked != null) {
      setState(() => _photos.add(File(picked.path)));
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Tomar foto'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de galería'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una categoría')),
      );
      return;
    }

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;
    final user = authState.user;

    setState(() => _isSubmitting = true);

    try {
      // First create service without photos to get the real ID
      final service = ServiceModel(
        id: '',
        clienteId: user.uid,
        clienteNombre: user.fullName,
        clienteTelefono: user.telefono,
        titulo: _titleController.text.trim(),
        descripcion: _descriptionController.text.trim(),
        categoria: _selectedCategory!,
        urgencia: _urgency,
        ubicacion: GeoPoint(_lat, _lng),
        ubicacionTexto: _addressController.text.trim().isNotEmpty
            ? _addressController.text.trim()
            : 'Ubicación por confirmar',
        fotos: [],
        estado: AppConstants.statusPending,
        tipoAsignacion: AppConstants.assignmentAutomatic,
        estimacionCosto: _estimatedCost,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final serviceRepo = context.read<ServiceRepository>();
      final createdService = await serviceRepo.createService(service);

      // Upload photos with real service ID
      if (_photos.isNotEmpty) {
        final storageRepo = context.read<StorageRepository>();
        final photoUrls = await storageRepo.uploadServicePhotos(
          createdService.id,
          _photos,
        );
        await serviceRepo.updateService(createdService.id, {'fotos': photoUrls});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Servicio creado exitosamente'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitar Servicio'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Category Selector
              Text('Categoría', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppConstants.serviceCategories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  final label = AppConstants.categoryLabels[cat] ?? cat;
                  final emoji = AppConstants.categoryIcons[cat] ?? '';
                  final tarifa = _tarifas[cat];
                  final tarifaText = tarifa != null
                      ? ' (\$${tarifa.tarifaBase.toStringAsFixed(0)})'
                      : '';
                  return ChoiceChip(
                    label: Text('$emoji $label$tarifaText'),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() => _selectedCategory = cat);
                      _updateEstimation();
                    },
                    selectedColor:
                        AppTheme.primaryColor.withValues(alpha: 0.15),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // Title
              AppTextField(
                controller: _titleController,
                label: 'Título del servicio',
                hint: 'Ej: Reparación de tubería con fuga',
                prefixIcon: Icons.title,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Requerido' : null,
              ),

              const SizedBox(height: 16),

              // Description
              AppTextField(
                controller: _descriptionController,
                label: 'Descripción del problema',
                hint: 'Describe detalladamente el problema...',
                maxLines: 4,
                maxLength: AppConstants.maxDescriptionLength,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Requerido' : null,
              ),

              const SizedBox(height: 24),

              // Location Map
              Text('Ubicación', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              LocationPicker(
                onLocationSelected: (result) {
                  _lat = result.latitude;
                  _lng = result.longitude;
                  _addressController.text = result.address;
                },
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _addressController,
                label: 'Dirección (ajustar si necesario)',
                hint: 'Calle, número, colonia, ciudad',
                prefixIcon: Icons.edit_location_outlined,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Requerido' : null,
              ),

              const SizedBox(height: 24),

              // Urgency
              Text('Urgencia', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _UrgencyOption(
                      label: 'Normal',
                      icon: Icons.schedule,
                      isSelected: _urgency == AppConstants.urgencyNormal,
                      onTap: () {
                        setState(() => _urgency = AppConstants.urgencyNormal);
                        _updateEstimation();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _UrgencyOption(
                      label: 'Urgente',
                      subtitle: 'x1.5',
                      icon: Icons.flash_on,
                      isSelected: _urgency == AppConstants.urgencyUrgent,
                      onTap: () {
                        setState(() => _urgency = AppConstants.urgencyUrgent);
                        _updateEstimation();
                      },
                      isUrgent: true,
                    ),
                  ),
                ],
              ),

              // Cost Estimation Card
              if (_estimatedCost != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor.withValues(alpha: 0.08),
                        AppTheme.secondaryColor.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.calculate_outlined,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Costo Estimado',
                              style: theme.textTheme.bodySmall,
                            ),
                            Text(
                              '\$${_estimatedCost!.toStringAsFixed(2)} USD',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (_urgency == AppConstants.urgencyUrgent)
                              Text(
                                'Incluye recargo por urgencia (x1.5)',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppTheme.warningColor,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Photos
              Text(
                'Fotos del problema (${_photos.length}/${AppConstants.maxPhotosPerService})',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    // Add button
                    GestureDetector(
                      onTap: _showPhotoOptions,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined,
                                color: AppTheme.primaryColor),
                            const SizedBox(height: 4),
                            Text(
                              'Agregar',
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Photo previews
                    ..._photos.asMap().entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                entry.value,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => setState(
                                    () => _photos.removeAt(entry.key)),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close,
                                      size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Submit
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_estimatedCost != null
                        ? 'Enviar Solicitud (\$${_estimatedCost!.toStringAsFixed(2)})'
                        : 'Enviar Solicitud'),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _UrgencyOption extends StatelessWidget {
  final String label;
  final String? subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isUrgent;

  const _UrgencyOption({
    required this.label,
    this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.isUrgent = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isUrgent ? AppTheme.errorColor : AppTheme.primaryColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: isSelected ? color : AppTheme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? color : AppTheme.textTertiary),
            const SizedBox(width: 8),
            Column(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? color : AppTheme.textSecondary,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? color.withValues(alpha: 0.7) : AppTheme.textTertiary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
