import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;
  bool _emailFocused = false;
  bool _passwordFocused = false;

  late AnimationController _bgAnimController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _bgAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutQuart,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutQuart,
    ));

    _emailFocus.addListener(() {
      setState(() => _emailFocused = _emailFocus.hasFocus);
    });
    _passwordFocus.addListener(() {
      setState(() => _passwordFocused = _passwordFocus.hasFocus);
    });

    _fadeController.forward();
  }

  @override
  void dispose() {
    _bgAnimController.dispose();
    _fadeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _onSubmit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
            AuthSignInRequested(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.error_outline_rounded,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        state.message,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFFE53935),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 8,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // === ANIMATED MESH GRADIENT BACKGROUND ===
            AnimatedBuilder(
              animation: _bgAnimController,
              builder: (context, _) {
                final v = _bgAnimController.value;
                return CustomPaint(
                  painter: _MeshGradientPainter(v),
                  size: Size.infinite,
                );
              },
            ),

            // === FLOATING LIGHT ORBS ===
            ..._buildOrbs(size),

            // === NOISE TEXTURE OVERLAY ===
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.1),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.2),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),

            // === MAIN CONTENT ===
            SafeArea(
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomPad),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: size.height -
                          MediaQuery.of(context).padding.top -
                          MediaQuery.of(context).padding.bottom,
                    ),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            children: [
                              SizedBox(height: size.height * 0.08),

                              // === LOGO ===
                              _buildLogo(),
                              const SizedBox(height: 28),

                              // === BRAND ===
                              Text(
                                'ServiTec',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -1.5,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Servicios profesionales a tu alcance',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white.withValues(alpha: 0.5),
                                  letterSpacing: 0.2,
                                ),
                              ),

                              SizedBox(height: size.height * 0.06),

                              // === FORM ===
                              Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    // Email
                                    _GlassInput(
                                      controller: _emailController,
                                      focusNode: _emailFocus,
                                      isFocused: _emailFocused,
                                      hint: 'Correo electrónico',
                                      icon: Icons.mail_outline_rounded,
                                      keyboardType:
                                          TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      onSubmitted: (_) =>
                                          _passwordFocus.requestFocus(),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Ingresa tu correo';
                                        }
                                        if (!value.contains('@')) {
                                          return 'Correo inválido';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 14),
                                    // Password
                                    _GlassInput(
                                      controller: _passwordController,
                                      focusNode: _passwordFocus,
                                      isFocused: _passwordFocused,
                                      hint: 'Contraseña',
                                      icon: Icons.lock_outline_rounded,
                                      obscureText: _obscurePassword,
                                      textInputAction: TextInputAction.done,
                                      onSubmitted: (_) => _onSubmit(),
                                      suffix: GestureDetector(
                                        onTap: () => setState(() =>
                                            _obscurePassword =
                                                !_obscurePassword),
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.only(right: 16),
                                          child: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_outlined
                                                : Icons
                                                    .visibility_off_outlined,
                                            color: Colors.white
                                                .withValues(alpha: 0.35),
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Ingresa tu contraseña';
                                        }
                                        if (value.length < 6) {
                                          return 'Mínimo 6 caracteres';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 14),

                              // === FORGOT PASSWORD ===
                              Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onTap: () => context.push('/forgot-password'),
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    child: Text(
                                      '¿Olvidaste tu contraseña?',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF5BEAD6),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 28),

                              // === LOGIN BUTTON ===
                              BlocBuilder<AuthBloc, AuthState>(
                                builder: (context, state) {
                                  final isLoading = state is AuthLoading;
                                  return _PremiumButton(
                                    label: 'Iniciar Sesión',
                                    isLoading: isLoading,
                                    onTap: isLoading ? null : _onSubmit,
                                  );
                                },
                              ),

                              SizedBox(height: size.height * 0.06),

                              // === DIVIDER ===
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.transparent,
                                            Colors.white
                                                .withValues(alpha: 0.15),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    child: Text(
                                      'o',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        color: Colors.white
                                            .withValues(alpha: 0.3),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white
                                                .withValues(alpha: 0.15),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 24),

                              // === REGISTER LINK ===
                              GestureDetector(
                                onTap: () => context.push('/register'),
                                child: Container(
                                  width: double.infinity,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.12),
                                    ),
                                    color:
                                        Colors.white.withValues(alpha: 0.04),
                                  ),
                                  child: Center(
                                    child: RichText(
                                      text: TextSpan(
                                        text: '¿No tienes cuenta?  ',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          color: Colors.white
                                              .withValues(alpha: 0.45),
                                        ),
                                        children: [
                                          TextSpan(
                                            text: 'Regístrate',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color:
                                                  const Color(0xFF5BEAD6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
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
            ),
          ],
        ),
      ),
    );
  }

  // === LOGO WIDGET ===
  Widget _buildLogo() {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A6B6E),
            Color(0xFF14BDAC),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF14BDAC).withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Icon(
        Icons.build_circle_outlined,
        size: 36,
        color: Colors.white,
      ),
    );
  }

  // === FLOATING ORBS ===
  List<Widget> _buildOrbs(Size size) {
    return [
      _AnimatedOrb(
        controller: _bgAnimController,
        orbSize: 220,
        color: const Color(0xFF14BDAC).withValues(alpha: 0.07),
        baseTop: -70,
        baseRight: -50,
        phaseOffset: 0,
      ),
      _AnimatedOrb(
        controller: _bgAnimController,
        orbSize: 180,
        color: const Color(0xFF0A6B6E).withValues(alpha: 0.09),
        baseBottom: 80,
        baseLeft: -70,
        phaseOffset: 0.4,
      ),
      _AnimatedOrb(
        controller: _bgAnimController,
        orbSize: 120,
        color: const Color(0xFFFF6B35).withValues(alpha: 0.04),
        baseTop: size.height * 0.35,
        baseRight: -30,
        phaseOffset: 0.7,
      ),
    ];
  }
}

