import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:furnexa/core/constants/app_constants.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/core/database/furnexa_database_diagnostics.dart';
import 'package:furnexa/core/localization/app_localizations.dart';
import 'package:furnexa/core/shared/app_settings.dart';
import 'package:furnexa/core/theme/app_theme.dart';
import 'package:furnexa/core/widgets/furnexa_app_shell.dart';
import 'package:furnexa/core/widgets/furnexa_logo.dart';
import 'package:furnexa/features/accounting/presentation/pages/accounting_page.dart';
import 'package:furnexa/features/backup_restore/presentation/pages/backup_restore_page.dart';
import 'package:furnexa/features/dashboard_reports/presentation/pages/dashboard_reports_page.dart';
import 'package:furnexa/features/documents/presentation/pages/document_history_page.dart';
import 'package:furnexa/features/factory_structure/data/datasources/factory_structure_local_data_source.dart';
import 'package:furnexa/features/factory_structure/presentation/pages/factory_structure_page.dart';
import 'package:furnexa/features/global_search/data/datasources/global_search_local_data_source.dart';
import 'package:furnexa/features/global_search/domain/entities/global_search_entities.dart';
import 'package:furnexa/features/global_search/domain/usecases/global_search_usecase.dart';
import 'package:furnexa/features/global_search/presentation/controllers/global_search_controller.dart';
import 'package:furnexa/features/global_search/presentation/widgets/global_search_control.dart';
import 'package:furnexa/features/hr/presentation/pages/hr_page.dart';
import 'package:furnexa/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:furnexa/features/notifications/presentation/pages/notifications_page.dart';
import 'package:furnexa/features/notifications/presentation/widgets/notification_badge.dart';
import 'package:furnexa/features/production/presentation/pages/production_page.dart';
import 'package:furnexa/features/purchasing/presentation/pages/purchasing_page.dart';
import 'package:furnexa/features/raw_materials_products/presentation/pages/raw_materials_products_page.dart';
import 'package:furnexa/features/sales/presentation/pages/sales_page.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'package:furnexa/features/users_roles_permissions/presentation/pages/login_page.dart';
import 'package:furnexa/features/users_roles_permissions/presentation/pages/users_roles_page.dart';
import 'package:furnexa/features/warehouses_stock/presentation/pages/warehouses_stock_page.dart';
import 'package:furnexa/features/warehouses_stock/data/repositories/warehouses_stock_repository_impl.dart';
import 'package:furnexa/features/purchasing/data/repositories/purchasing_repository_impl.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FurnexaDatabase.instance.database;
  await FactoryStructureLocalDataSource().initializeSchema();
  await FurnexaDatabaseDiagnostics.capture(source: 'app.startup');
  if (FurnexaDatabaseDiagnostics.enabled) {
    final stockRepository = WarehousesStockRepositoryImpl();
    final purchasingRepository = PurchasingRepositoryImpl();
    try {
      await stockRepository.warehouses();
    } on Object catch (error, stackTrace) {
      await FurnexaDatabaseDiagnostics.reportFailure(
        source: 'app.startup.stockWarehouses',
        error: error,
        stackTrace: stackTrace,
      );
    }
    try {
      await stockRepository.stock(null);
    } on Object catch (error, stackTrace) {
      await FurnexaDatabaseDiagnostics.reportFailure(
        source: 'app.startup.stock',
        error: error,
        stackTrace: stackTrace,
      );
    }
    try {
      await purchasingRepository.requests();
    } on Object catch (error, stackTrace) {
      await FurnexaDatabaseDiagnostics.reportFailure(
        source: 'app.startup.purchaseRequests',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
  final preferences = await SharedPreferences.getInstance();
  final settings = AppSettings(preferences);
  runApp(
    FurnexaApp(
      initialThemeMode: settings.themeMode,
      initialLocale: settings.locale,
      preferences: preferences,
    ),
  );
}

class FurnexaApp extends StatefulWidget {
  const FurnexaApp({
    super.key,
    this.initialThemeMode = ThemeMode.light,
    this.initialLocale = const Locale('ar'),
    this.preferences,
  });

  final ThemeMode initialThemeMode;
  final Locale initialLocale;
  final SharedPreferences? preferences;

  static final SecurityLocalDataSource security = SecurityLocalDataSource();

  @override
  State<FurnexaApp> createState() => _FurnexaAppState();
}

class _FurnexaAppState extends State<FurnexaApp> {
  late ThemeMode _themeMode = widget.initialThemeMode;
  late Locale _locale = widget.initialLocale;

  void _toggleTheme() {
    final next = _themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    setState(() => _themeMode = next);
    final preferences = widget.preferences;
    if (preferences != null)
      unawaited(AppSettings(preferences).saveTheme(next));
  }

  void _toggleLocale() {
    final next = _locale.languageCode == 'ar'
        ? const Locale('en')
        : const Locale('ar');
    setState(() => _locale = next);
    final preferences = widget.preferences;
    if (preferences != null)
      unawaited(AppSettings(preferences).saveLocale(next));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        const AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: _AuthGate(
        security: FurnexaApp.security,
        themeMode: _themeMode,
        locale: _locale,
        onToggleTheme: _toggleTheme,
        onToggleLocale: _toggleLocale,
      ),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate({
    required this.security,
    required this.themeMode,
    required this.locale,
    required this.onToggleTheme,
    required this.onToggleLocale,
  });
  final SecurityLocalDataSource security;
  final ThemeMode themeMode;
  final Locale locale;
  final VoidCallback onToggleTheme;
  final VoidCallback onToggleLocale;

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _ready = false;
  bool _setupRequired = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await widget.security.ensureInitialAdmin();
      _setupRequired = await widget.security.initialAdminSetupRequired();
    } catch (_) {
      if (!mounted) return;
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) => !_ready
      ? Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const FurnexaLogo(),
                const SizedBox(height: 18),
                Text(
                  'Furnexa ERP',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                const CircularProgressIndicator(),
              ],
            ),
          ),
        )
      : widget.security.session == null
      ? LoginPage(
          security: widget.security,
          setupRequired: _setupRequired,
          onLoggedIn: () => setState(() {}),
        )
      : _AppHome(
          security: widget.security,
          onLogout: () => setState(() {}),
          themeMode: widget.themeMode,
          locale: widget.locale,
          onToggleTheme: widget.onToggleTheme,
          onToggleLocale: widget.onToggleLocale,
        );
}

