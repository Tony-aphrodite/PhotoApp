import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/account_admin_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../widgets/account_admin_widgets.dart';

/// Every registered cliente, with the admin's account-level switch.
///
/// Until this screen existed the admin could see técnicos but had no view of
/// clientes at all — so a cliente who kept trying to take jobs off-platform
/// (the pattern the moderation queue is there to surface) had nowhere to be
/// acted on.
class AdminClientsScreen extends StatefulWidget {
  const AdminClientsScreen({super.key});

  @override
  State<AdminClientsScreen> createState() => _AdminClientsScreenState();
}

class _AdminClientsScreenState extends State<AdminClientsScreen> {
  late final Stream<List<UserModel>> _clients;
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Subscribed once; filtering is in memory so typing never re-reads.
    _clients = context.read<UserRepository>().getAllClients();
    _search.addListener(() {
      setState(() => _query = _search.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(UserModel u) {
    if (_query.isEmpty) return true;
    return u.fullName.toLowerCase().contains(_query) ||
        u.email.toLowerCase().contains(_query) ||
        u.telefono.contains(_query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            floating: true,
            pinned: true,
            backgroundColor: const Color(0xFF0A2E36),
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0A2E36),
                      Color(0xFF0D5C61),
                      Color(0xFF14BDAC),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Clientes',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Cuentas registradas en la plataforma',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre, correo o teléfono',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          StreamBuilder<List<UserModel>>(
            stream: _clients,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primaryColor),
                  ),
                );
              }
              if (snapshot.hasError) {
                return SliverFillRemaining(
                  child: Center(child: Text('Error: ${snapshot.error}')),
                );
              }
              final all = snapshot.data ?? const <UserModel>[];
              context
                  .read<AccountAdminRepository>()
                  .ensureStatus(all.map((u) => u.uid));
              final clients = all.where(_matches).toList();
              if (clients.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Text(
                      _query.isEmpty
                          ? 'No hay clientes registrados'
                          : 'Sin resultados para "$_query"',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                sliver: SliverList.separated(
                  itemCount: clients.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _ClientCard(client: clients[i]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  final UserModel client;

  const _ClientCard({required this.client});

  Future<void> _toggle(BuildContext context) async {
    final suspending = client.activo;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: Text(
          suspending ? 'Suspender cuenta' : 'Reactivar cuenta',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          suspending
              ? '${client.fullName} no podrá iniciar sesión ni crear solicitudes hasta que la reactives.'
              : '${client.fullName} podrá volver a usar la app.',
          style: GoogleFonts.plusJakartaSans(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  suspending ? AppTheme.errorColor : AppTheme.successColor,
            ),
            child: Text(
              suspending ? 'Suspender' : 'Reactivar',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<UserRepository>().setActivo(client.uid, !suspending);
      messenger.showSnackBar(SnackBar(
        content:
            Text(suspending ? 'Cuenta suspendida.' : 'Cuenta reactivada.'),
        backgroundColor: AppTheme.successColor,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('No se pudo actualizar: $e'),
        backgroundColor: AppTheme.errorColor,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                client.nombre.isNotEmpty ? client.nombre[0].toUpperCase() : '?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        client.fullName,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    UnverifiedEmailBadge(uid: client.uid),
                    if (!client.activo) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Suspendido',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.errorColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  client.email,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  '${client.telefono}  ·  desde ${DateFormat('dd/MM/yyyy').format(client.createdAt)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: AppTheme.textTertiary),
            onSelected: (action) => action == 'release_phone'
                ? confirmAndReleasePhone(context, client)
                : _toggle(context),
            itemBuilder: (_) => [
              releasePhoneMenuItem(),
              PopupMenuItem(
                value: 'toggle',
                child: Row(
                  children: [
                    Icon(
                      client.activo
                          ? Icons.block_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 18,
                      color: client.activo
                          ? AppTheme.errorColor
                          : AppTheme.successColor,
                    ),
                    const SizedBox(width: 10),
                    Text(client.activo
                        ? 'Suspender cuenta'
                        : 'Reactivar cuenta'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
