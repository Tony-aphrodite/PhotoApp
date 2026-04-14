import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _emailFocus = FocusNode();
  bool _emailFocused = false;

  late AnimationController _bgAnimController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

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

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _emailFocus.addListener(() {
      setState(() => _emailFocused = _emailFocus.hasFocus);
    });

    _fadeController.forward();
  }

  @override
  void dispose() {
    _bgAnimController.dispose();
    _fadeController.dispose();
    _glowController.dispose();
    _emailController.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthPasswordResetSent) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Se envi\u00f3 un correo para recuperar tu contrase\u00f1a'),
                    ),
                  ],
                ),
                backgroundColor: AppTheme.successColor,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
            context.pop();
          } else if (state is AuthError) {
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
                child: SizedBox(
                  height: size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
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

                              const Spacer(flex: 2),

                              // Lock icon with glow
                              Center(
                                child: AnimatedBuilder(
                                  animation: _glowAnimation,
                                  builder: (context, child) {
                                    return Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(30),
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            AppTheme.secondaryColor
                                                .withValues(alpha: 0.15),
                                            AppTheme.primaryColor
                                                .withValues(alpha: 0.15),
                                          ],
                                        ),
                                        border: Border.all(
                                          color: AppTheme.secondaryColor
                                              .withValues(alpha: 0.25),
                                          width: 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppTheme.secondaryColor
                                                .withValues(
                                                    alpha: _glowAnimation.value *
                                                        0.3),
                                            blurRadius: 40,
                                            spreadRadius: 5,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.lock_reset_rounded,
                                        size: 44,
                                        color: AppTheme.secondaryColor,
                                      ),
                                    );
                                  },
                                ),
                              ),

                              const SizedBox(height: 36),

                              // Title
                              Text(
                                'Recuperar Contrase\u00f1a',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -1.0,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'Ingresa tu correo electr\u00f3nico y te enviaremos un enlace para restablecer tu contrase\u00f1a.',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white.withValues(alpha: 0.5),
                                    height: 1.5,
                                    letterSpacing: 0.2,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),

                              const SizedBox(height: 40),

                              // Email field
                              _buildInputField(
                                controller: _emailController,
                                focusNode: _emailFocus,
                                isFocused: _emailFocused,
                                hint: 'Correo electr\u00f3nico',
                                icon: Icons.mail_outline_rounded,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) {
                                  if (_formKey.currentState?.validate() ??
                                      false) {
                                    context.read<AuthBloc>().add(
                                          AuthResetPasswordRequested(
                                            email:
                                                _emailController.text.trim(),
                                          ),
                                        );
                                  }
                                },
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Requerido';
                                  if (!v.contains('@')) {
                                    return 'Correo inv\u00e1lido';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 28),

                              // Submit button
                              BlocBuilder<AuthBloc, AuthState>(
                                builder: (context, state) {
                                  final isLoading = state is AuthLoading;
                                  return _buildGradientButton(
                                    onTap: isLoading
                                        ? null
                                        : () {
                                            if (_formKey.currentState
                                                    ?.validate() ??
                                                false) {
                                              context.read<AuthBloc>().add(
                                                    AuthResetPasswordRequested(
                                                      email: _emailController
                                                          .text
                                                          .trim(),
                                                    ),
                                                  );
                                            }
                                          },
                                    isLoading: isLoading,
                                    label: 'Enviar Enlace',
                                  );
                                },
                              ),

                              const SizedBox(height: 24),

                              // Back to login link
                              Center(
                                child: GestureDetector(
                                  onTap: () => context.pop(),
                                  child: Text(
                                    'Volver al inicio de sesi\u00f3n',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.secondaryColor
                                          .withValues(alpha: 0.8),
                                    ),
                                  ),
                                ),
                              ),

                              const Spacer(flex: 3),
                            ],
                          ),
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
