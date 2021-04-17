import 'dart:async';

import 'package:pedantic/pedantic.dart';
import 'package:use_case/use_case.dart';
import 'package:test/test.dart';

import 'helpers/matchers.dart';
import 'helpers/use_cases.dart';

void main() {
  group('Use case', () {
    late UseCase<int, String> useCase,
        errorUseCase,
        slowUseCase,
        inverseSlowUseCase;

    setUp(() {
      useCase = IntToStringUseCase();
      errorUseCase = IntToStringErrorUseCase();
      slowUseCase = IntToStringSlowUseCase();
      inverseSlowUseCase = IntToStringInverseSlowUseCase();
    });

    test('Returns UseCaseResult with data', () async {
      final result = await useCase.call(1);

      expect(result, useCaseSuccess('1'));
    });

    test('Returns UseCaseResult with exception', () async {
      final result = await errorUseCase.call(1);

      expect(result, useCaseFailure);
    });

    test('Can process results via a Stream', () async {
      final controller = StreamController<int>();

      expect(controller.stream.useCaseMap(useCase),
          emitsInOrder(['1', '2', '3', emitsDone]));

      controller.sink.add(1);
      controller.sink.add(2);
      controller.sink.add(3);
      unawaited(controller.sink.close());
    });

    test('Can process errors via a Stream', () async {
      final controller = StreamController<int>();

      expect(
          controller.stream.useCaseMap(errorUseCase),
          emitsInOrder([
            emitsError(isException),
            emitsError(isException),
            emitsError(isException),
            emitsDone
          ]));

      controller.sink.add(1);
      controller.sink.add(2);
      controller.sink.add(3);
      unawaited(controller.sink.close());
    });

    test('Cancelable acts like switchMap', () async {
      final controller = StreamController<int>();

      expect(controller.stream.useCaseSwitchMap(slowUseCase),
          emitsInOrder(['3', emitsDone]));

      controller.sink.add(1);
      controller.sink.add(2);
      controller.sink.add(3);
      unawaited(controller.sink.close());
    });

    test('Non-cancelable acts like asyncExpand', () async {
      final controller = StreamController<int>();

      expect(controller.stream.useCaseMap(inverseSlowUseCase),
          emitsInOrder(['1', '2', '3', emitsDone]));

      controller.sink.add(1); // will complete last
      controller.sink.add(2);
      controller.sink.add(3); // will complete first
      unawaited(controller.sink.close());
    });

    test('Can use a controller', () async {
      final controller = UseCaseStreamController(useCase: useCase);

      expect(controller, emitsInOrder(['1', '2', '3', emitsDone]));

      controller.sink.add(1);
      controller.sink.add(2);
      controller.sink.add(3);
      unawaited(controller.sink.close());
    });

    test('Can use a controller with transformers A', () async {
      final controller = UseCaseStreamController(
          useCase: useCase,
          inputStream: (Stream<int> stream) => stream.distinct());

      expect(controller, emitsInOrder(['1', emitsDone]));

      controller.sink.add(1);
      controller.sink.add(1);
      controller.sink.add(1);
      unawaited(controller.sink.close());
    });

    test('Can use a controller with transformers B', () async {
      final controller = UseCaseStreamController(
          useCase: useCase,
          outputStream: (Stream<String> stream) => stream.distinct());

      expect(controller, emitsInOrder(['1', emitsDone]));

      controller.sink.add(1);
      controller.sink.add(1);
      controller.sink.add(1);
      unawaited(controller.sink.close());
    });

    test('Can use a controller with transformers C', () async {
      final controller = UseCaseStreamController(
        useCase: useCase,
        inputStream: (Stream<int> stream) => stream.map((it) => it * 2),
        outputStream: (Stream<String> stream) => stream.map((it) => 'v$it'),
      );

      expect(controller, emitsInOrder(['v2', 'v4', 'v6', emitsDone]));

      controller.sink.add(1);
      controller.sink.add(2);
      controller.sink.add(3);
      unawaited(controller.sink.close());
    });
  });
}
