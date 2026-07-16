/// JavaScript compatibility adapter for AstroBox v1 plugins.
///
/// The adapter translates the legacy guest API into the canonical ZeroBox
/// Host API. Native code must not implement AstroBox-specific method names.
const astroBoxLegacyBootstrap = r'''
(() => {
  const callbacks = Object.create(null);
  const lifecycle = [];
  const events = Object.create(null);
  const timers = Object.create(null);
  const virtualFiles = Object.create(null);
  let nextCallback = 0;
  let nextTimer = 0;

  function host(method, args = []) {
    return sendMessage('ZeroBoxHost', JSON.stringify({method, args}));
  }

  function resolveVirtualFile(path) {
    const resolved = virtualFiles[path] || path;
    if (typeof resolved !== 'string') return resolved;
    if (resolved.startsWith('/package/')) return `/plugin/${resolved.slice(9)}`;
    if (resolved.startsWith('/tmp/')) return `/temp/${resolved.slice(5)}`;
    return resolved;
  }

  function parseLegacyJson(value) {
    if (typeof value !== 'string') return value;
    try {
      return JSON.parse(value);
    } catch (_) {
      return value;
    }
  }

  function hasInterconnectListeners() {
    return Object.keys(events).some((name) => name.startsWith('onQAICMessage_'));
  }

  globalThis.console = {
    log: (...args) => host('log.info', args.map(String)),
    debug: (...args) => host('log.debug', args.map(String)),
    info: (...args) => host('log.info', args.map(String)),
    warn: (...args) => host('log.warning', args.map(String)),
    error: (...args) => host('log.error', args.map(String)),
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
      readConfig: async () => JSON.stringify(
        (await host('storage.get', ['__astrobox_config'])) || {}
      ),
      writeConfig: (value) => host('storage.set', [
        '__astrobox_config',
        typeof value === 'string' ? JSON.parse(value) : value,
      ]),
    },
    debug: {
      sendRaw: (value) => host('protocol.send', [value, {encoding: 'base64'}]),
    },
    device: {
      getDeviceList: async () => JSON.stringify(
        (await host('device.list')).map((device) => ({
          name: device.name,
          addr: device.id,
        }))
      ),
      getDeviceState: async (address) => {
        const devices = await host('device.list');
        const device = devices.find((item) => item.id === address);
        if (!device) throw new Error(`Device not found: ${address}`);
        return JSON.stringify({
          name: device.name,
          addr: device.id,
          authkey: '',
          bleservice: {recv: '', sent: ''},
          max_frame_size: 0,
          sec_keys: null,
          network_mtu: 0,
          codename: device.codename || '',
        });
      },
      modifyDeviceState: () => {
        throw new Error('AstroBox modifyDeviceState is not supported by ZeroBox');
      },
      disconnectDevice: () => host('device.disconnect'),
    },
    event: {
      addEventListener: (name, fn) => {
        events[name] = fn;
        if (name.startsWith('onQAICMessage_')) host('interconnect.observe');
      },
      removeEventListener: (name) => {
        delete events[name];
        if (name.startsWith('onQAICMessage_') && !hasInterconnectListeners()) {
          host('interconnect.unobserve');
        }
      },
      sendEvent: (name, payload) => __zbDispatchEvent(name, payload),
    },
    installer: {
      addThirdPartyAppToQueue: (value) =>
        host('device.install', [resolveVirtualFile(value), {type: 'app'}]),
      addWatchFaceToQueue: (value) =>
        host('device.install', [resolveVirtualFile(value), {type: 'watchface'}]),
      addFirmwareToQueue: (value) =>
        host('device.install', [resolveVirtualFile(value), {type: 'firmware'}]),
    },
    interconnect: {
      sendQAICMessage: (packageName, data) =>
        host('interconnect.send', [packageName, data]),
    },
    lifecycle: {
      onLoad: (fn) => lifecycle.push(fn),
    },
    native: {
      regNativeFun: (fn) => {
        const id = `zb_callback_${++nextCallback}`;
        callbacks[id] = fn;
        return id;
      },
    },
    network: {
      fetch: (url, options) => host('network.fetch', [url, options]),
    },
    provider: {
      registerCommunityProvider: () => {
        throw new Error('Provider is not available to AstroBox legacy plugins');
      },
    },
    thirdpartyapp: {
      launchQA: (app, page) => {
        const value = parseLegacyJson(app);
        const packageName = typeof value === 'string'
          ? value
          : value && (value.package_name || value.packageName);
        if (!packageName) throw new Error('Application package name is required');
        return host('device.apps.launch', [packageName, {page}]);
      },
      getThirdPartyAppList: async () => JSON.stringify(
        (await host('device.apps.list')).map((app) => ({
          package_name: app.packageName,
          app_name: app.name,
          version_code: app.versionCode,
          can_remove: app.canRemove,
        }))
      ),
    },
    ui: {
      updatePluginSettingsUI: (nodes) => host('ui.update', [nodes]),
      openPageWithNodes: (nodes) => host('ui.openPage', [nodes]),
      openPageWithUrl: (url) => host('ui.openExternal', [url]),
    },
    filesystem: {
      pickFile: async (options) => {
        const value = parseLegacyJson(options) || {};
        const result = await host('file.pick', [{...value, _legacyText: true}]);
        if (!result) return null;
        virtualFiles[result.name] = result.path;
        return JSON.stringify({
          path: result.name,
          size: result.size,
          text_len: result.textLength,
        });
      },
      readFile: (id, options) => {
        const value = parseLegacyJson(options) || {};
        return host('file.read', [resolveVirtualFile(id), {
          encoding: value.decode_text ? 'text' : 'base64',
          offset: value.offset,
          length: value.len,
          _legacyText: value.decode_text === true,
        }]);
      },
      unloadFile: (id) => {
        const handle = resolveVirtualFile(id);
        delete virtualFiles[id];
        return host('file.remove', [handle]);
      },
    },
  };
  Object.defineProperty(globalThis, 'AstroBox', {
    value: astroBoxApi,
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
    const listener = events[name];
    if (typeof listener === 'function') await listener(payload);
  };
  globalThis.__zbFireTimer = async (id) => {
    const timer = timers[id];
    if (!timer) return;
    if (!timer.repeat) delete timers[id];
    await timer.fn();
  };
})();
''';
