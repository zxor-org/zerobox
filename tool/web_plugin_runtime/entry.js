import { newQuickJSWASMModuleFromVariant } from "quickjs-emscripten-core";
import releaseVariant from "@jitl/quickjs-singlefile-browser-release-sync";

const modulePromise = newQuickJSWASMModuleFromVariant(releaseVariant);
const instances = new Map();

function requireInstance(id) {
  const instance = instances.get(id);
  if (!instance || instance.closed) throw new Error(`Plugin runtime not found: ${id}`);
  return instance;
}

function pump(instance) {
  if (instance.closed) return;
  instance.deadline = performance.now() + 10000;
  const result = instance.runtime.executePendingJobs();
  if (result.error) {
    const message = instance.context.dump(result.error);
    result.error.dispose();
    throw new Error(String(message));
  }
}

function hostValue(instance, value) {
  if (value === undefined) return instance.context.undefined;
  if (value === null) return instance.context.null;
  const json = JSON.stringify(value);
  const result = instance.context.evalCode(`JSON.parse(${JSON.stringify(json)})`);
  return instance.context.unwrapResult(result);
}

function evaluate(instance, code, name) {
  instance.deadline = performance.now() + 10000;
  const result = instance.context.evalCode(code, name);
  if (result.error) {
    const message = instance.context.dump(result.error);
    result.error.dispose();
    throw new Error(String(message));
  }
  return result.value;
}

async function settle(instance, handle) {
  const promise = instance.context.resolvePromise(handle);
  handle.dispose();
  pump(instance);
  const result = await promise;
  if (result.error) {
    const message = instance.context.dump(result.error);
    result.error.dispose();
    throw new Error(String(message));
  }
  const value = instance.context.dump(result.value);
  result.value.dispose();
  return value;
}

async function create(id, bootstrap, globals, source) {
  await close(id);
  const QuickJS = await modulePromise;
  const runtime = QuickJS.newRuntime({
    memoryLimitBytes: 64 * 1024 * 1024,
    maxStackSizeBytes: 1024 * 1024,
  });
  const context = runtime.newContext();
  const instance = {
    id,
    runtime,
    context,
    deadline: performance.now() + 10000,
    closed: false,
  };
  runtime.setInterruptHandler(() => performance.now() > instance.deadline);
  instances.set(id, instance);

  const sendMessage = context.newFunction("sendMessage", (channel, message) => {
    const channelName = context.getString(channel);
    const payload = context.getString(message);
    const hostResult = globalThis.zeroboxPluginHostCall(id, channelName, payload);
    if (!hostResult || typeof hostResult.then !== "function") {
      return hostValue(instance, hostResult);
    }
    const deferred = context.newPromise();
    Promise.resolve(hostResult).then(
      (value) => {
        if (instance.closed) return;
        const handle = hostValue(instance, value);
        deferred.resolve(handle);
        if (handle.alive && handle !== context.undefined && handle !== context.null) {
          handle.dispose();
        }
        pump(instance);
      },
      (error) => {
        if (instance.closed) return;
        const handle = context.newError(String(error));
        deferred.reject(handle);
        handle.dispose();
        pump(instance);
      },
    );
    deferred.settled.finally(() => deferred.dispose());
    return deferred.handle;
  });
  context.setProp(context.global, "sendMessage", sendMessage);
  sendMessage.dispose();

  try {
    evaluate(instance, bootstrap, "zerobox_abv1_host.js").dispose();
    evaluate(instance, globals, "zerobox_abv1_globals.js").dispose();
    evaluate(instance, source, `${id}/main.js`).dispose();
    return await settle(instance, evaluate(instance, "__zbStartPlugin()", `${id}/start.js`));
  } catch (error) {
    await close(id);
    throw error;
  }
}

async function invoke(id, callback, args) {
  const instance = requireInstance(id);
  return settle(
    instance,
    evaluate(
      instance,
      `__zbInvokeRegistered(${JSON.stringify(callback)}, ${JSON.stringify(args)})`,
      `${id}/callback.js`,
    ),
  );
}

async function dispatchEvent(id, name, payload) {
  const instance = requireInstance(id);
  return settle(
    instance,
    evaluate(
      instance,
      `__zbDispatchEvent(${JSON.stringify(name)}, ${JSON.stringify(payload)})`,
      `${id}/event.js`,
    ),
  );
}

async function fireTimer(id, timerId) {
  const instance = requireInstance(id);
  return settle(
    instance,
    evaluate(instance, `__zbFireTimer(${Number(timerId)})`, `${id}/timer.js`),
  );
}

async function close(id) {
  const instance = instances.get(id);
  if (!instance) return;
  instances.delete(id);
  instance.closed = true;
  instance.context.dispose();
  instance.runtime.dispose();
}

globalThis.ZeroBoxPluginRuntime = { create, invoke, dispatchEvent, fireTimer, close };
