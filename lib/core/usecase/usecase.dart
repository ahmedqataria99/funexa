import 'package:furnexa/core/result/result.dart';

abstract class UseCase<Input, Output> {
  Future<Result<Output>> call(Input params);
}

class NoParams {
  const NoParams();
}
