import 'package:use_case/use_case.dart';

class IntToStringUseCase extends UseCase<int, String> {
  @override
  Future<String> transaction(int param) => Future.value(param.toString());
}

class IntToStringErrorUseCase extends UseCase<int, String> {
  @override
  Future<String> transaction(int param) =>
      Future.error(Exception('something went wrong!'));
}

class IntToStringSlowUseCase extends UseCase<int, String> {
  @override
  Future<String> transaction(int param) async {
    await Future.delayed(const Duration(milliseconds: 20));

    return param.toString();
  }
}

class IntToStringInverseSlowUseCase extends UseCase<int, String> {
  @override
  Future<String> transaction(int param) async {
    await Future.delayed(Duration(milliseconds: 500 - param * 100));

    return param.toString();
  }
}
