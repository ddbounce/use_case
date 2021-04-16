import 'package:meta/meta.dart';

/// A use case defines a [transaction] which can be triggered using [call].
///
/// Subclasses should extend [UseCase], for example:
///
/// ```dart
/// class IntToStringUseCase extends UseCase<int, String> {
///   @override
///   Future<String> transaction(int param) => Future.value(param.toString());
/// }
/// ```
abstract class UseCase<In, Out> {
  /// executes the [transaction] with the given [param].
  @nonVirtual
  Future<UseCaseResult<Out>> call(In param) async {
    Out? result;

    try {
      result = await transaction(param);
    } catch (e, s) {
      return UseCaseResult<Out>(
          exception: UseCaseException(error: e, stackTrace: s));
    }

    return UseCaseResult(data: result!);
  }

  /// the transaction, which should be implemented in a sub-class.
  @protected
  Future<Out> transaction(In param);
}

/// The return value for a [UseCase], either [data] or [exception] will be filled.
class UseCaseResult<Out> {
  /// If successful, then data will be filled
  final Out? data;

  /// If unsuccessful, then exception will be filled
  final UseCaseException? exception;

  /// returns true when the call succeeded.
  bool get hasData => data != null;

  /// returns true when the call errored.
  bool get hasError => exception != null;

  const UseCaseResult({this.data, this.exception})
      : assert(data != null || exception != null);
}

/// A wrapper for exceptions that may be thrown during the call phase of a [UseCase].
class UseCaseException {
  /// A reference to the wrapped error.
  final Object error;

  /// A reference to the wrapped stack trace.
  final StackTrace stackTrace;

  /// The wrapper's constructor.
  const UseCaseException({required this.error, required this.stackTrace});

  @override
  String toString() => 'UseCaseException: ${Error.safeToString(error)}';
}
