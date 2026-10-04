import 'package:furnexa/core/error/app_exception.dart';
import 'package:furnexa/core/result/result.dart';
import 'package:furnexa/core/usecase/usecase.dart';
import 'package:furnexa/features/factory_structure/domain/entities/factory_profile.dart';
import 'package:furnexa/features/factory_structure/domain/repositories/factory_structure_repository.dart';

class SaveFactoryProfileUseCase implements UseCase<FactoryProfile, void> {
  SaveFactoryProfileUseCase(this.repository);

  final FactoryStructureRepository repository;

  @override
  Future<Result<void>> call(FactoryProfile params) async {
    try {
      await repository.saveFactory(params);
      return Result.success(null);
    } catch (error) {
      return Result.failure(DatabaseException('Failed to save factory profile'));
    }
  }
}
