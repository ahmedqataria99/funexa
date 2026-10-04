import 'package:furnexa/core/result/result.dart';
import 'package:furnexa/core/usecase/usecase.dart';
import 'package:furnexa/features/factory_structure/domain/entities/section.dart';
import 'package:furnexa/features/factory_structure/domain/repositories/factory_structure_repository.dart';

class GetSectionsUseCase implements UseCase<String, List<Section>> {
  GetSectionsUseCase(this.repository);

  final FactoryStructureRepository repository;

  @override
  Future<Result<List<Section>>> call(String params) async {
    try {
      final sections = await repository.searchSections(params);
      return Result.success(sections);
    } catch (error) {
      return Result.failure(Exception('Failed to load sections') as dynamic);
    }
  }
}
