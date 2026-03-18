import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/service_card.dart';
import '../../../data/models/service_model.dart';
import '../../../data/repositories/service_repository.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';

class ClientServicesScreen extends StatelessWidget {
  const ClientServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = context.watch<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return const SizedBox();
    final user = authState.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Mis Servicios')),
      body: StreamBuilder<List<ServiceModel>>(
        stream: context.read<ServiceRepository>().getClientServices(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final services = snapshot.data ?? [];

          if (services.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 64, color: AppTheme.textTertiary),
                  const SizedBox(height: 16),
                  Text(
                    'No tienes servicios',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: services.length,
            itemBuilder: (context, index) {
              final service = services[index];
              return ServiceCard(
                service: service,
                showTechnician: true,
                onTap: () => context.push('/service/${service.id}'),
              );
            },
          );
        },
      ),
    );
  }
}
