import assert from "node:assert/strict";

export function trackModuleUsage(moduleExports) {
  const used = new Set();
  const wrapped = new Map();
  const proxy = new Proxy(moduleExports, {
    get(target, prop, receiver) {
      const value = Reflect.get(target, prop, receiver);
      if (typeof prop !== "string" || typeof value !== "function") {
        return value;
      }
      const cached = wrapped.get(prop);
      if (cached) {
        return cached;
      }
      const instrumented = (...args) => {
        used.add(prop);
        return value(...args);
      };
      wrapped.set(prop, instrumented);
      return instrumented;
    },
  });
  return { proxy, used };
}

export function assertAllExportedFunctionsUsed(moduleExports, used) {
  const exportedFunctions = Object.entries(moduleExports)
    .filter(([, value]) => typeof value === "function")
    .map(([name]) => name)
    .sort();
  const usedFunctions = Array.from(used).sort();
  assert.deepEqual(usedFunctions, exportedFunctions);
}
