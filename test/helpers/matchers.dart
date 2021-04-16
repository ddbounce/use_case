import 'package:test/test.dart';
import 'package:use_case/use_case.dart';

Matcher useCaseSuccess(expected) => _UseCaseSuccess(expected);
const Matcher useCaseFailure = _UseCaseFailure();

class _UseCaseSuccess<Out> extends Matcher {
  final Object? _expected;

  const _UseCaseSuccess(this._expected);

  @override
  bool matches(item, Map matchState) {
    if (item is UseCaseResult<Out>) {
      return item.data == _expected;
    }

    return false;
  }

  @override
  Description describe(Description description) =>
      description.add('matches ').addDescriptionOf(_expected);
}

class _UseCaseFailure extends Matcher {
  const _UseCaseFailure();

  @override
  bool matches(item, Map matchState) {
    if (item is UseCaseResult) {
      return item.exception != null;
    }

    return false;
  }

  @override
  Description describe(Description description) =>
      description.add('throws exception');
}
