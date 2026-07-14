import 'dart:async';

typedef PluginHostCall =
    FutureOr<Object?> Function(String method, List<Object?> arguments);

abstract interface class PluginRuntime {
  Future<void> start({
    required String pluginId,
    required String pluginName,
    required String pluginVersion,
    required String runtimeVersion,
    required String source,
    required PluginHostCall hostCall,
  });

  Future<void> invokeCallback(String callbackId, [String? value]);

  Future<Object?> invokeRegistered(String callbackId, List<String> arguments);

  Future<void> dispatchEvent(String name, String payload);

  Future<void> close();
}

const abV1PluginBootstrap = r'''
(() => {
  const callbacks = Object.create(null);
  const lifecycle = [];
  const events = Object.create(null);
  const timers = Object.create(null);
  let nextCallback = 0;
  let nextTimer = 0;

  function host(method, args = []) {
    return sendMessage('ZeroBoxHost', JSON.stringify({method, args}));
  }

  globalThis.console = {
    log: (...args) => host('console.log', args.map(String)),
    info: (...args) => host('console.info', args.map(String)),
    warn: (...args) => host('console.warn', args.map(String)),
    error: (...args) => host('console.error', args.map(String)),
  };

  globalThis.__zbSetRuntimeGlobals = (id, name, version, runtimeVersion) => {
    const values = {
      RUNTIME: 'AstroBox',
      RUNTIME_VERSION: runtimeVersion,
      PLUGIN_NAME: name,
      PLUGIN_PATH: `zerobox-plugin://${id}`,
      PLUGIN_VERSION: version,
    };
    for (const [key, value] of Object.entries(values)) {
      Object.defineProperty(globalThis, key, {
        value,
        writable: false,
        configurable: false,
        enumerable: true,
      });
    }
  };

  function scheduleTimer(fn, delay, repeat) {
    if (typeof fn !== 'function') throw new TypeError('Timer callback must be a function');
    const id = ++nextTimer;
    timers[id] = {fn, repeat};
    host('runtime.setTimer', [id, Number(delay) || 0, repeat]);
    return id;
  }

  globalThis.setTimeout = (fn, delay = 0) => scheduleTimer(fn, delay, false);
  globalThis.setInterval = (fn, delay = 0) => scheduleTimer(fn, delay, true);
  globalThis.clearTimeout = globalThis.clearInterval = (id) => {
    delete timers[id];
    host('runtime.clearTimer', [Number(id)]);
  };

  const astroBoxApi = {
    config: {
      readConfig: () => host('config.readConfig'),
      writeConfig: (value) => host('config.writeConfig', [value]),
    },
    debug: {
      sendRaw: (value) => host('debug.sendRaw', [value]),
    },
    device: {
      getDeviceList: () => host('device.getDeviceList'),
      getDeviceState: (address) => host('device.getDeviceState', [address]),
      modifyDeviceState: (address, state) => host('device.modifyDeviceState', [address, state]),
      disconnectDevice: () => host('device.disconnectDevice'),
    },
    event: {
      addEventListener: (name, fn) => {
        host('permission.require', ['event']);
        (events[name] ??= []).push(fn);
      },
      removeEventListener: (name) => {
        host('permission.require', ['event']);
        delete events[name];
      },
      sendEvent: (name, payload) => {
        host('permission.require', ['event']);
        return __zbDispatchEvent(name, payload);
      },
    },
    installer: {
      addThirdPartyAppToQueue: (value) => host('installer.addThirdPartyAppToQueue', [value]),
      addWatchFaceToQueue: (value) => host('installer.addWatchFaceToQueue', [value]),
      addFirmwareToQueue: (value) => host('installer.addFirmwareToQueue', [value]),
    },
    interconnect: {
      sendQAICMessage: (packageName, data) =>
        host('interconnect.sendQAICMessage', [packageName, data]),
    },
    lifecycle: {
      onLoad: (fn) => {
        host('permission.require', ['lifecycle']);
        lifecycle.push(fn);
      },
    },
    native: {
      regNativeFun: (fn) => {
        host('permission.require', ['native']);
        const id = `zb_callback_${++nextCallback}`;
        callbacks[id] = fn;
        return id;
      },
    },
    network: {
      fetch: (url, options) => host('network.fetch', [url, options]),
    },
    provider: {
      registerCommunityProvider: (provider) =>
        host('provider.registerCommunityProvider', [provider]),
    },
    thirdpartyapp: {
      launchQA: (app, page) => host('thirdpartyapp.launchQA', [app, page]),
      getThirdPartyAppList: () => host('thirdpartyapp.getThirdPartyAppList'),
    },
    ui: {
      updatePluginSettingsUI: (nodes) => host('ui.updatePluginSettingsUI', [nodes]),
      openPageWithNodes: (nodes) => host('ui.openPageWithNodes', [nodes]),
      openPageWithUrl: (url) => host('ui.openPageWithUrl', [url]),
    },
    filesystem: {
      pickFile: (options) => host('filesystem.pickFile', [options]),
      readFile: (id, options) => host('filesystem.readFile', [id, options]),
      unloadFile: (id) => host('filesystem.unloadFile', [id]),
    },
  };
  Object.defineProperty(globalThis, 'AstroBox', {
    value: astroBoxApi,
    writable: false,
    configurable: false,
    enumerable: true,
  });

  const zeroBoxApi = {
    filesystem: {
      readFile: (path, options) => host('sandbox.readFile', [path, options]),
      writeFile: (path, data, options) =>
        host('sandbox.writeFile', [path, data, options]),
      listDirectory: async (path) =>
        JSON.parse(await host('sandbox.listDirectory', [path])),
      stat: async (path) => JSON.parse(await host('sandbox.stat', [path])),
      remove: (path) => host('sandbox.remove', [path]),
    },
  };
  Object.defineProperty(globalThis, 'ZeroBox', {
    value: zeroBoxApi,
    writable: false,
    configurable: false,
    enumerable: true,
  });

  globalThis.__zbStartPlugin = async () => {
    for (const fn of lifecycle) await fn();
  };
  globalThis.__zbInvokeRegistered = async (id, args) => {
    const fn = callbacks[id];
    if (typeof fn !== 'function') throw new Error(`Unknown callback: ${id}`);
    return await fn(...args);
  };
  globalThis.__zbDispatchEvent = async (name, payload) => {
    const listeners = events[name] ?? [];
    for (const fn of listeners) await fn(payload);
  };
  globalThis.__zbFireTimer = async (id) => {
    const timer = timers[id];
    if (!timer) return;
    if (!timer.repeat) delete timers[id];
    await timer.fn();
  };
})();
''';
