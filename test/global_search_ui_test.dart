import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/localization/app_localizations.dart';
import 'package:furnexa/features/global_search/data/datasources/global_search_local_data_source.dart';
import 'package:furnexa/features/global_search/domain/entities/global_search_entities.dart';
import 'package:furnexa/features/global_search/domain/usecases/global_search_usecase.dart';
import 'package:furnexa/features/global_search/presentation/controllers/global_search_controller.dart';
import 'package:furnexa/features/global_search/presentation/widgets/global_search_control.dart';

void main() {
  late _FakeSearchDataSource source;
  late GlobalSearchController controller;

  setUp(() {
    source = _FakeSearchDataSource();
    controller = GlobalSearchController(
      useCase: GlobalSearchUseCase(source),
      recentSearches: source.recentSearches,
      clearRecentSearches: source.clearRecentSearches,
    );
  });

  tearDown(() => controller.dispose());

  test(
    'controller debounces queries and returns grouped result data',
    () async {
      controller.setQuery('chair', debounce: const Duration(days: 1));
      await controller.search();

      expect(source.queries, ['chair']);
      expect(controller.results, hasLength(2));
      expect(controller.results.map((item) => item.category).toSet(), {
        GlobalSearchEntityCategory.products,
        GlobalSearchEntityCategory.customers,
      });
    },
  );

  test(
    'controller applies category filters through the existing use case',
    () async {
      controller.setFilter(GlobalSearchEntityCategory.products);
      controller.setQuery('chair', debounce: const Duration(days: 1));
      await controller.search();

      expect(source.filters.single, GlobalSearchEntityCategory.products);
      expect(
        controller.results.single.entityType,
        GlobalSearchEntityType.product,
      );
    },
  );

  testWidgets('search field and recent searches render in the overlay', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        GlobalSearchControl(
          controller: controller,
          onResultSelected: (_) {},
          onViewAll: (_) {},
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('البحث العام'), findsOneWidget);
    expect(find.text('بحث سابق'), findsOneWidget);
  });

  testWidgets('results render grouped labels and navigate on selection', (
    tester,
  ) async {
    GlobalSearchResultItem? selected;
    await tester.pumpWidget(
      _app(
        GlobalSearchControl(
          controller: controller,
          onResultSelected: (item) => selected = item,
          onViewAll: (_) {},
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'chair');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('المنتجات'), findsNWidgets(2));
    expect(find.text('العملاء'), findsNWidgets(2));
    expect(find.text('CHAIR-001'), findsOneWidget);
    await tester.tap(find.text('كرسي سفرة'));
    await tester.pump(const Duration(milliseconds: 120));
    expect(selected?.entityType, GlobalSearchEntityType.product);
  });

  testWidgets('empty query provides a useful start state', (tester) async {
    source.recent.clear();
    await tester.pumpWidget(
      _app(
        GlobalSearchControl(
          controller: controller,
          onResultSelected: (_) {},
          onViewAll: (_) {},
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('ابدأ البحث'), findsOneWidget);
    expect(
      find.text('اكتب كلمة أو رقمًا للوصول السريع إلى بياناتك.'),
      findsOneWidget,
    );
  });
}

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('ar'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: ThemeData(useMaterial3: true),
  home: Scaffold(appBar: AppBar(title: child)),
);

class _FakeSearchDataSource extends GlobalSearchLocalDataSource {
  _FakeSearchDataSource() : super();

  final queries = <String>[];
  final filters = <GlobalSearchEntityCategory>[];
  final recent = <String>['بحث سابق'];

  @override
  Future<List<GlobalSearchResultItem>> search(
    String query, {
    GlobalSearchEntityCategory filter = GlobalSearchEntityCategory.all,
    int limit = 20,
  }) async {
    queries.add(query);
    filters.add(filter);
    final results = [
      const GlobalSearchResultItem(
        id: 'product-1',
        entityType: GlobalSearchEntityType.product,
        category: GlobalSearchEntityCategory.products,
        title: 'كرسي سفرة',
        codeOrNumber: 'CHAIR-001',
      ),
      const GlobalSearchResultItem(
        id: 'customer-1',
        entityType: GlobalSearchEntityType.customer,
        category: GlobalSearchEntityCategory.customers,
        title: 'عميل تجريبي',
        codeOrNumber: 'CUST-001',
      ),
    ];
    if (filter == GlobalSearchEntityCategory.all) return results;
    return results.where((item) => item.category == filter).toList();
  }

  @override
  Future<void> saveRecentQuery(String query) async {}

  @override
  Future<List<String>> recentSearches() async => recent;

  @override
  Future<void> clearRecentSearches() async => recent.clear();
}
