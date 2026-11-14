// JS-only async primitives: Promise[T] bridging + async fetch.
//
// Exposes a minimal surface so consumers can chain concurrent LLM requests
// via moonbitlang async intrinsics (%async.suspend / %async.run) without
// taking a dependency on moonbitlang/async.
//
// This file is compiled only for the "js" target (see moon.pkg).

///|
/// Opaque JS value type for FFI bridging. Treat as a black-box handle.
#external
pub type JsValue

///|
/// Zero-cost bitcast between type-compatible values — emits no JS code.
/// Useful for reinterpreting `Promise[T]` as `JsValue` when calling FFI.
pub fn[A, B] identity(a : A) -> B = "%identity"

///|
/// Opaque JS Promise type. Obtained from async FFI helpers and awaited
/// via `Promise::wait` inside an `async` function.
#external
pub type Promise[T]

///|
pub fn[T] Promise::to_any(self : Promise[T]) -> JsValue = "%identity"

///|
/// Compiler intrinsic — suspends an async function until ok/err is invoked.
pub async fn[T, E : Error] async_suspend(
  f : ((T) -> Unit, (E) -> Unit) -> Unit,
) -> T raise E = "%async.suspend"

///|
/// Compiler intrinsic — runs an async function to completion on the event loop.
pub fn run_async(f : async () -> Unit noraise) -> Unit = "%async.run"

///|
/// Bridge a JS Promise's then/catch into MoonBit async resolvers.
extern "js" fn _promise_then_catch(
  p : JsValue,
  ok : (JsValue) -> Unit,
  err : (JsValue) -> Unit,
) -> Unit =
  #| (p, ok, err) => { p.then(v => ok(v)).catch(e => err(e)); }

///|
/// Await a JS Promise from inside an `async` function. Rethrows any
/// promise rejection as an error value.
pub async fn[T] Promise::wait(self : Promise[T]) -> T {
  async_suspend(fn(ok, err) {
    _promise_then_catch(self.to_any(), fn(v : JsValue) { ok(identity(v)) }, fn(
      e : JsValue,
    ) {
      err(identity(e))
    })
  })
}

///|
/// JS-only non-streaming async fetch. Returns the response body as a string.
/// On HTTP/network error, returns a string prefixed with "ERROR: " — the caller
/// should check the prefix. `timeout_sec = 0` disables the timeout.
///
/// Intended for parallel LLM requests where SSE streaming is unnecessary
/// (e.g. summarization). Uses the host's native `fetch()` (Node 18+ / browser).
pub fn fetch_text_async(
  url : String,
  http_method : String,
  headers_json : String,
  body : String,
  timeout_sec : Int,
) -> Promise[String] {
  js_fetch_text_async(url, http_method, headers_json, body, timeout_sec)
}

///|
extern "js" fn js_fetch_text_async(
  url : String,
  http_method : String,
  headers_json : String,
  body : String,
  timeout_sec : Int,
) -> Promise[String] =
  #| (url, method, headersJson, body, timeoutSec) => {
  #|   return (async () => {
  #|     try {
  #|       const headers = JSON.parse(headersJson);
  #|       const controller = new AbortController();
  #|       const timer = timeoutSec > 0
  #|         ? setTimeout(() => controller.abort(), timeoutSec * 1000)
  #|         : null;
  #|       try {
  #|         const res = await fetch(url, {
  #|           method,
  #|           headers,
  #|           body: body && body.length > 0 ? body : undefined,
  #|           signal: controller.signal,
  #|         });
  #|         const text = await res.text();
  #|         if (!res.ok) return 'ERROR: HTTP ' + res.status + ': ' + text;
  #|         return text;
  #|       } finally {
  #|         if (timer) clearTimeout(timer);
  #|       }
  #|     } catch (e) {
  #|       return 'ERROR: ' + (e && e.message ? e.message : String(e));
  #|     }
  #|   })();
  #| }
