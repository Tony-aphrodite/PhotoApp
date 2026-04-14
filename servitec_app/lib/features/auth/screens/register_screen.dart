import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _nombreFocus = FocusNode();
  final _apellidoFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _telefonoFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  bool _nombreFocused = false;
  bool _apellidoFocused = false;
  bool _emailFocused = false;
  bool _telefonoFocused = false;
  bool _passwordFocused = false;
  bool _confirmPasswordFocused = false;

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isTechnician = false;
  final List<String> _selectedEspecialidades = [];

  late AnimationController _bgAnimController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _bgAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));

    _nombreFocus.addListener(() {
      setState(() => _nombreFocused = _nombreFocus.hasFocus);
    });
    _apellidoFocus.addListener(() {
      setState(() => _apellidoFocused = _apellidoFocus.hasFocus);
    });
    _emailFocus.addListener(() {
      setState(() => _emailFocused = _emailFocus.hasFocus);
    });
    _telefonoFocus.addListener(() {
      setState(() => _telefonoFocused = _telefonoFocus.hasFocus);
    });
    _passwordFocus.addListener(() {
      setState(() => _passwordFocused = _passwordFocus.hasFocus);
    });
    _confirmPasswordFocus.addListener(() {
      setState(() => _confirmPasswordFocused = _confirmPasswordFocus.hasFocus);
    });

    _fadeController.forward();
  }

  @override
  void dispose() {
    _bgAnimController.dispose();
    _fadeController.dispose();
    _nombreController.dispose();
    _apellidoController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nombreFocus.dispose();
    _apellidoFocus.dispose();
    _emailFocus.dispose();
    _telefonoFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  void _onSubmit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_isTechnician) {
      if (_selectedEspecialidades.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Selecciona al menos una especialidad'),
                ),
              ],
            ),
            backgroundColor: AppTheme.warningColor,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        return;
      }
      context.read<AuthBloc>().add(
            AuthRegisterTechnicianRequested(
              email: _emailController.text.trim(),
              password: _passwordController.text,
              nombre: _nombreController.text.trim(),
              apellido: _apellidoController.text.trim(),
              telefono: _telefonoController.text.trim(),
              especialidades: _selectedEspecialidades,
            ),
          );
    } else {
      context.read<AuthBloc>().add(
            AuthRegisterClientRequested(
              email: _emailController.text.trim(),
              password: _passwordController.text,
              nombre: _nombreController.text.trim(),
              apellido: _apellidoController.text.trim(),
              telefono: _telefonoController.text.trim(),
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text(state.message)),
                  ],
                ),
                backgroundColor: AppTheme.errorColor,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        },
        child: Stack(
          children: [
            // Animated gradient background
            AnimatedBuilder(
              animation: _bgAnimController,
              builder: (context, _) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(
                        math.cos(_bgAnimController.value * 2 * math.pi) * 0.5,
                        -1.0,
                      ),
                      end: Alignment(
                        math.sin(_bgAnimController.value * 2 * math.pi) * 0.5,
                        1.0,
                      ),
                      colors: const [
                        Color(0xFF061A1E),
                        Color(0xFF0A3D42),
                        Color(0xFF0D5C61),
                        Color(0xFF0A2E36),
                      ],
                      stops: const [0.0, 0.3, 0.6, 1.0],
                    ),
                  ),
                );
              },
            ),

            // Floating orbs
            ..._buildFloatingOrbs(size),

            // Main content
            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 20),

                            // Back button
                            Align(
                              alignment: Alignment.centerLeft,
                              child: GestureDetector(
                                onTap: () => context.pop(),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.white.withValues(alpha: 0.05),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.08),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: Colors.white.withValues(alpha: 0.7),
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Title
                            Text(
                              'Crear Cuenta',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Completa tus datos para comenzar',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withValues(alpha: 0.5),
                                letterSpacing: 0.3,
                              ),
                            ),

                            const SizedBox(height: 32),

                            // Role selector
                            Text(
                              'Tipo de cuenta',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.7),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildRoleCard(
                                    title: 'Cliente',
                                    subtitle: 'Solicitar servicios',
                                    icon: Icons.person_outline_rounded,
                                    isSelected: !_isTechnician,
                                    onTap: () => setState(() => _isTechnician = false),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildRoleCard(
                                    title: 'T\u00e9cnico',
                                    subtitle: 'Ofrecer servicios',
                                    icon: Icons.engineering_outlined,
                                    isSelected: _isTechnician,
                                    onTap: () => setState(() => _isTechnician = true),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 28),

                            // Name fields
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInputField(
                                    controller: _nombreController,
                                    focusNode: _nombreFocus,
                                    isFocused: _nombreFocused,
                                    hint: 'Nombre',
                                    icon: Icons.person_outline_rounded,
                                    textInputAction: TextInputAction.next,
                                    onSubmitted: (_) => _apellidoFocus.requestFocus(),
                                    validator: (v) =>
                                        v == null || v.isEmpty ? 'Requerido' : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildInputField(
                                    controller: _apellidoController,
                                    focusNode: _apellidoFocus,
                                    isFocused: _apellidoFocused,
                                    hint: 'Apellido',
                                    icon: Icons.person_outline_rounded,
                                    textInputAction: TextInputAction.next,
                                    onSubmitted: (_) => _emailFocus.requestFocus(),
                                    validator: (v) =>
                                        v == null || v.isEmpty ? 'Requerido' : null,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            _buildInputField(
                              controller: _emailController,
                              focusNode: _emailFocus,
                              isFocused: _emailFocused,
                              hint: 'Correo electr\u00f3nico',
                              icon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => _telefonoFocus.requestFocus(),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Requerido';
                                if (!v.contains('@')) return 'Correo inv\u00e1lido';
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            _buildInputField(
                              controller: _telefonoController,
                              focusNode: _telefonoFocus,
                              isFocused: _telefonoFocused,
                              hint: 'Tel\u00e9fono',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => _passwordFocus.requestFocus(),
                              validator: (v) =>
                                  v == null || v.isEmpty ? 'Requerido' : null,
                            ),

                            const SizedBox(height: 16),

                            _buildInputField(
                              controller: _passwordController,
                              focusNode: _passwordFocus,
                              isFocused: _passwordFocused,
                              hint: 'Contrase\u00f1a',
                              icon: Icons.lock_outline_rounded,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => _confirmPasswordFocus.requestFocus(),
                              suffix: GestureDetector(
                                onTap: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                                child: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: Colors.white.withValues(alpha: 0.4),
                                  size: 20,
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Requerido';
                                if (v.length < 6) return 'M\u00ednimo 6 caracteres';
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            _buildInputField(
                              controller: _confirmPasswordController,
                              focusNode: _confirmPasswordFocus,
                              isFocused: _confirmPasswordFocused,
                              hint: 'Confirmar Contrase\u00f1a',
                              icon: Icons.lock_outline_rounded,
                              obscureText: _obscureConfirm,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _onSubmit(),
                              suffix: GestureDetector(
                                onTap: () => setState(
                                    () => _obscureConfirm = !_obscureConfirm),
                                child: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: Colors.white.withValues(alpha: 0.4),
                                  size: 20,
                                ),
                              ),
                              validator: (v) {
                                if (v != _passwordController.text) {
                                  return 'Las contrase\u00f1as no coinciden';
                                }
                                return null;
                              },
                            ),

                            // Technician specialties
                            if (_isTechnician) ...[
                              const SizedBox(height: 28),
                              Text(
                                'Especialidades',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.7),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Selecciona tus \u00e1reas de expertise',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.4),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: AppConstants.serviceCategories.map((cat) {
                                  final isSelected =
                                      _selectedEspecialidades.contains(cat);
                                  final label =
                                      AppConstants.categoryLabels[cat] ?? cat;
                                  final emoji =
                                      AppConstants.categoryIcons[cat] ?? '';
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedEspecialidades.remove(cat);
                                        } else {
                                          _selectedEspecialidades.add(cat);
                                        }
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: isSelected
                                            ? AppTheme.secondaryColor
                                                .withValues(alpha: 0.15)
                                            : Colors.white.withValues(alpha: 0.05),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppTheme.secondaryColor
                                                  .withValues(alpha: 0.5)
                                              : Colors.white
                                                  .withValues(alpha: 0.08),
                                          width: isSelected ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isSelected)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(right: 6),
                                              child: Icon(
                                                Icons.check_rounded,
                                                size: 16,
                                                color: AppTheme.secondaryColor,
                                              ),
                                            ),
                                          Text(
                                            '$emoji $label',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 13,
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,
                                              color: isSelected
                                                  ? AppTheme.secondaryColor
                                                  : Colors.white
                                                      .withValues(alpha: 0.6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],

                            const SizedBox(height: 32),

                            // Submit button
                            BlocBuilder<AuthBloc, AuthState>(
                              builder: (context, state) {
                                final isLoading = state is AuthLoading;
                                return _buildGradientButton(
                                  onTap: isLoading ? null : _onSubmit,
                                  isLoading: isLoading,
                                  label: _isTechnician
                                      ? 'Registrarme como T\u00e9cnico'
                                      : 'Registrarme como Cliente',
                                );
                              },
                            ),

                            const SizedBox(height: 24),

                            // Login link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '\u00bfYa tienes cuenta?  ',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => context.pop(),
                                  child: Text(
                                    'Inicia Sesi\u00f3n',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.secondaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected
              ? AppTheme.secondaryColor.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: isSelected
                ? AppTheme.secondaryColor.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.secondaryColor.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: isSelected
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF0D7377),
                          Color(0xFF14BDAC),
                        ],
                      )
                    : null,
                color: isSelected ? null : Colors.white.withValues(alpha: 0.06),
              ),
              child: Icon(
                icon,
                size: 24,
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? AppTheme.secondaryColor
                    : Colors.white.withValues(alpha: 0.7),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Colors.white.withValues(alpha: 0.4),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isFocused,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    Widget? suffix,
    String? Function(String?)? validator,
    void Function(String)? onSubmitted,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFocused
              ? AppTheme.secondaryColor.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.08),
          width: isFocused ? 1.5 : 1,
        ),
        color: Colors.white.withValues(alpha: isFocused ? 0.08 : 0.05),
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onFieldSubmitted: onSubmitted,
        validator: validator,
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        cursorColor: AppTheme.secondaryColor,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.plusJakartaSans(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 15,
          ),
          prefixIcon: Icon(
            icon,
            color: isFocused
                ? AppTheme.secondaryColor
                : Colors.white.withValues(alpha: 0.3),
            size: 20,
          ),
          suffixIcon: suffix != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: suffix,
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          errorStyle: GoogleFonts.plusJakartaSans(
            color: const Color(0xFFFF6B6B),
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildGradientButton({
    required VoidCallback? onTap,
    required bool isLoading,
    required String label,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: onTap != null
              ? const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFF0D7377),
                    Color(0xFF14BDAC),
                  ],
                )
              : LinearGradient(
                  colors: [
                    const Color(0xFF0D7377).withValues(alpha: 0.5),
                    const Color(0xFF14BDAC).withValues(alpha: 0.5),
                  ],
                ),
          boxShadow: onTap != null
              ? [
                  BoxShadow(
                    color: AppTheme.secondaryColor.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }

  List<Widget> _buildFloatingOrbs(Size size) {
    return [
      _buildOrb(
        size: size,
        orbSize: 200,
        color: AppTheme.secondaryColor.withValues(alpha: 0.06),
        top: -60,
        right: -40,
        phaseOffset: 0,
      ),
      _buildOrb(
        size: size,
        orbSize: 160,
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        bottom: 100,
        left: -60,
        phaseOffset: 0.5,
      ),
      _buildOrb(
        size: size,
        orbSize: 100,
        color: AppTheme.accentColor.withValues(alpha: 0.04),
        top: size.height * 0.3,
        right: -30,
        phaseOffset: 0.3,
      ),
      _buildOrb(
        size: size,
        orbSize: 120,
        color: AppTheme.secondaryColor.withValues(alpha: 0.05),
        bottom: 300,
        right: -50,
        phaseOffset: 0.7,
      ),
    ];
  }

  Widget _buildOrb({
    required Size size,
    required double orbSize,
    required Color color,
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double phaseOffset,
  }) {
    return AnimatedBuilder(
      animation: _bgAnimController,
      builder: (context, _) {
        final t = (_bgAnimController.value + phaseOffset) % 1.0;
        return Positioned(
          top: top != null ? top + math.sin(t * 2 * math.pi) * 20 : null,
          bottom:
              bottom != null ? bottom + math.cos(t * 2 * math.pi) * 20 : null,
          left: left != null ? left + math.sin(t * 2 * math.pi) * 15 : null,
          right:
              right != null ? right + math.cos(t * 2 * math.pi) * 15 : null,
          child: Container(
            width: orbSize,
            height: orbSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
        );
      },
    );
  }
}