// ============================================================
// GLASS INPUT FIELD — fully isolated from theme
// ============================================================
class _GlassInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isFocused;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final void Function(String)? onSubmitted;

  const _GlassInput({
    required this.controller,
    required this.focusNode,
    required this.isFocused,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.suffix,
    this.validator,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFocused
              ? const Color(0xFF5BEAD6).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.1),
          width: 1.5,
        ),
        color: isFocused
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.06),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: const Color(0xFF14BDAC).withValues(alpha: 0.1),
                  blurRadius: 20,
                  spreadRadius: -2,
                ),
              ]
            : null,
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
          color: Colors.white.withValues(alpha: 0.95),
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        cursorColor: const Color(0xFF5BEAD6),
        cursorWidth: 1.5,
        decoration: InputDecoration(
          filled: false,
          hintText: hint,
          hintStyle: GoogleFonts.plusJakartaSans(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Icon(
              icon,
              color: isFocused
                  ? const Color(0xFF5BEAD6)
                  : Colors.white.withValues(alpha: 0.3),
              size: 20,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 48),
          suffixIcon: suffix,
          suffixIconConstraints: const BoxConstraints(minWidth: 48),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 0, vertical: 18),
          errorStyle: GoogleFonts.plusJakartaSans(
            color: const Color(0xFFFF8A80),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PREMIUM GRADIENT BUTTON
// ============================================================
class _PremiumButton extends StatefulWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onTap;

  const _PremiumButton({
    required this.label,
    required this.isLoading,
    this.onTap,
  });

  @override
  State<_PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<_PremiumButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: widget.onTap != null
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0D8B8F),
                      Color(0xFF14BDAC),
                      Color(0xFF5BEAD6),
                    ],
                    stops: [0.0, 0.5, 1.0],
                  )
                : LinearGradient(
                    colors: [
                      const Color(0xFF0D8B8F).withValues(alpha: 0.4),
                      const Color(0xFF14BDAC).withValues(alpha: 0.4),
                    ],
                  ),
            boxShadow: widget.onTap != null
                ? [
                    BoxShadow(
                      color:
                          const Color(0xFF14BDAC).withValues(alpha: 0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                      spreadRadius: -4,
                    ),
                    BoxShadow(
                      color:
                          const Color(0xFF0D8B8F).withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    widget.label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ANIMATED ORB
// ============================================================
class _AnimatedOrb extends StatelessWidget {
  final AnimationController controller;
  final double orbSize;
  final Color color;
  final double? baseTop;
  final double? baseBottom;
  final double? baseLeft;
  final double? baseRight;
  final double phaseOffset;

  const _AnimatedOrb({
    required this.controller,
    required this.orbSize,
    required this.color,
    this.baseTop,
    this.baseBottom,
    this.baseLeft,
    this.baseRight,
    required this.phaseOffset,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = (controller.value + phaseOffset) % 1.0;
        final dy = math.sin(t * 2 * math.pi) * 18;
        final dx = math.cos(t * 2 * math.pi) * 12;
        return Positioned(
          top: baseTop != null ? baseTop! + dy : null,
          bottom: baseBottom != null ? baseBottom! + dy : null,
          left: baseLeft != null ? baseLeft! + dx : null,
          right: baseRight != null ? baseRight! + dx : null,
          child: Container(
            width: orbSize,
            height: orbSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color,
                  color.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================================================
// MESH GRADIENT PAINTER — organic animated background
// ============================================================
class _MeshGradientPainter extends CustomPainter {
  final double t;
  _MeshGradientPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Base dark gradient
    final basePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF041216),
          Color(0xFF072A30),
          Color(0xFF0A3D42),
          Color(0xFF061A1E),
        ],
        stops: [0.0, 0.35, 0.65, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, basePaint);

    // Animated teal glow — top right
    final glow1Center = Offset(
      size.width * (0.75 + 0.1 * math.sin(t * 2 * math.pi)),
      size.height * (0.15 + 0.08 * math.cos(t * 2 * math.pi)),
    );
    final glow1Paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.8,
        colors: [
          const Color(0xFF14BDAC).withValues(alpha: 0.12),
          const Color(0xFF14BDAC).withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCenter(center: glow1Center, width: 400, height: 400),
      );
    canvas.drawRect(rect, glow1Paint);

    // Animated deep glow — bottom left
    final glow2Center = Offset(
      size.width * (0.2 + 0.08 * math.cos(t * 2 * math.pi + 1)),
      size.height * (0.8 + 0.06 * math.sin(t * 2 * math.pi + 1)),
    );
    final glow2Paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.7,
        colors: [
          const Color(0xFF0D7377).withValues(alpha: 0.15),
          const Color(0xFF0D7377).withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCenter(center: glow2Center, width: 350, height: 350),
      );
    canvas.drawRect(rect, glow2Paint);
  }

  @override
  bool shouldRepaint(_MeshGradientPainter old) => old.t != t;
}
