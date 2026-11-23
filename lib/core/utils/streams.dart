import 'dart:async';

/// A stream that can be listened to again and again: every listener gets
/// its own fresh stream from [create]. StreamBuilder re-subscribes whenever
/// its section is rebuilt (e.g. switching pills), which a single-subscription
/// stream rejects with "Stream has already been listened to".
Stream<T> relistenable<T>(Stream<T> Function() create) {
  return Stream<T>.multi((controller) {
    final sub = create().listen(
      controller.addSync,
      onError: controller.addErrorSync,
      onDone: controller.closeSync,
    );
    controller
      ..onPause = sub.pause
      ..onResume = sub.resume
      ..onCancel = sub.cancel;
  });
}

/// Emits [combine] of the latest value of each stream once both have
/// emitted. Errors from either stream are forwarded. Each listener gets its
/// own subscriptions to fresh streams from [a] and [b], so the result can be
/// listened to more than once.
Stream<R> combineLatest2<A, B, R>(
  Stream<A> Function() a,
  Stream<B> Function() b,
  R Function(A, B) combine,
) {
  return Stream<R>.multi((controller) {
    A? lastA;
    B? lastB;
    var hasA = false, hasB = false;

    void emit() {
      if (hasA && hasB) controller.addSync(combine(lastA as A, lastB as B));
    }

    final subA = a().listen((v) {
      lastA = v;
      hasA = true;
      emit();
    }, onError: controller.addErrorSync);
    final subB = b().listen((v) {
      lastB = v;
      hasB = true;
      emit();
    }, onError: controller.addErrorSync);

    controller.onCancel = () async {
      await subA.cancel();
      await subB.cancel();
    };
  });
}
