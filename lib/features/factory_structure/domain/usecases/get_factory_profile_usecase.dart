import 'package:furnexa/core/result/result.dart';
import 'package:furnexa/core/usecase/usecase.dart';
import 'package:furnexa/features/factory_structure/domain/entities/factory_profile.dart';
import 'package:furnexa/features/factory_structure/domain/repositories/factory_structure_repository.dart';

class GetFactoryProfileUseCase implements UseCase<NoParams, FactoryProfile?> {
  GetFactoryProfileUseCase(this.repository);

  final FactoryStructureRepository repository;

  @override
  Future<Result<FactoryProfile?>> call(NoParams params) async {
    try {
      final factory = await repository.getFactory();
      return Result.success(factory);
    } catch (error) {
      return Result.failure(
        Exception('Failed to load factory profile') as dynamic,
      );
    }
  }
}
