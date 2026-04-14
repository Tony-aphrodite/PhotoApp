import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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

class _CreateServiceScreenState extends State<CreateServiceScreen>
    with SingleTickerProviderStateMixin {
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

  late final AnimationController _animController;

  // Icon data for categories
  static const Map<String, IconData> _categoryIcons = {
    'electricidad': Icons.bolt_rounded,
    'plomeria': Icons.plumbing_rounded,
    'limpieza': Icons.cleaning_services_rounded,
    'pintura': Icons.format_paint_rounded,
    'carpinteria': Icons.carpenter_rounded,
    'cerrajeria': Icons.lock_rounded,
    'aire_acondicionado': Icons.ac_unit_rounded,
    'electrodomesticos': Icons.electrical_services_rounded,
    'jardineria': Icons.yard_rounded,
    'otro': Icons.handyman_rounded,
  };

  static const List<List<Color>> _categoryGradients = [
    [Color(0xFFFFB020), Color(0xFFFF6B35)],
    [Color(0xFF2979FF), Color(0xFF00B0FF)],
    [Color(0xFF00C853), Color(0xFF69F0AE)],
    [Color(0xFFAA00FF), Color(0xFFD500F9)],
    [Color(0xFF8D6E63), Color(0xFFBCAAA4)],
    [Color(0xFFFF1744), Color(0xFFFF8A80)],
    [Color(0xFF00BCD4), Color(0xFF84FFFF)],
    [Color(0xFFFF6D00), Color(0xFFFFAB40)],
    [Color(0xFF00C853), Color(0xFF76FF03)],
    [Color(0xFF546E7A), Color(0xFF90A4AE)],
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _loadTarifas();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
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
    _animController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_photos.length >= AppConstants.maxPhotosPerService) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximo 5 fotos por servicio')),
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Tomar foto',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.photo_library_rounded,
                    color: AppTheme.secondaryColor,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Elegir de galeria',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una categoria')),
      );
      return;
    }

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;
    final user = authState.user;

    setState(() => _isSubmitting = true);

    try {
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
            : 'Ubicacion por confirmar',
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
        await serviceRepo
            .updateService(createdService.id, {'fotos': photoUrls});
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
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 110,
            floating: false,
            pinned: true,
            backgroundColor: AppTheme.backgroundLight,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppTheme.softShadow,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: AppTheme.textPrimary,
                ),
              ),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Solicitar Servicio',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 48,
                      height: 3,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0D7377), Color(0xFF14BDAC)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- Section 1: Category ---
                _SectionHeader(
                  icon: Icons.category_rounded,
                  title: 'Categoria',
                  number: '1',
                ),
                const SizedBox(height: 14),
                _buildCategorySelector(),

                const SizedBox(height: 28),
                _buildSectionDivider(),
                const SizedBox(height: 28),

                // --- Section 2: Details ---
                _SectionHeader(
                  icon: Icons.description_rounded,
                  title: 'Detalles',
                  number: '2',
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _titleController,
                  label: 'Titulo del servicio',
                  hint: 'Ej: Reparacion de tuberia con fuga',
                  prefixIcon: Icons.title,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _descriptionController,
                  label: 'Descripcion del problema',
                  hint: 'Describe detalladamente el problema...',
                  maxLines: 4,
                  maxLength: AppConstants.maxDescriptionLength,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Requerido' : null,
                ),

                const SizedBox(height: 28),
                _buildSectionDivider(),
                const SizedBox(height: 28),

                // --- Section 3: Location ---
                _SectionHeader(
                  icon: Icons.location_on_rounded,
                  title: 'Ubicacion',
                  number: '3',
                ),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppTheme.softShadow,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: LocationPicker(
                      onLocationSelected: (result) {
                        _lat = result.latitude;
                        _lng = result.longitude;
                        _addressController.text = result.address;
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _addressController,
                  label: 'Direccion (ajustar si necesario)',
                  hint: 'Calle, numero, colonia, ciudad',
                  prefixIcon: Icons.edit_location_outlined,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Requerido' : null,
                ),

                const SizedBox(height: 28),
                _buildSectionDivider(),
                const SizedBox(height: 28),

                // --- Section 4: Urgency ---
                _SectionHeader(
                  icon: Icons.speed_rounded,
                  title: 'Urgencia',
                  number: '4',
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _PremiumUrgencyOption(
                        label: 'Normal',
                        icon: Icons.schedule_rounded,
                        isSelected: _urgency == AppConstants.urgencyNormal,
                        onTap: () {
                          setState(
                              () => _urgency = AppConstants.urgencyNormal);
                          _updateEstimation();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PremiumUrgencyOption(
                        label: 'Urgente',
                        subtitle: 'x1.5',
                        icon: Icons.flash_on_rounded,
                        isSelected: _urgency == AppConstants.urgencyUrgent,
                        onTap: () {
                          setState(
                              () => _urgency = AppConstants.urgencyUrgent);
                          _updateEstimation();
                        },
                        isUrgent: true,
                      ),
                    ),
                  ],
                ),

                // Cost Estimation Card
                if (_estimatedCost != null) ...[
                  const SizedBox(height: 20),
                  _buildCostEstimationCard(),
                ],

                const SizedBox(height: 28),
                _buildSectionDivider(),
                const SizedBox(height: 28),

                // --- Section 5: Photos ---
                _SectionHeader(
                  icon: Icons.photo_camera_rounded,
                  title:
                      'Fotos del problema (${_photos.length}/${AppConstants.maxPhotosPerService})',
                  number: '5',
                ),
                const SizedBox(height: 14),
                _buildPhotoSection(),

                const SizedBox(height: 36),

                // Submit button - gradient with glow
                _buildSubmitButton(),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionDivider() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            AppTheme.dividerColor,
            AppTheme.dividerColor,
            Colors.transparent,
          ],
          stops: const [0.0, 0.2, 0.8, 1.0],
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(
        AppConstants.serviceCategories.length,
        (index) {
          final cat = AppConstants.serviceCategories[index];
          final isSelected = _selectedCategory == cat;
          final label = AppConstants.categoryLabels[cat] ?? cat;
          final icon = _categoryIcons[cat] ?? Icons.handyman_rounded;
          final gradColors =
              _categoryGradients[index % _categoryGradients.length];
          final tarifa = _tarifas[cat];
          final tarifaText = tarifa != null
              ? '\$${tarifa.tarifaBase.toStringAsFixed(0)}'
              : '';

          return GestureDetector(
            onTap: () {
              setState(() => _selectedCategory = cat);
              _updateEstimation();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width: (MediaQuery.of(context).size.width - 50) / 2,
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: gradColors[0].withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                        ...AppTheme.softShadow,
                      ]
                    : AppTheme.softShadow,
                border: isSelected
                    ? Border.all(
                        color: gradColors[0].withValues(alpha: 0.4),
                        width: 1.5)
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isSelected
                            ? gradColors
                            : [
                                gradColors[0].withValues(alpha: 0.12),
                                gradColors[1].withValues(alpha: 0.06),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      size: 18,
                      color: isSelected ? Colors.white : gradColors[0],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w600,
                            color: isSelected
                                ? gradColors[0]
                                : AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (tarifaText.isNotEmpty)
                          Text(
                            tarifaText,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? gradColors[0].withValues(alpha: 0.7)
                                  : AppTheme.textTertiary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: gradColors),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCostEstimationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A2E36), Color(0xFF0D5C61), Color(0xFF14BDAC)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calculate_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Costo Estimado',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '\$${_estimatedCost!.toStringAsFixed(2)} USD',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                if (_urgency == AppConstants.urgencyUrgent)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Incluye recargo por urgencia (x1.5)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFFFD54F),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          SizedBox(
            height: 110,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // Add button - drag-and-drop style
                GestureDetector(
                  onTap: _showPhotoOptions,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.25),
                        width: 1.5,
                        strokeAlign: BorderSide.strokeAlignInside,
                      ),
                      color: AppTheme.primaryColor.withValues(alpha: 0.03),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primaryColor.withValues(alpha: 0.12),
                                AppTheme.secondaryColor
                                    .withValues(alpha: 0.06),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.add_a_photo_rounded,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Agregar',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Photo previews
                ..._photos.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Stack(
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(
                              entry.value,
                              width: 110,
                              height: 110,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _photos.removeAt(entry.key)),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.close_rounded,
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
          if (_photos.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Toca para agregar fotos del problema',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppTheme.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: _isSubmitting
            ? LinearGradient(
                colors: [
                  const Color(0xFF0D7377).withValues(alpha: 0.5),
                  const Color(0xFF14BDAC).withValues(alpha: 0.5),
                ],
              )
            : const LinearGradient(
                colors: [Color(0xFF0D7377), Color(0xFF14BDAC)],
              ),
        boxShadow: _isSubmitting
            ? []
            : [
                BoxShadow(
                  color: const Color(0xFF14BDAC).withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: const Color(0xFF0D7377).withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _isSubmitting ? null : _submit,
          child: Center(
            child: _isSubmitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _estimatedCost != null
                        ? 'Enviar Solicitud (\$${_estimatedCost!.toStringAsFixed(2)})'
                        : 'Enviar Solicitud',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String number;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.number,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D7377), Color(0xFF14BDAC)],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              number,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        const SizedBox(width: 6),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

class _PremiumUrgencyOption extends StatelessWidget {
  final String label;
  final String? subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isUrgent;

  const _PremiumUrgencyOption({
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
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white
              : AppTheme.backgroundLight,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isSelected ? [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
            ...AppTheme.softShadow,
          ] : [],
          border: isSelected
              ? Border.all(color: color.withValues(alpha: 0.3), width: 1.5)
              : Border.all(color: AppTheme.dividerColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.12)
                    : AppTheme.dividerColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 16,
                color: isSelected ? color : AppTheme.textTertiary,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isSelected ? color : AppTheme.textSecondary,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? color.withValues(alpha: 0.6)
                          : AppTheme.textTertiary,
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
