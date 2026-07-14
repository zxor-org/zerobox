import 'dart:math' as math;
import 'dart:typed_data';

import 'package:wasm_run_flutter/wasm_run_flutter.dart';
import 'package:zerobox/src/core/wasm/wasm_runtime.dart';

final class WasmOpusDecoder {
  WasmOpusDecoder._(
    this._scope,
    this._instance,
    this._memory,
    this._decoderPointer,
    this._mappingPointer,
    this._inputPointer,
    this._outputPointer,
    this._inputCapacity,
  );

  static const _assetPath = 'assets/wasm/opus_frame_decoder.wasm';
  static const _outputCapacity = 5760;
  static const _initialInputCapacity = 4096;

  final WasmScope _scope;
  final ScopedWasmInstance _instance;
  final WasmMemory _memory;
  final int _decoderPointer;
  final int _mappingPointer;
  int _inputPointer;
  final int _outputPointer;
  int _inputCapacity;
  bool _disposed = false;

  late final WasmFunction _decodeFunction = _instance.function('k');
  late final WasmFunction _destroyFunction = _instance.function('l');
  late final WasmFunction _mallocFunction = _instance.function('j');
  late final WasmFunction _freeFunction = _instance.function('m');

  static Future<WasmOpusDecoder> create({
    int sampleRate = 16000,
    int channels = 1,
  }) async {
    if (channels != 1) {
      throw ArgumentError.value(channels, 'channels', 'only mono is supported');
    }

    final scope = WasmRuntime.shared.openScope('system.opus-decoder');
    try {
      final instance = await scope.instantiateAsset(
        _assetPath,
        configure: _configureEmscriptenImports,
      );
      final memory = instance.memory('g');
      instance.function('h')();

      final malloc = instance.function('j');
      final mappingPointer = _intResult(malloc([channels]));
      final inputPointer = _intResult(malloc([_initialInputCapacity]));
      final outputPointer = _intResult(
        malloc([_outputCapacity * channels * Float32List.bytesPerElement]),
      );
      if (mappingPointer == 0 || inputPointer == 0 || outputPointer == 0) {
        throw StateError('libopus WASM memory allocation failed');
      }
      memory.view[mappingPointer] = 0;

      final decoderPointer = _intResult(
        instance.function('i')([
          sampleRate,
          channels,
          1,
          0,
          mappingPointer,
          0,
          0,
        ]),
      );
      if (decoderPointer == 0) {
        throw StateError('libopus WASM decoder creation failed');
      }

      return WasmOpusDecoder._(
        scope,
        instance,
        memory,
        decoderPointer,
        mappingPointer,
        inputPointer,
        outputPointer,
        _initialInputCapacity,
      );
    } catch (_) {
      scope.dispose();
      rethrow;
    }
  }

  Float32List decode(Uint8List packet) {
    _ensureActive();
    if (packet.isEmpty) return Float32List(0);
    _ensureInputCapacity(packet.length);

    _memory.view.setRange(_inputPointer, _inputPointer + packet.length, packet);
    final samples = _intResult(
      _decodeFunction([
        _decoderPointer,
        _inputPointer,
        packet.length,
        _outputPointer,
      ]),
    );
    if (samples < 0) {
      throw StateError(_opusError(samples));
    }
    if (samples > _outputCapacity) {
      throw StateError('libopus returned too many samples: $samples');
    }

    final view = _memory.view;
    return Float32List.fromList(
      Float32List.view(
        view.buffer,
        view.offsetInBytes + _outputPointer,
        samples,
      ),
    );
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    try {
      _destroyFunction([_decoderPointer]);
      _freeFunction([_decoderPointer]);
      _freeFunction([_mappingPointer]);
      _freeFunction([_inputPointer]);
      _freeFunction([_outputPointer]);
    } finally {
      _scope.dispose();
    }
  }

  void _ensureInputCapacity(int required) {
    if (required <= _inputCapacity) return;
    final replacement = _intResult(_mallocFunction([required]));
    if (replacement == 0) {
      throw StateError('libopus WASM input allocation failed');
    }
    _freeFunction([_inputPointer]);
    _inputPointer = replacement;
    _inputCapacity = required;
  }

  void _ensureActive() {
    if (_disposed) throw StateError('Opus decoder is disposed');
  }

  static void _configureEmscriptenImports(WasmInstanceBuilder builder) {
    builder
      ..addImport(
        'a',
        'a',
        WasmFunction(
          math.cos,
          params: const [ValueTy.f64],
          results: const [ValueTy.f64],
        ),
      )
      ..addImport(
        'a',
        'b',
        WasmFunction.voidReturn(
          (int code) => throw StateError('libopus exited with code $code'),
          params: const [ValueTy.i32],
        ),
      )
      ..addImport('a', 'c', WasmFunction.voidReturn(() {}, params: const []))
      ..addImport(
        'a',
        'd',
        WasmFunction.voidReturn(
          () => throw StateError('libopus aborted'),
          params: const [],
        ),
      )
      ..addImport(
        'a',
        'e',
        WasmFunction(
          (int _, double _) => 0,
          params: const [ValueTy.i32, ValueTy.f64],
          results: const [ValueTy.i32],
        ),
      )
      ..addImport(
        'a',
        'f',
        WasmFunction(
          (int _) => 0,
          params: const [ValueTy.i32],
          results: const [ValueTy.i32],
        ),
      );
  }

  static int _intResult(List<Object?> result) {
    if (result.length != 1 || result.first is! int) {
      throw StateError('Unexpected WASM result: $result');
    }
    return result.first! as int;
  }

  static String _opusError(int code) => switch (code) {
    -1 => 'libopus: invalid argument',
    -2 => 'libopus: output buffer too small',
    -3 => 'libopus: internal error',
    -4 => 'libopus: invalid packet',
    -5 => 'libopus: unimplemented operation',
    -6 => 'libopus: invalid state',
    -7 => 'libopus: allocation failed',
    _ => 'libopus: unknown error $code',
  };
}
