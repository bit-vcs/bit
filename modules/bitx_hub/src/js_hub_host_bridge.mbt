///| JS host bridge for Hub exports (shares globalThis.__bitGitJsState with src/lib).

///|
priv struct HubJsHostFs {
  host_id : Int
}

///|
fn hub_make_host_fs(host_id : Int) -> HubJsHostFs {
  { host_id, }
}

// --- extern "js" FFI (same host state as src/lib) ---

///|
extern "js" fn hub_js_host_last_error() -> String =
  #| () => globalThis.__bitGitJsLastError ?? ""

///|
extern "js" fn hub_js_host_write_file(
  host_id : Int,
  path : String,
  content : FixedArray[Byte],
) -> String? =
  #| (hostId, path, content) => {
  #|   const state = globalThis.__bitGitJsState ??= { nextHostId: 1, hosts: new Map() };
  #|   const host = state.hosts.get(hostId);
  #|   if (!host) return `host ${hostId} not found`;
  #|   try { host.writeFile(path, Uint8Array.from(content ?? [])); return undefined; }
  #|   catch (e) { return String(e?.message ?? e); }
  #| }

///|
extern "js" fn hub_js_host_write_string(
  host_id : Int,
  path : String,
  content : String,
) -> String? =
  #| (hostId, path, content) => {
  #|   const state = globalThis.__bitGitJsState ??= { nextHostId: 1, hosts: new Map() };
  #|   const host = state.hosts.get(hostId);
  #|   if (!host) return `host ${hostId} not found`;
  #|   try { host.writeString(path, content); return undefined; }
  #|   catch (e) { return String(e?.message ?? e); }
  #| }

///|
extern "js" fn hub_js_host_mkdir_p(host_id : Int, path : String) -> String? =
  #| (hostId, path) => {
  #|   const state = globalThis.__bitGitJsState ??= { nextHostId: 1, hosts: new Map() };
  #|   const host = state.hosts.get(hostId);
  #|   if (!host) return `host ${hostId} not found`;
  #|   try { host.mkdirP(path); return undefined; }
  #|   catch (e) { return String(e?.message ?? e); }
  #| }

///|
extern "js" fn hub_js_host_read_file(
  host_id : Int,
  path : String,
) -> FixedArray[Byte]? =
  #| (hostId, path) => {
  #|   const state = globalThis.__bitGitJsState ??= { nextHostId: 1, hosts: new Map() };
  #|   const host = state.hosts.get(hostId);
  #|   if (!host) { globalThis.__bitGitJsLastError = `host ${hostId} not found`; return undefined; }
  #|   try {
  #|     const v = host.readFile(path);
  #|     if (v instanceof Uint8Array) return Uint8Array.from(v);
  #|     if (v instanceof ArrayBuffer) return new Uint8Array(v.slice(0));
  #|     if (Array.isArray(v)) return Uint8Array.from(v, x => Number(x) & 0xff);
  #|     if (typeof v === 'string') return new TextEncoder().encode(v);
  #|     globalThis.__bitGitJsLastError = 'readFile must return Uint8Array/ArrayBuffer/Array/string';
  #|     return undefined;
  #|   } catch (e) { globalThis.__bitGitJsLastError = String(e?.message ?? e); return undefined; }
  #| }

///|
extern "js" fn hub_js_host_readdir(
  host_id : Int,
  path : String,
) -> FixedArray[String]? =
  #| (hostId, path) => {
  #|   const state = globalThis.__bitGitJsState ??= { nextHostId: 1, hosts: new Map() };
  #|   const host = state.hosts.get(hostId);
  #|   if (!host) { globalThis.__bitGitJsLastError = `host ${hostId} not found`; return undefined; }
  #|   try {
  #|     const entries = host.readdir(path);
  #|     return Array.from(entries, (item) => String(item));
  #|   } catch (e) { globalThis.__bitGitJsLastError = String(e?.message ?? e); return undefined; }
  #| }

///|
extern "js" fn hub_js_host_is_dir(host_id : Int, path : String) -> Bool =
  #| (hostId, path) => {
  #|   const state = globalThis.__bitGitJsState ??= { nextHostId: 1, hosts: new Map() };
  #|   const host = state.hosts.get(hostId);
  #|   return host?.isDir?.(path) ?? false;
  #| }

