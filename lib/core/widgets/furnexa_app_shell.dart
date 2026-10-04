import 'package:flutter/material.dart';

import 'package:furnexa/core/localization/app_localizations.dart';
import 'package:furnexa/core/theme/app_theme.dart';
import 'package:furnexa/core/widgets/furnexa_breadcrumbs.dart';
import 'package:furnexa/core/widgets/furnexa_logo.dart';

class FurnexaAppShell extends StatelessWidget {
  const FurnexaAppShell({
    super.key,
    required this.title,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.body,
    required this.onToggleSidebar,
    required this.onToggleTheme,
    required this.onToggleLocale,
    required this.isDark,
    required this.locale,
    this.actions,
    this.leading,
    this.search,
    this.breadcrumbs = const [],
    this.userName,
    this.userRole,
    this.onLogout,
    this.isSidebarExpanded = true,
    this.showLogo = true,
  });

  final String title;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<FurnexaNavItem> destinations;
  final Widget body;
  final VoidCallback onToggleSidebar;
  final VoidCallback onToggleTheme;
  final VoidCallback onToggleLocale;
  final bool isDark;
  final Locale locale;
  final List<Widget>? actions;
  final Widget? leading;
  final Widget? search;
  final List<String> breadcrumbs;
  final String? userName;
  final String? userRole;
  final VoidCallback? onLogout;
  final bool isSidebarExpanded;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);
    final sidebarWidth = isSidebarExpanded ? 248.0 : 76.0;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: sidebarWidth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                  border: BorderDirectional(
                    end: BorderSide(
                      color: isDark
                          ? AppTheme.darkBorder
                          : AppTheme.lightBorder,
                    ),
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showLogo)
                          Padding(
                            padding: EdgeInsetsDirectional.only(
                              bottom: 14,
                              start: isSidebarExpanded ? 8 : 0,
                            ),
                            child: FurnexaLogo(
                              compact: !isSidebarExpanded,
                              showText: false,
                            ),
                          ),
                        Align(
                          alignment: isSidebarExpanded
                              ? AlignmentDirectional.centerStart
                              : Alignment.center,
                          child: IconButton(
                            tooltip: isSidebarExpanded
                                ? localizations.collapseSidebar
                                : localizations.expandSidebar,
                            onPressed: onToggleSidebar,
                            icon: Icon(
                              isSidebarExpanded ? Icons.menu_open : Icons.menu,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.separated(
                            itemCount: destinations.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final item = destinations[index];
                              final selected = index == selectedIndex;
                              final tile = Material(
                                color: selected
                                    ? (isDark
                                          ? AppTheme.darkSurfaceAlt
                                          : AppTheme.lightSurfaceAlt)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  onTap: () => onDestinationSelected(index),
                                  borderRadius: BorderRadius.circular(12),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isSidebarExpanded ? 12 : 0,
                                      vertical: 11,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: selected
                                            ? (isDark
                                                  ? AppTheme.darkPrimary
                                                  : AppTheme.navy)
                                            : Colors.transparent,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: isSidebarExpanded
                                          ? MainAxisAlignment.start
                                          : MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          selected
                                              ? item.selectedIcon
                                              : item.icon,
                                          color: selected
                                              ? (isDark
                                                    ? AppTheme.amber
                                                    : AppTheme.navy)
                                              : theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                        ),
                                        if (isSidebarExpanded) ...[
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              item.label,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.labelLarge?.copyWith(
                                                color: selected
                                                    ? (isDark
                                                          ? AppTheme
                                                                .darkTextPrimary
                                                          : AppTheme.navy)
                                                    : (isDark
                                                          ? AppTheme
                                                                .darkTextSecondary
                                                          : AppTheme
                                                                .lightTextSecondary),
                                                fontWeight: selected
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              );
                              return isSidebarExpanded
                                  ? tile
                                  : Tooltip(message: item.label, child: tile);
                            },
                          ),
                        ),
                        const Divider(height: 1),
                        const SizedBox(height: 10),
                        if (isSidebarExpanded)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              children: [
                                if (leading != null) ...[
                                  leading!,
                                  const SizedBox(width: 10),
                                ],
                                Expanded(
                                  child: Text(
                                    title,
                                    style: theme.textTheme.labelLarge,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Center(child: leading),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  _FurnexaTopBar(
                    title: title,
                    breadcrumbs: breadcrumbs,
                    search: search,
                    actions: actions,
                    userName: userName,
                    userRole: userRole,
                    onLogout: onLogout,
                    isDark: isDark,
                    locale: locale,
                    onToggleTheme: onToggleTheme,
                    onToggleLocale: onToggleLocale,
                    onToggleSidebar: onToggleSidebar,
                  ),
                  Expanded(child: body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FurnexaTopBar extends StatelessWidget {
  const _FurnexaTopBar({
    required this.title,
    required this.breadcrumbs,
    required this.search,
    required this.actions,
    required this.userName,
    required this.userRole,
    required this.onLogout,
    required this.isDark,
    required this.locale,
    required this.onToggleTheme,
    required this.onToggleLocale,
    required this.onToggleSidebar,
  });

  final String title;
  final List<String> breadcrumbs;
  final Widget? search;
  final List<Widget>? actions;
  final String? userName;
  final String? userRole;
  final VoidCallback? onLogout;
  final bool isDark;
  final Locale locale;
  final VoidCallback onToggleTheme;
  final VoidCallback onToggleLocale;
  final VoidCallback onToggleSidebar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 900;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (compact)
                        IconButton(
                          tooltip: localizations.expandSidebar,
                          onPressed: onToggleSidebar,
                          icon: const Icon(Icons.menu),
                        ),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!compact && search != null) ...[
                        const SizedBox(width: 16),
                        Flexible(flex: 2, child: search!),
                      ],
                      IconButton(
                        tooltip:
                            '${localizations.theme}: ${isDark ? localizations.light : localizations.dark}',
                        onPressed: onToggleTheme,
                        icon: Icon(
                          isDark
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                        ),
                      ),
                      IconButton(
                        tooltip:
                            '${localizations.language}: ${locale.languageCode == 'ar' ? localizations.english : localizations.arabic}',
                        onPressed: onToggleLocale,
                        icon: const Icon(Icons.translate_outlined),
                      ),
                      if (actions != null) ...[
                        const SizedBox(width: 4),
                        ...actions!,
                      ],
                      _FurnexaUserMenu(
                        name: userName,
                        role: userRole,
                        onLogout: onLogout,
                      ),
                    ],
                  ),
                  if (compact && search != null) ...[
                    const SizedBox(height: 8),
                    search!,
                  ],
                  if (breadcrumbs.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    FurnexaBreadcrumbs(items: breadcrumbs),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FurnexaUserMenu extends StatelessWidget {
  const _FurnexaUserMenu({
    required this.name,
    required this.role,
    required this.onLogout,
  });

  final String? name;
  final String? role;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      tooltip: localizations.user,
      onSelected: (value) {
        if (value == 'logout') onLogout?.call();
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          value: 'identity',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text(name ?? localizations.user),
            subtitle: Text('${localizations.role}: ${role ?? ''}'),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'logout',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout),
            title: Text(localizations.logout),
          ),
        ),
      ],
      child: const Padding(
        padding: EdgeInsets.all(6),
        child: CircleAvatar(
          radius: 17,
          child: Icon(Icons.person_outline, size: 18),
        ),
      ),
    );
  }
}

class FurnexaNavItem {
  const FurnexaNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
