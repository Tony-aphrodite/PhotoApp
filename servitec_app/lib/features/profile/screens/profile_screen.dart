import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/bloc/auth_state.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = context.watch<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return const SizedBox();
    final user = authState.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar
            CircleAvatar(
              radius: 50,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
              child: Text(
                user.nombre.isNotEmpty
                    ? user.nombre[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(user.fullName, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                user.rol.toUpperCase(),
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Info items
            _ProfileItem(
              icon: Icons.email_outlined,
              label: 'Correo',
              value: user.email,
            ),
            _ProfileItem(
              icon: Icons.phone_outlined,
              label: 'Teléfono',
              value: user.telefono,
            ),

            if (user.isTechnician) ...[
              _ProfileItem(
                icon: Icons.star_outline,
                label: 'Calificación',
                value:
                    '${user.calificacionPromedio?.toStringAsFixed(1) ?? "0.0"} (${user.totalResenas ?? 0} reseñas)',
              ),
              _ProfileItem(
                icon: Icons.handyman_outlined,
                label: 'Servicios completados',
                value: '${user.serviciosCompletados ?? 0}',
              ),
              if (user.especialidades != null &&
                  user.especialidades!.isNotEmpty)
                _ProfileItem(
                  icon: Icons.category_outlined,
                  label: 'Especialidades',
                  value: user.especialidades!
                      .map((e) => AppConstants.categoryLabels[e] ?? e)
                      .join(', '),
                ),
            ],

            const SizedBox(height: 32),

            // Sign Out
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Cerrar Sesión'),
                      content: const Text(
                          '¿Estás seguro de cerrar sesión?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancelar'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            context
                                .read<AuthBloc>()
                                .add(AuthSignOutRequested());
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.errorColor,
                          ),
                          child: const Text('Cerrar Sesión'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.logout, color: AppTheme.errorColor),
                label: const Text('Cerrar Sesión'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.errorColor,
                  side: const BorderSide(color: AppTheme.errorColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodySmall),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
