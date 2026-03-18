import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_text_field.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isTechnician = false;
  final List<String> _selectedEspecialidades = [];

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onSubmit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_isTechnician) {
      if (_selectedEspecialidades.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona al menos una especialidad')),
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Cuenta'),
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Role selector
                Text('Tipo de cuenta', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _RoleCard(
                        title: 'Cliente',
                        subtitle: 'Solicitar servicios',
                        icon: Icons.person_outline,
                        isSelected: !_isTechnician,
                        onTap: () => setState(() => _isTechnician = false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _RoleCard(
                        title: 'Técnico',
                        subtitle: 'Ofrecer servicios',
                        icon: Icons.engineering_outlined,
                        isSelected: _isTechnician,
                        onTap: () => setState(() => _isTechnician = true),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Name fields
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _nombreController,
                        label: 'Nombre',
                        prefixIcon: Icons.person_outline,
                        textInputAction: TextInputAction.next,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Requerido' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _apellidoController,
                        label: 'Apellido',
                        textInputAction: TextInputAction.next,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Requerido' : null,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                AppTextField(
                  controller: _emailController,
                  label: 'Correo electrónico',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requerido';
                    if (!v.contains('@')) return 'Correo inválido';
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                AppTextField(
                  controller: _telefonoController,
                  label: 'Teléfono',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Requerido' : null,
                ),

                const SizedBox(height: 16),

                AppTextField(
                  controller: _passwordController,
                  label: 'Contraseña',
                  prefixIcon: Icons.lock_outlined,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  suffix: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requerido';
                    if (v.length < 6) return 'Mínimo 6 caracteres';
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                AppTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirmar Contraseña',
                  prefixIcon: Icons.lock_outlined,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  validator: (v) {
                    if (v != _passwordController.text) {
                      return 'Las contraseñas no coinciden';
                    }
                    return null;
                  },
                ),

                // Technician specialties
                if (_isTechnician) ...[
                  const SizedBox(height: 24),
                  Text('Especialidades', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Selecciona tus áreas de expertise',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AppConstants.serviceCategories.map((cat) {
                      final isSelected = _selectedEspecialidades.contains(cat);
                      final label = AppConstants.categoryLabels[cat] ?? cat;
                      final emoji = AppConstants.categoryIcons[cat] ?? '';
                      return FilterChip(
                        label: Text('$emoji $label'),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedEspecialidades.add(cat);
                            } else {
                              _selectedEspecialidades.remove(cat);
                            }
                          });
                        },
                        selectedColor:
                            AppTheme.primaryColor.withValues(alpha: 0.15),
                        checkmarkColor: AppTheme.primaryColor,
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 32),

                // Submit
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    final isLoading = state is AuthLoading;
                    return ElevatedButton(
                      onPressed: isLoading ? null : _onSubmit,
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isTechnician
                                  ? 'Registrarme como Técnico'
                                  : 'Registrarme como Cliente',
                            ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '¿Ya tienes cuenta? ',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('Inicia Sesión'),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textTertiary,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
              ),
            ),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
