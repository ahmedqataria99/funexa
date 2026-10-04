import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:furnexa/features/global_search/domain/entities/global_search_entities.dart';
import 'package:furnexa/features/global_search/domain/usecases/global_search_usecase.dart';

class GlobalSearchController extends ChangeNotifier {
  GlobalSearchController({
    required GlobalSearchUseCase useCase,
    Future<List<String>> Function()? recentSearches,
    Future<void> Function()? clearRecentSearches,
  }) : _useCase = useCase,
       _recentSearches = recentSearches,
       _clearRecentSearches = clearRecentSearches;

  final GlobalSearchUseCase _useCase;
  final Future<List<String>> Function()? _recentSearches;
  final Future<void> Function()? _clearRecentSearches;
  Timer? _debounce;
  String query = '';
  GlobalSearchEntityCategory filter = GlobalSearchEntityCategory.all;
  List<GlobalSearchResultItem> results = const [];
  List<String> recent = const [];
  bool loading = false;
  bool loadingRecent = false;
  String? error;
  int _requestId = 0;

  List<GlobalSearchResultItem> get visibleResults => results;

  Future<void> open() async {
    if (_recentSearches == null || recent.isNotEmpty || loadingRecent) return;
    loadingRecent = true;
    notifyListeners();
    try {
      recent = await _recentSearches();
    } finally {
      loadingRecent = false;
      notifyListeners();
    }
  }

  void setQuery(
    String value, {
    Duration debounce = const Duration(milliseconds: 300),
  }) {
    query = value;
    error = null;
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      results = const [];
      loading = false;
      notifyListeners();
      return;
    }
    loading = true;
    notifyListeners();
    _debounce = Timer(debounce, search);
  }

  void setFilter(GlobalSearchEntityCategory value) {
    filter = value;
    if (query.trim().isNotEmpty) search();
    notifyListeners();
  }

  Future<void> search() async {
    final currentQuery = query.trim();
    if (currentQuery.isEmpty) return;
    final requestId = ++_requestId;
    loading = true;
    error = null;
    notifyListeners();
    final result = await _useCase.call(currentQuery, filter: filter);
    if (requestId != _requestId) return;
    if (result.isSuccess) {
      results = result.value;
    } else {
      results = const [];
      error = result.error.message;
    }
    loading = false;
    notifyListeners();
  }

  Future<void> retry() => search();

  Future<void> clearRecent() async {
    await _clearRecentSearches?.call();
    recent = const [];
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
