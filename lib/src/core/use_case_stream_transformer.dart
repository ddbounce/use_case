import 'dart:async';

import 'package:use_case/src/core/use_case.dart';

class _UseCaseStreamSink<In, Out, T extends UseCase<In, Out>>
    implements EventSink<In> {
  final T _useCase;
  final EventSink<Out> _outputSink;
  final bool _isCancelable;
  final Map<int, UseCaseResult<Out>?> _priorityQueue =
      <int, UseCaseResult<Out>?>{};
  int _callIndex = 0, _openCalls = 0;
  bool _isClosePending = false;

  _UseCaseStreamSink(
    this._outputSink,
    this._useCase,
    this._isCancelable,
  );

  @override
  void add(In data) {
    final callIndex = ++_callIndex;

    if (!_isCancelable) {
      _priorityQueue[callIndex] = null;
    }

    _openCalls++;

    _useCase.call(data).then((result) {
      _openCalls--;

      if (_isCancelable) {
        if (callIndex == _callIndex) {
          _handleResult(result);
        }
      } else {
        _priorityQueue[callIndex] = result;
        _maybeDrainPriorityQueue();
      }

      _maybeClose();
    });
  }

  @override
  void addError(Object e, [StackTrace? st]) => _outputSink.addError(e, st);

  @override
  void close() {
    _isClosePending = true;

    if (_openCalls == 0) {
      _outputSink.close();
    }
  }

  @pragma('vm:prefer-inline')
  void _maybeDrainPriorityQueue() {
    if (_priorityQueue.values.every((it) => it != null)) {
      final list = <_PriorityQueueEntry<Out>>[];

      _priorityQueue
          .forEach((key, value) => list.add(_PriorityQueueEntry(key, value!)));
      _priorityQueue.clear();

      list.sort((a, b) => a.index.compareTo(b.index));

      list.map((it) => it.result).forEach(_handleResult);
    }
  }

  @pragma('vm:prefer-inline')
  void _handleResult(UseCaseResult<Out> result) {
    if (result.exception != null) {
      return addError(result.exception!.error, result.exception!.stackTrace);
    }

    _outputSink.add(result.data!);
  }

  @pragma('vm:prefer-inline')
  void _maybeClose() {
    if (_isClosePending && _openCalls == 0) {
      _outputSink.close();
    }
  }
}

/// A stream transformer which takes a [useCase] and either emits
/// its result as [Out], or adds an error to the stream if the [useCase] failed.
/// [isCancelable] will cancel any active [useCase] calls, if new input [In]
/// is received. The default value is false.
///
/// When [isCancelable] is false, the transformer acts like [Stream.asyncExpand].
/// When true, it acts like switchMap from Rx.
class UseCaseStreamTransformer<In, S extends UseCase<In, Out>, Out>
    extends StreamTransformerBase<In, Out> {
  final S useCase;
  final bool isCancelable;

  /// Creates a new [UseCaseStreamTransformer]
  UseCaseStreamTransformer(this.useCase, {this.isCancelable = false});

  @override
  Stream<Out> bind(Stream<In> stream) => Stream.eventTransformed(
      stream, (sink) => _UseCaseStreamSink(sink, useCase, isCancelable));
}

/// A [Stream] extension, which provides ways to map a [UseCase] in the
/// form of stream operators.
extension UseCaseExtension<In> on Stream<In> {
  /// Consumes a [UseCase] and emits results in the same order.
  /// This behavior is similar to [Stream.asyncExpand].
  Stream<Out> useCaseMap<Out, S extends UseCase<In, Out>>(S useCase) =>
      transform(UseCaseStreamTransformer(useCase));

  /// Consumes a [UseCase] and cancels active ones, whenever a new call
  /// occurs.
  /// This behavior is similar to switchMap from Rx.
  Stream<Out> useCaseSwitchMap<Out, S extends UseCase<In, Out>>(S useCase) =>
      transform(UseCaseStreamTransformer(useCase, isCancelable: true));
}

class _PriorityQueueEntry<Out> {
  final int index;
  final UseCaseResult<Out> result;

  _PriorityQueueEntry(this.index, this.result);
}