///|
extern "js" fn hub_js_host_is_file(host_id : Int, path : String) -> Bool =
  #| (hostId, path) => {
  #|   const state = globalThis.__bitGitJsState ??= { nextHostId: 1, hosts: new Map() };
  #|   const host = state.hosts.get(hostId);
  #|   return host?.isFile?.(path) ?? false;
  #| }

///|
extern "js" fn hub_js_host_mtime(host_id : Int, path : String) -> FixedArray[Int]? =
  #| (hostId, path) => {
  #|   const state = globalThis.__bitGitJsState ??= { nextHostId: 1, hosts: new Map() };
  #|   const host = state.hosts.get(hostId);
  #|   if (!host) {
  #|     globalThis.__bitGitJsLastError = `host ${hostId} not found`;
  #|     return undefined;
  #|   }
  #|   if (typeof host.mtime !== 'function') {
  #|     globalThis.__bitGitJsLastError = 'host.mtime(path) is required';
  #|     return undefined;
  #|   }
  #|   try {
  #|     const value = host.mtime(path);
  #|     if (!Array.isArray(value) || value.length !== 2) {
  #|       globalThis.__bitGitJsLastError = 'host.mtime(path) must return [seconds, nanoseconds]';
  #|       return undefined;
  #|     }
  #|     const seconds = Number(value[0]);
  #|     const nanoseconds = Number(value[1]);
  #|     if (!Number.isInteger(seconds) || !Number.isInteger(nanoseconds)) {
  #|       globalThis.__bitGitJsLastError = 'host.mtime(path) must return integer seconds and nanoseconds';
  #|       return undefined;
  #|     }
  #|     return [seconds, nanoseconds];
  #|   } catch (error) {
  #|     globalThis.__bitGitJsLastError = String(error?.message ?? error);
  #|     return undefined;
  #|   }
  #| }

// --- Trait implementations ---

///|
fn bytes_from_array(arr : FixedArray[Byte]) -> Bytes {
  Bytes::from_array(arr)
}

///|
impl @bit.FileSystem for HubJsHostFs with fn mkdir_p(self, path) {
  match hub_js_host_mkdir_p(self.host_id, path) {
    Some(e) => raise @bit.GitError::IoError(e)
    None => ()
  }
}

///|
impl @bit.FileSystem for HubJsHostFs with fn write_file(self, path, content) {
  // A `FixedArray` rather than an `Array`: `Array` is deprecated at the JS FFI
  // boundary, and a `FixedArray[Byte]` arrives as a `Uint8Array`, which the
  // bridge's `Uint8Array.from` reads exactly as it read the plain array.
  let arr = FixedArray::make(content.length(), b'\x00')
  for i in 0..<content.length() {
    arr[i] = content[i]
  }
  match hub_js_host_write_file(self.host_id, path, arr) {
    Some(e) => raise @bit.GitError::IoError(e)
    None => ()
  }
}

///|
impl @bit.FileSystem for HubJsHostFs with fn write_string(self, path, content) {
  match hub_js_host_write_string(self.host_id, path, content) {
    Some(e) => raise @bit.GitError::IoError(e)
    None => ()
  }
}

///|
impl @bit.FileSystem for HubJsHostFs with fn remove_file(_self, _path) {
  // Not needed for hub reads
}

///|
impl @bit.FileSystem for HubJsHostFs with fn remove_dir(_self, _path) {
  // Not needed for hub reads
}

///|
impl @bit.RepoFileSystem for HubJsHostFs with fn read_file(self, path) {
  match hub_js_host_read_file(self.host_id, path) {
    Some(arr) => bytes_from_array(arr)
    None => raise @bit.GitError::IoError(hub_js_host_last_error())
  }
}

///|
impl @bit.RepoFileSystem for HubJsHostFs with fn readdir(self, path) {
  match hub_js_host_readdir(self.host_id, path) {
    Some(arr) => Array::from_fixed_array(arr)
    None => raise @bit.GitError::IoError(hub_js_host_last_error())
  }
}

///|
impl @bit.RepoFileSystem for HubJsHostFs with fn is_dir(self, path) {
  hub_js_host_is_dir(self.host_id, path)
}

///|
impl @bit.RepoFileSystem for HubJsHostFs with fn is_file(self, path) {
  hub_js_host_is_file(self.host_id, path)
}

///|
impl @bit.RepoFileSystem for HubJsHostFs with fn mtime(self, path) {
  match hub_js_host_mtime(self.host_id, path) {
    Some(value) => (value[0], value[1])
    None => raise @bit.GitError::IoError(hub_js_host_last_error())
  }
}
