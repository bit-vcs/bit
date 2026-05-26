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
  content : Array[Byte],
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
) -> Array[Byte]? =
  #| (hostId, path) => {
  #|   const state = globalThis.__bitGitJsState ??= { nextHostId: 1, hosts: new Map() };
  #|   const host = state.hosts.get(hostId);
  #|   if (!host) { globalThis.__bitGitJsLastError = `host ${hostId} not found`; return { $tag: 0 }; }
  #|   try {
  #|     const v = host.readFile(path);
  #|     if (v instanceof Uint8Array) return { $tag: 1, _0: Array.from(v) };
  #|     if (v instanceof ArrayBuffer) return { $tag: 1, _0: Array.from(new Uint8Array(v)) };
  #|     if (Array.isArray(v)) return { $tag: 1, _0: v.map(x => Number(x) & 0xff) };
  #|     if (typeof v === 'string') return { $tag: 1, _0: Array.from(new TextEncoder().encode(v)) };
  #|     globalThis.__bitGitJsLastError = 'readFile must return Uint8Array/ArrayBuffer/Array/string';
  #|     return { $tag: 0 };
  #|   } catch (e) { globalThis.__bitGitJsLastError = String(e?.message ?? e); return { $tag: 0 }; }
  #| }

///|
extern "js" fn hub_js_host_readdir(
  host_id : Int,
  path : String,
) -> Array[String]? =
  #| (hostId, path) => {
  #|   const state = globalThis.__bitGitJsState ??= { nextHostId: 1, hosts: new Map() };
  #|   const host = state.hosts.get(hostId);
  #|   if (!host) { globalThis.__bitGitJsLastError = `host ${hostId} not found`; return { $tag: 0 }; }
  #|   try {
  #|     const entries = host.readdir(path);
  #|     return { $tag: 1, _0: Array.from(entries) };
  #|   } catch (e) { globalThis.__bitGitJsLastError = String(e?.message ?? e); return { $tag: 0 }; }
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

// --- Trait implementations ---

///|
fn bytes_from_array(arr : Array[Byte]) -> Bytes {
  Bytes::from_iter(arr.iter())
}

///|
impl @bit.FileSystem for HubJsHostFs with mkdir_p(self, path) {
  match hub_js_host_mkdir_p(self.host_id, path) {
    Some(e) => raise @bit.GitError::IoError(e)
    None => ()
  }
}

///|
impl @bit.FileSystem for HubJsHostFs with write_file(self, path, content) {
  let arr = Array::new(capacity=content.length())
  for i in 0..<content.length() {
    arr.push(content[i])
  }
  match hub_js_host_write_file(self.host_id, path, arr) {
    Some(e) => raise @bit.GitError::IoError(e)
    None => ()
  }
}

///|
impl @bit.FileSystem for HubJsHostFs with write_string(self, path, content) {
  match hub_js_host_write_string(self.host_id, path, content) {
    Some(e) => raise @bit.GitError::IoError(e)
    None => ()
  }
}

///|
impl @bit.FileSystem for HubJsHostFs with remove_file(_self, _path) {
  // Not needed for hub reads
}

///|
impl @bit.FileSystem for HubJsHostFs with remove_dir(_self, _path) {
  // Not needed for hub reads
}

///|
impl @bit.RepoFileSystem for HubJsHostFs with read_file(self, path) {
  match hub_js_host_read_file(self.host_id, path) {
    Some(arr) => bytes_from_array(arr)
    None => raise @bit.GitError::IoError(hub_js_host_last_error())
  }
}

///|
impl @bit.RepoFileSystem for HubJsHostFs with readdir(self, path) {
  match hub_js_host_readdir(self.host_id, path) {
    Some(arr) => arr
    None => raise @bit.GitError::IoError(hub_js_host_last_error())
  }
}

///|
impl @bit.RepoFileSystem for HubJsHostFs with is_dir(self, path) {
  hub_js_host_is_dir(self.host_id, path)
}

///|
impl @bit.RepoFileSystem for HubJsHostFs with is_file(self, path) {
  hub_js_host_is_file(self.host_id, path)
}
