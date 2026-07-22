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
  Map<String, Object?> get diagnostics;

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
      info: (id) => host('device.info', [id]),
      connect: (id) => host('device.connect', [id]),
      disconnect: (id) => host('device.disconnect', [id]),
      apps: {
        list: (id) => host('device.apps.list', [id]),
        launch: (packageName, options) =>
          host('device.apps.launch', [packageName, options]),
        uninstall: (packageName) => host('device.apps.uninstall', [packageName]),
      },
      install: (path, options) => host('device.install', [path, options]),
    },
    protocol: {
      send: (data, options) => host('protocol.send', [data, options]),
      request: (data, options) => host('protocol.request', [data, options]),
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
    os: {
      arch: () => host('os.arch'),
      hostname: () => host('os.hostname'),
      locale: () => host('os.locale'),
      platform: () => host('os.platform'),
      version: () => host('os.version'),
      language: () => host('os.language'),
      appearance: () => host('os.appearance'),
      timezone: () => host('os.timezone'),
    },
    watchface: {
      list: (deviceId) => host('watchface.list', [deviceId]),
      set: (watchfaceId, deviceId) =>
        host('watchface.set', [watchfaceId, deviceId]),
    },
    appside: {
      list: () => host('appside.list'),
      start: (appId) => host('appside.start', [appId]),
      stop: (appId) => host('appside.stop', [appId]),
      send: (appId, hexData) => host('appside.send', [appId, hexData]),
      inject: (appId, hexData) => host('appside.inject', [appId, hexData]),
      sessions: () => host('appside.sessions'),
      events: (appId) => host('appside.events', [appId]),
      clearEvents: (appId) => host('appside.clearEvents', [appId]),
    },
    ui: (() => {
      const n = (type, props, children) => {
        const p = {};
        for (const [k, v] of Object.entries(props || {})) {
          p[k] = typeof v === 'function' ? registerCallback(v) : v;
        }
        return { type, props: p, children: children || [] };
      };
      const e = (type) => (...args) => {
        const props = args.length === 2 ? args[0] : {};
        const kids = args.length === 2 ? args[1] : args[0];
        const arr = Array.isArray(kids) ? kids : kids != null ? [kids] : [];
        return n(type, props, arr);
      };
      return {
        render: (tree) => host('ui.render', [tree]),
        update: (nodes) => host('ui.update', [nodes]),
        openPage: (tree) => host('ui.openPage', [tree]),
        openExternal: (url) => host('ui.openExternal', [url]),
        getRenderSize: () => host('ui.getRenderSize'),
        dialog: (opts) => host('ui.dialog', [opts]),
        callback: registerCallback,
        action: (fn, render) => registerCallback(async (...args) => {
          const result = await fn(...args);
          if (typeof render === 'function') await render();
          return result;
        }),
        Column: e('Column'), Row: e('Row'), LazyColumn: e('LazyColumn'),
        Spacer: () => n('Spacer', {}, []),
        Text: (value, p) => n('Text', { value, ...p }, []),
        Button: (label, p) => n('Button', { text: label, ...p }, []),
        Image: (src, p) => n('Image', { src, ...p }, []),
        Divider: (p) => n('Divider', p || {}, []),
        Badge: (p, child) => n('Badge', p || {}, [child]),
        TextField: (p) => n('TextField', p || {}, []),
        Switch: (checked, p) => n('Switch', { checked, ...p }, []),
        Checkbox: (checked, p) => n('Checkbox', { checked, ...p }, []),
        Slider: (value, p) => n('Slider', { value, ...p }, []),
        Dropdown: (value, p) => n('Dropdown', { value, ...p }, []),
        Card: (p, child) => n('Card', p || {}, [child]),
        Modal: (p, child) => n('Modal', p || {}, [child]),
        Tooltip: (p, child) => n('Tooltip', p || {}, [child]),
        Tabs: (p) => n('Tabs', p || {}, []),
        TabContent: (tabId, activeId, child) => n('TabContent', { tabId, activeId }, [child]),
        CircularProgress: (p) => n('CircularProgress', p || {}, []),
        LinearProgress: (value, p) => n('LinearProgress', { value, ...p }, []),
      };
    })(),
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
