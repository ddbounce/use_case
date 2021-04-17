import 'dart:async';

import 'package:use_case/src/core/use_case.dart';
import 'package:use_case/src/core/use_case_stream_transformer.dart';

typedef EventTransformationHandler<T> = Stream<T> Function(Stream<T>);

class UseCaseStreamController<In, Out> extends StreamView<Out>
    implements StreamSink<In> {
  final StreamController<In> _controller;
  final Stream<Out> _stream;

  bool _isAddingStreamItems = false;

  UseCaseStreamController._(this._controller, this._stream) : super(_stream);

  /// Creates a new [UseCase] stream controller.
  /// When adding events, it will invoke the provided [useCase] and emit
  /// the result as [Out].
  /// If you need to do transformations on either the incoming or outgoing
  /// events, then use [inputStream] and [outputStream].
  ///
  /// ```dart
  /// final controller = UseCaseStreamController(
  ///     useCase: myUseCase,
  ///     inputStream: (stream) => stream.distinct()),
  ///     outputStream: (stream) => stream.map((it) => it + 1),
  /// );
  /// ```
  ///
  /// If you are only interested in the latest [Out] results,
  /// you can cancel any running use cases when new input [In] is added,
  /// by setting [onlyLatestResults] to true.
  ///
  /// See also [StreamController.onListen] and [StreamController.onCancel],
  /// for [onListen] and [onCancel].
  factory UseCaseStreamController({
    required UseCase<In, Out> useCase,
    void Function()? onListen,
    void Function()? onCancel,
    EventTransformationHandler<In>? inputStream,
    EventTransformationHandler<Out>? outputStream,
    bool sync = false,
    bool onlyLatestResults = false,
  }) {
    final controller = StreamController<In>.broadcast(
      onListen: onListen,
      onCancel: onCancel,
      sync: sync,
    );
    final inputTransform = inputStream ?? (stream) => stream;
    final outputTransform = outputStream ?? (stream) => stream;
    final stream = outputTransform(inputTransform(controller.stream).transform(
        UseCaseStreamTransformer(useCase, isCancelable: onlyLatestResults)));

    return UseCaseStreamController._(controller, stream);
  }

  StreamSink<In> get sink => _controller.sink;

  ControllerCallback? get onListen => _controller.onListen;

  set onListen(void Function()? onListenHandler) {
    _controller.onListen = onListenHandler;
  }

  Stream<Out> get stream => _stream;

  ControllerCancelCallback? get onCancel => _controller.onCancel;

  set onCancel(void Function()? onCancelHandler) {
    _controller.onCancel = onCancelHandler;
  }

  bool get isClosed => _controller.isClosed;

  bool get isPaused => _controller.isPaused;

  bool get hasListener => _controller.hasListener;

  @override
  Future<dynamic> get done => _controller.done;

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    if (_isAddingStreamItems) {
      throw StateError(
          'You cannot add an error while items are being added from addStream');
    }

    _controller.addError(error, stackTrace);
  }

  @override
  Future<void> addStream(Stream<In> source, {bool? cancelOnError}) {
    if (_isAddingStreamItems) {
      throw StateError(
          'You cannot add items while items are being added from addStream');
    }

    final completer = Completer<void>();
    var isOnDoneCalled = false;
    final complete = () {
      if (!isOnDoneCalled) {
        isOnDoneCalled = true;
        _isAddingStreamItems = false;
        completer.complete();
      }
    };

    _isAddingStreamItems = true;

    source.listen((In event) {
      add(event);
    }, onError: (Object e, StackTrace s) {
      addError(e, s);

      if (identical(cancelOnError, true)) {
        complete();
      }
    }, onDone: () {
      complete();
    }, cancelOnError: cancelOnError);

    return completer.future;
  }

  @override
  void add(In event) {
    if (_isAddingStreamItems) {
      throw StateError(
          'You cannot add items while items are being added from addStream');
    }

    _controller.add(event);
  }

  @override
  Future<dynamic> close() {
    if (_isAddingStreamItems) {
      throw StateError(
          'You cannot close the subject while items are being added from addStream');
    }

    return _controller.close();
  }
}
