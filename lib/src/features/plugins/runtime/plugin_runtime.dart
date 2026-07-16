import 'dart:async';
import 'dart:typed_data';

typedef PluginHostCall =
    FutureOr<Object?> Function(String method, List<Object?> arguments);

void settlePluginHostCall(Object? result, void Function() dispatch) {
  if (result is! Future) return;
  unawaited(
    result.then<void>(
      (_) => scheduleMicrotask(dispatch),
      onError: (_, _) => scheduleMicrotask(dispatch),
    ),
  );
}

abstract interface class PluginRuntime {
  Future<void> start({
    required String pluginId,
    required String pluginName,
    required String pluginVersion,
    required String runtimeVersion,
    required Uint8List entryBytes,
    required String bootstrap,
    required PluginHostCall hostCall,
  });

  Future<void> invokeCallback(String callbackId, [String? value]);

  Future<Object?> invokeRegistered(String callbackId, List<Object?> arguments);

  Future<void> dispatchEvent(String name, String payload);

  Future<void> close();
}

const zeroBoxPluginBootstrap = r'''
(() => {
  const callbacks = Object.create(null);
  const events = Object.create(null);
  const timers = Object.create(null);
  let nextCallback = 0;
  let nextTimer = 0;

  function host(method, args = []) {
    return sendMessage('ZeroBoxHost', JSON.stringify({method, args}));
  }

  function registerCallback(fn) {
    if (typeof fn !== 'function') throw new TypeError('Expected a function');
    const id = `zb_callback_${++nextCallback}`;
    callbacks[id] = fn;
    return id;
  }

  function scheduleTimer(fn, delay, repeat) {
    const id = ++nextTimer;
    timers[id] = {fn, repeat};
    host('runtime.setTimer', [id, Number(delay) || 0, repeat]);
    return id;
  }

  globalThis.console = {
    log: (...args) => host('log.info', args.map(String)),
    debug: (...args) => host('log.debug', args.map(String)),
    info: (...args) => host('log.info', args.map(String)),
    warn: (...args) => host('log.warning', args.map(String)),
    error: (...args) => host('log.error', args.map(String)),
  };

  globalThis.__zbSetRuntimeGlobals = (id, name, version, runtimeVersion) => {
    Object.defineProperty(globalThis, 'PLUGIN', {
      value: Object.freeze({id, name, version, runtimeVersion}),
      writable: false,
      configurable: false,
    });
  };

  globalThis.setTimeout = (fn, delay = 0) => scheduleTimer(fn, delay, false);
  globalThis.setInterval = (fn, delay = 0) => scheduleTimer(fn, delay, true);
  globalThis.clearTimeout = globalThis.clearInterval = (id) => {
    delete timers[id];
    host('runtime.clearTimer', [Number(id)]);
  };

  const api = {
    storage: {
      get: (key) => host('storage.get', [key]),
      set: (key, value) => host('storage.set', [key, value]),
      remove: (key) => host('storage.remove', [key]),
      clear: () => host('storage.clear'),
    },
    file: {
      read: (path, options) => host('file.read', [path, options]),
      write: (path, data, options) => host('file.write', [path, data, options]),
      list: (path) => host('file.list', [path]),
      stat: (path) => host('file.stat', [path]),
      mkdir: (path) => host('file.mkdir', [path]),
      copy: (source, destination) =>
        host('file.copy', [source, destination]),
      move: (source, destination) =>
        host('file.move', [source, destination]),
      remove: (path) => host('file.remove', [path]),
      pick: (options) => host('file.pick', [options]),
      unload: (path, options) => host('file.unload', [path, options]),
    },
    network: {
      fetch: (url, options) => host('network.fetch', [url, options]),
      download: (url, path, options) =>
        host('network.download', [url, path, options]),
    },
    interconnect: {
      send: (packageName, data) =>
        host('interconnect.send', [packageName, data]),
      onMessage: async (fn) => {
        await host('interconnect.observe');
        events.interconnect = (payload) => fn(
          typeof payload === 'string' ? JSON.parse(payload) : payload
        );
        return () => {
          delete events.interconnect;
          return host('interconnect.unobserve');
        };
      },
    },
    provider: {
      register: (definition) => {
        const value = {...definition};
        for (const key of ['categories', 'query', 'detail', 'download']) {
          if (typeof value[key] === 'function') value[key] = registerCallback(value[key]);
        }
        return host('provider.register', [value]);
      },
      unregister: (id) => host('provider.unregister', [id]),
    },
    device: {
      list: () => host('device.list'),
      info: () => host('device.info'),
      connect: (id) => host('device.connect', [id]),
      disconnect: () => host('device.disconnect'),
      apps: {
        list: () => host('device.apps.list'),
        launch: (packageName, options) =>
          host('device.apps.launch', [packageName, options]),
        uninstall: (packageName) => host('device.apps.uninstall', [packageName]),
      },
      install: (path, options) => host('device.install', [path, options]),
    },
    protocol: {
      send: (data, options) => host('protocol.send', [data, options]),
      observe: async (fn) => {
        await host('protocol.observe');
        events['protocol.data'] = (payload) => fn(
          typeof payload === 'string' ? JSON.parse(payload) : payload
        );
        return () => {
          delete events['protocol.data'];
          return host('protocol.unobserve');
        };
      },
    },
    ui: {
      update: (nodes) => host('ui.update', [nodes]),
      openPage: (nodes) => host('ui.openPage', [nodes]),
      openExternal: (url) => host('ui.openExternal', [url]),
      callback: registerCallback,
    },
    wasm: {
      load: async (path, options) => {
        const id = await host('wasm.load', [path, options]);
        return Object.freeze({
          id,
          call: (name, ...args) => host('wasm.call', [id, name, args]),
          readMemory: (offset, length, memory = 'memory') =>
            host('wasm.memory.read', [id, memory, offset, length]),
          writeMemory: (offset, data, memory = 'memory') =>
            host('wasm.memory.write', [id, memory, offset, data]),
          dispose: () => host('wasm.dispose', [id]),
        });
      },
    },
  };

  Object.defineProperty(globalThis, 'ZeroBox', {
    value: Object.freeze(api),
    writable: false,
    configurable: false,
  });

  globalThis.__zbInvokeRegistered = async (id, args) => {
    const callback = callbacks[id];
    if (typeof callback !== 'function') throw new Error(`Callback not found: ${id}`);
    return await callback(...args);
  };
  globalThis.__zbDispatchEvent = async (name, payload) => {
    const callback = events[name];
    if (typeof callback === 'function') await callback(payload);
  };
  globalThis.__zbFireTimer = async (id) => {
    const timer = timers[id];
    if (!timer) return;
    if (!timer.repeat) delete timers[id];
    await timer.fn();
  };
  globalThis.__zbStartPlugin = async () => {
    if (typeof globalThis.activate === 'function') await globalThis.activate(PLUGIN);
  };
})();
''';
