import 'package:furnexa/core/error/app_exception.dart';
import 'package:furnexa/core/result/result.dart';
import 'package:furnexa/features/global_search/data/datasources/global_search_local_data_source.dart';
import 'package:furnexa/features/global_search/domain/entities/global_search_entities.dart';

class GlobalSearchUseCase {
  const GlobalSearchUseCase(this.dataSource);

  final GlobalSearchLocalDataSource dataSource;

  Future<Result<List<GlobalSearchResultItem>>> call(
    String params, {
    GlobalSearchEntityCategory filter = GlobalSearchEntityCategory.all,
    int limit = 20,
  }) async {
    try {
      final results = await dataSource.search(
        params,
        filter: filter,
        limit: limit,
      );
      if (params.trim().isNotEmpty) {
        await dataSource.saveRecentQuery(params);
      }
      return Result.success(results);
    } catch (error) {
      return Result.failure(
        DatabaseException('Failed to execute global search'),
      );
    }
  }
}
