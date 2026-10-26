import assert from "node:assert/strict";
import { clearMocks, mockIPC } from "@tauri-apps/api/mocks";

// Exercise the real store and generated command bindings against Tauri's IPC
// mock. Every scenario imports a fresh webview-lifetime singleton.
const previousWindow = Object.getOwnPropertyDescriptor(globalThis, "window");
const nativeWindow = {
  crypto: globalThis.crypto,
  __TAURI_INTERNALS__: {} as {
    runCallback: (id: number, event: unknown) => void;
  },
};
Object.defineProperty(globalThis, "window", {
  configurable: true,
  value: nativeWindow,
});

const hydrationCommands = [
  "get_default_settings",
  "get_app_settings",
  "check_custom_sounds",
  "is_update_checks_locked",
];
const tick = () => new Promise((resolve) => setTimeout(resolve, 0));
const deferred = () => {
  let resolve!: () => void;
  const promise = new Promise<void>((done) => {
    resolve = done;
  });
  return { promise, resolve };
};

let scenario = 0;
async function fixture() {
  const counts: Record<string, number> = {};
  const listeners = new Map<number, string>();
  const controls = {
    failure: "",
    delayed: "",
    gate: deferred(),
    nativeError: false,
  };
  mockIPC(async (command, args) => {
    const payload = args as Record<string, unknown> | undefined;
    const event = String(payload?.event ?? "");
    const key = command === "plugin:event|listen" ? event : command;
    counts[key] = (counts[key] ?? 0) + 1;
    if (key === controls.failure) {
      if (controls.nativeError) throw "synthetic native error";
      throw new Error("synthetic IPC error");
    }
    if (key === controls.delayed) await controls.gate.promise;
    switch (command) {
      case "plugin:event|listen": {
        const id = Number(payload?.handler);
        listeners.set(id, event);
        return id;
      }
      case "plugin:event|unlisten":
        listeners.delete(Number(payload?.eventId));
        return;
      case "get_app_settings":
      case "get_default_settings":
        return { theme: "system" };
      case "check_custom_sounds":
        return { start: false, stop: false };
      case "is_update_checks_locked":
        return true;
      case "get_available_microphones":
        return [];
      default:
        throw new Error(`Unexpected test command: ${command}`);
    }
  });
  const { useSettingsStore: store } = (await import(
    `./settingsStore.ts?scenario=${scenario++}`
  )) as typeof import("./settingsStore");
  return {
    store,
    counts,
    controls,
    listeners,
    emit: async (event: string, payload: unknown) => {
      for (const [id, name] of listeners) {
        if (name === event) {
          nativeWindow.__TAURI_INTERNALS__.runCallback(id, {
            event,
            id,
            payload,
          });
        }
      }
      await tick();
    },
  };
}

const originalError = console.error;
const expectedErrors: unknown[][] = [];
console.error = (...args: unknown[]) => expectedErrors.push(args);
try {
  const { store, counts, controls, listeners, emit } = await fixture();
  controls.delayed = "get_app_settings";
  let reentrant: Promise<void> | undefined;
  const unsubscribe = store.subscribe(() => {
    reentrant ??= store.getState().initialize();
  });
  const pending = store.getState().initialize();
  for (let i = 0; i < 4; i++) {
    assert.equal(store.getState().initialize(), pending);
  }
  await tick();
  assert.equal(reentrant, pending);
  assert.equal(store.getState().isLoading, true);
  assert.equal(listeners.size, 2);
  for (const command of hydrationCommands) assert.equal(counts[command], 1);
  assert.equal(counts.get_available_microphones, undefined);
  assert.equal(counts.get_available_output_devices, undefined);
  controls.gate.resolve();
  await pending;
  unsubscribe();
  for (let i = 0; i < 4; i++) await store.getState().initialize();
  for (const command of hydrationCommands) assert.equal(counts[command], 1);
  assert.equal(counts["model-state-changed"], 1);
  assert.equal(counts["settings-changed"], 1);
  assert.equal(store.getState().isLoading, false);
  assert.equal(store.getState().settings?.selected_microphone, "Default");

  await emit("model-state-changed", { event_type: "loading_completed" });
  assert.equal(counts.get_app_settings, 2);
  await emit("settings-changed", { setting: "theme" });
  assert.equal(counts.get_app_settings, 3);
  assert.equal(counts.get_available_microphones, undefined);
  await emit("settings-changed", { setting: "selected_microphone" });
  assert.equal(counts.get_app_settings, 4);
  assert.equal(counts.get_available_microphones, 1);
  assert.equal(expectedErrors.length, 0);

  // Either listener can fail before the other registration resolves. Rollback
  // must wait for and remove that late listener before permitting another init.
  for (const failedEvent of ["model-state-changed", "settings-changed"]) {
    const f = await fixture();
    f.controls.failure = failedEvent;
    f.controls.delayed =
      failedEvent === "model-state-changed"
        ? "settings-changed"
        : "model-state-changed";
    const attempt = f.store.getState().initialize();
    let settled = false;
    void attempt.then(() => {
      settled = true;
    });
    await tick();
    assert.equal(settled, false);
    assert.equal(f.store.getState().initialize(), attempt);
    f.controls.gate.resolve();
    await attempt;
    assert.equal(f.listeners.size, 0);
    assert.equal(f.counts["plugin:event|unlisten"], 1);
    assert.equal(f.store.getState().isLoading, false);
    // Listener failure must not discard an otherwise usable settings snapshot.
    assert.equal(f.store.getState().settings?.theme, "system");
    f.controls.failure = "";
    await f.store.getState().initialize();
    assert.equal(f.listeners.size, 2);
    for (const command of hydrationCommands) assert.equal(f.counts[command], 2);
    await f.emit("model-state-changed", {});
    assert.equal(f.counts.get_app_settings, 3);
  }

  // A stale successful snapshot from a previous attempt must not conceal a
  // failed required read on the next attempt (native Result and thrown errors).
  const retry = await fixture();
  for (const failedRead of ["get_default_settings", "get_app_settings"]) {
    retry.controls.failure = failedRead;
    retry.controls.nativeError = failedRead === "get_app_settings";
    await retry.store.getState().initialize();
    assert.equal(retry.listeners.size, 0);
    assert.equal(retry.store.getState().isLoading, false);
  }
  retry.controls.failure = "";
  await retry.store.getState().initialize();
  await retry.store.getState().initialize();
  assert.equal(retry.listeners.size, 2);
  for (const command of hydrationCommands)
    assert.equal(retry.counts[command], 3);

  // Optional probes retain their existing fallback behavior rather than
  // preventing initialization or starting an automatic retry loop.
  for (const optional of ["check_custom_sounds", "is_update_checks_locked"]) {
    const f = await fixture();
    f.controls.failure = optional;
    await f.store.getState().initialize();
    await f.store.getState().initialize();
    assert.equal(f.listeners.size, 2);
    for (const command of hydrationCommands) assert.equal(f.counts[command], 1);
    assert.deepEqual(f.store.getState().customSounds, {
      start: false,
      stop: false,
    });
    assert.equal(
      f.store.getState().updateChecksLocked,
      optional !== "is_update_checks_locked",
    );
  }
  assert.ok(expectedErrors.length > 0);
} finally {
  console.error = originalError;
  clearMocks();
  if (previousWindow)
    Object.defineProperty(globalThis, "window", previousWindow);
  else Reflect.deleteProperty(globalThis, "window");
}

console.log("settings initialization: all assertions passed");