class _AppHome extends StatefulWidget {
  const _AppHome({
    required this.security,
    required this.onLogout,
    required this.themeMode,
    required this.locale,
    required this.onToggleTheme,
    required this.onToggleLocale,
  });
  final SecurityLocalDataSource security;
  final VoidCallback onLogout;
  final ThemeMode themeMode;
  final Locale locale;
  final VoidCallback onToggleTheme;
  final VoidCallback onToggleLocale;

  @override
  State<_AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends State<_AppHome> {
  int _index = 0;
  bool _sidebarExpanded = true;
  GlobalSearchResultItem? _selectedSearchResult;
  late final GlobalSearchController _searchController = GlobalSearchController(
    useCase: GlobalSearchUseCase(
      GlobalSearchLocalDataSource(security: widget.security),
    ),
    recentSearches: GlobalSearchLocalDataSource(
      security: widget.security,
    ).recentSearches,
    clearRecentSearches: GlobalSearchLocalDataSource(
      security: widget.security,
    ).clearRecentSearches,
  );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openSearchResult(GlobalSearchResultItem item) {
    setState(() {
      _selectedSearchResult = item;
      _index = switch (item.entityType) {
        GlobalSearchEntityType.product => 2,
        GlobalSearchEntityType.customer ||
        GlobalSearchEntityType.salesOrder => 5,
        GlobalSearchEntityType.productionOrder ||
        GlobalSearchEntityType.productionStage => 6,
        GlobalSearchEntityType.worker => 7,
        GlobalSearchEntityType.warehouse => 3,
        GlobalSearchEntityType.section || GlobalSearchEntityType.workshop => 1,
      };
    });
  }

  void _openSearchCategory(GlobalSearchEntityCategory category) {
    final index = switch (category) {
      GlobalSearchEntityCategory.products => 2,
      GlobalSearchEntityCategory.customers ||
      GlobalSearchEntityCategory.salesOrders => 5,
      GlobalSearchEntityCategory.productionOrders => 6,
      GlobalSearchEntityCategory.workers => 7,
      GlobalSearchEntityCategory.warehouses => 3,
      GlobalSearchEntityCategory.sections ||
      GlobalSearchEntityCategory.workshops ||
      GlobalSearchEntityCategory.stages => 1,
      _ => 0,
    };
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final pages = [
      DashboardReportsPage(
        security: widget.security,
        onNavigate: (value) => setState(() => _index = value),
      ),
      FactoryStructurePage(
        security: widget.security,
        initialSelectedId:
            _selectedSearchResult != null &&
                {
                  GlobalSearchEntityType.section,
                  GlobalSearchEntityType.workshop,
                  GlobalSearchEntityType.productionStage,
                }.contains(_selectedSearchResult!.entityType)
            ? _selectedSearchResult!.id
            : null,
      ),
      RawMaterialsProductsPage(
        key: ValueKey('product-${_selectedSearchResult?.id}'),
        security: widget.security,
        initialProductId:
            _selectedSearchResult?.entityType == GlobalSearchEntityType.product
            ? _selectedSearchResult!.id
            : null,
      ),
      WarehousesStockPage(
        key: ValueKey('warehouse-${_selectedSearchResult?.id}'),
        initialWarehouseId:
            _selectedSearchResult?.entityType ==
                GlobalSearchEntityType.warehouse
            ? _selectedSearchResult!.id
            : null,
      ),
      PurchasingPage(),
      SalesPage(
        key: ValueKey('sales-${_selectedSearchResult?.id}'),
        initialCustomerId:
            _selectedSearchResult?.entityType == GlobalSearchEntityType.customer
            ? _selectedSearchResult!.id
            : null,
        initialOrderId:
            _selectedSearchResult?.entityType ==
                GlobalSearchEntityType.salesOrder
            ? _selectedSearchResult!.id
            : null,
      ),
      ProductionPage(
        key: ValueKey('production-${_selectedSearchResult?.id}'),
        initialOrderId:
            _selectedSearchResult?.entityType ==
                GlobalSearchEntityType.productionOrder
            ? _selectedSearchResult!.id
            : null,
      ),
      HrPage(
        security: widget.security,
        initialWorkerId:
            _selectedSearchResult?.entityType == GlobalSearchEntityType.worker
            ? _selectedSearchResult!.id
            : null,
      ),
      AccountingPage(security: widget.security),
      UsersRolesPage(security: widget.security, onLogout: widget.onLogout),
      NotificationsPage(
        security: widget.security,
        onNavigate: (action) => setState(
          () => _index = switch (action) {
            'warehouse_stock' => 3,
            'purchasing' => 4,
            'sales' => 5,
            'production' => 6,
            'hr' => 7,
            'accounting' => 8,
            _ => _index,
          },
        ),
      ),
      const DocumentHistoryPage(),
      BackupRestorePage(
        security: widget.security,
        onRestoreCompleted: widget.onLogout,
      ),
    ];

    final navItems = [
      FurnexaNavItem(
        label: localizations.dashboard,
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
      ),
      FurnexaNavItem(
        label: localizations.factoryStructure,
        icon: Icons.factory_outlined,
        selectedIcon: Icons.factory,
      ),
      FurnexaNavItem(
        label: localizations.products,
        icon: Icons.inventory_2_outlined,
        selectedIcon: Icons.inventory_2,
      ),
      FurnexaNavItem(
        label: localizations.warehousesStock,
        icon: Icons.warehouse_outlined,
        selectedIcon: Icons.warehouse,
      ),
      FurnexaNavItem(
        label: localizations.purchasing,
        icon: Icons.shopping_cart_outlined,
        selectedIcon: Icons.shopping_cart,
      ),
      FurnexaNavItem(
        label: localizations.sales,
        icon: Icons.point_of_sale_outlined,
        selectedIcon: Icons.point_of_sale,
      ),
      FurnexaNavItem(
        label: localizations.production,
        icon: Icons.precision_manufacturing_outlined,
        selectedIcon: Icons.precision_manufacturing,
      ),
      FurnexaNavItem(
        label: localizations.humanResources,
        icon: Icons.groups_outlined,
        selectedIcon: Icons.groups,
      ),
      FurnexaNavItem(
        label: localizations.accounting,
        icon: Icons.account_balance_outlined,
        selectedIcon: Icons.account_balance,
      ),
      FurnexaNavItem(
        label: localizations.usersRoles,
        icon: Icons.admin_panel_settings_outlined,
        selectedIcon: Icons.admin_panel_settings,
      ),
      FurnexaNavItem(
        label: localizations.notifications,
        icon: Icons.notifications_none_outlined,
        selectedIcon: Icons.notifications,
      ),
      FurnexaNavItem(
        label: localizations.documents,
        icon: Icons.description_outlined,
        selectedIcon: Icons.description,
      ),
      FurnexaNavItem(
        label: localizations.backupRestore,
        icon: Icons.backup_outlined,
        selectedIcon: Icons.backup,
      ),
    ];

    return FurnexaAppShell(
      title: pages.isEmpty ? 'Furnexa ERP' : navItems[_index].label,
      selectedIndex: _index,
      onDestinationSelected: (value) => setState(() => _index = value),
      destinations: navItems,
      isSidebarExpanded: _sidebarExpanded,
      onToggleSidebar: () =>
          setState(() => _sidebarExpanded = !_sidebarExpanded),
      onToggleTheme: widget.onToggleTheme,
      onToggleLocale: widget.onToggleLocale,
      isDark: widget.themeMode == ThemeMode.dark,
      locale: widget.locale,
      breadcrumbs: [localizations.home, navItems[_index].label],
      userName: widget.security.session?.user.displayName,
      userRole: widget.security.session?.role.name,
      onLogout: () {
        widget.security.logout();
        widget.onLogout();
      },
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: const Icon(Icons.person_outline, size: 18),
      ),
      actions: [
        FutureBuilder<int>(
          future: NotificationsRepositoryImpl().unreadCount(),
          builder: (context, snapshot) => IconButton(
            tooltip: 'الإشعارات',
            onPressed: () => setState(() => _index = 10),
            icon: NotificationBadge(
              count: snapshot.data ?? 0,
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
        ),
      ],
      search: GlobalSearchControl(
        controller: _searchController,
        onResultSelected: _openSearchResult,
        onViewAll: _openSearchCategory,
      ),
      body: pages[_index],
    );
  }
}
