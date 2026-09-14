import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/account_admin_repository.dart';

/// "Correo sin verificar" pill, shown only once the account is known to be
/// unverified. Call [AccountAdminRepository.ensureStatus] for the visible uids
/// first; this widget only listens.
class UnverifiedEmailBadge extends StatelessWidget {
  final String uid;

  const UnverifiedEmailBadge({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, bool>>(
      valueListenable: context.read<AccountAdminRepository>().emailVerified,
      builder: (context, verified, _) {
        if (verified[uid] != false) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.warningColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Correo sin verificar',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.warningColor,
            ),
          ),
        );
      },
    );
  }
}

/// Menu entry shared by the clientes and técnicos lists.
PopupMenuItem<String> releasePhoneMenuItem() => const PopupMenuItem(
      value: 'release_phone',
      child: Row(
        children: [
          Icon(Icons.phonelink_erase_rounded, size: 18),
          SizedBox(width: 10),
          Text('Liberar teléfono'),
        ],
      ),
    );

/// Confirms, then frees the phone number [user] holds so its real owner can
/// register with it.
Future<void> confirmAndReleasePhone(BuildContext context, UserModel user) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      title: Text(
        'Liberar teléfono',
        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
      ),
      content: Text(
        'El número ${user.telefono.isEmpty ? '' : '${user.telefono} '}dejará de estar '
        'reservado para ${user.fullName} y cualquier persona podrá registrarse con él.\n\n'
        'Úsalo cuando alguien se registró con un número que no es suyo. '
        'La cuenta no se suspende; hazlo aparte si corresponde.',
        style: GoogleFonts.plusJakartaSans(color: AppTheme.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warningColor),
          child: const Text('Liberar', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  try {
    final released =
        await context.read<AccountAdminRepository>().releasePhone(user.uid);
    messenger.showSnackBar(SnackBar(
      content: Text(released.isEmpty
          ? 'Esta cuenta no tenía ningún teléfono reservado.'
          : 'Teléfono ${released.join(', ')} liberado.'),
      backgroundColor: AppTheme.successColor,
    ));
  } catch (e) {
    messenger.showSnackBar(SnackBar(
      content: Text('No se pudo liberar: $e'),
      backgroundColor: AppTheme.errorColor,
    ));
  }
}
