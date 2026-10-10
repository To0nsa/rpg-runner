import 'dart:async';
import 'dart:collection';
import 'dart:js_interop';

final _scheduler = _BrowserWorkScheduler();

/// Yields through a browser message event, avoiding nested timer throttling.
/// The shared ports retain only pending continuations, never completed work.
Future<void> yieldCooperativeWork() => _scheduler.yieldWork();

final class _BrowserWorkScheduler {
  _BrowserWorkScheduler() {
    _channel.port1.onmessage = ((JSAny? event) {
      _pending.removeFirst().complete();
    }).toJS;
  }

  final _channel = _MessageChannel();
  final _pending = Queue<Completer<void>>();

  Future<void> yieldWork() {
    final completion = Completer<void>();
    _pending.addLast(completion);
    _channel.port2.postMessage(null);
    return completion.future;
  }
}

@JS('MessageChannel')
extension type _MessageChannel._(JSObject _) implements JSObject {
  external _MessageChannel();
  external _MessagePort get port1;
  external _MessagePort get port2;
}

extension type _MessagePort._(JSObject _) implements JSObject {
  external set onmessage(JSFunction callback);
  external void postMessage(JSAny? value);
}
