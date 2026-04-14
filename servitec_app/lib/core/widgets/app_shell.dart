import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/bloc/auth_state.dart';
import '../theme/app_theme.dart';

class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return const SizedBox();
    final user = authState.user;

    List<_NavItem> items;

    if (user.isClient) {
      items = const [
        _NavItem(
          outlinedIcon: Icons.home_outlined,
          filledIcon: Icons.home_rounded,
          label: 'Inicio',
        ),
        _NavItem(
          outlinedIcon: Icons.list_alt_outlined,
          filledIcon: Icons.list_alt_rounded,
          label: 'Servicios',
        ),
        _NavItem(
          outlinedIcon: Icons.person_outline_rounded,
          filledIcon: Icons.person_rounded,
          label: 'Perfil',
        ),
      ];
    } else if (user.isTechnician) {
      items = const [
        _NavItem(
          outlinedIcon: Icons.dashboard_outlined,
          filledIcon: Icons.dashboard_rounded,
          label: 'Servicios',
        ),
        _NavItem(
          outlinedIcon: Icons.person_outline_rounded,
          filledIcon: Icons.person_rounded,
          label: 'Perfil',
        ),
      ];
    } else {
      // Admin
      items = const [
        _NavItem(
          outlinedIcon: Icons.dashboard_outlined,
          filledIcon: Icons.dashboard_rounded,
          label: 'Dashboard',
        ),
        _NavItem(
          outlinedIcon: Icons.people_outline_rounded,
          filledIcon: Icons.people_rounded,
          label: 'Tecnicos',
        ),
        _NavItem(
          outlinedIcon: Icons.person_outline_rounded,
          filledIcon: Icons.person_rounded,
          label: 'Perfil',
        ),
      ];
    }

    final currentIndex = navigationShell.currentIndex;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: AppTheme.dividerColor,
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(items.length, (index) {
                final item = items[index];
                final isSelected = index == currentIndex;

                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      navigationShell.goBranch(
                        index,
                        initialLocation: index == currentIndex,
                      );
                    },
                    child: _PremiumNavItem(
                      item: item,
                      isSelected: isSelected,
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData outlinedIcon;
  final IconData filledIcon;
  final String label;

  const _NavItem({
    required this.outlinedIcon,
    required this.filledIcon,
    required this.label,
  });
}

class _PremiumNavItem extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;

  const _PremiumNavItem({
    required this.item,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Gradient indicator line above the icon
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            height: 3,
            width: isSelected ? 24 : 0,
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: isSelected ? AppTheme.cardGradient : null,
            ),
          ),
          // Icon
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              isSelected ? item.filledIcon : item.outlinedIcon,
              key: ValueKey(isSelected),
              size: 24,
              color: isSelected
                  ? AppTheme.primaryColor
                  : AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 4),
          // Label
          Text(
            item.label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? AppTheme.primaryColor
                  : AppTheme.textTertiary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
