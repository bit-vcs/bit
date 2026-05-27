///| JS host registry bridge for exported `src/lib` operations.

///|
priv struct LibJsHostFs {
  host_id : Int
}

///|
fn LibJsHostFs::new(host_id : Int) -> LibJsHostFs {
  { host_id, }
}

///|
fn js_make_host_fs(host_id : Int) -> LibJsHostFs {
  LibJsHostFs::new(host_id)
}

///|
fn js_bytes_to_array(bytes : Bytes) -> Array[Byte] {
  let out : Array[Byte] = Array::new(capacity=bytes.length())
  for i in 0..<bytes.length() {
    out.push(bytes[i])
  }
  out
}

///|
fn js_host_error_message() -> String {
  lib_js_host_last_error()
}

///|
fn js_unwrap_host_write(result : String?) -> Result[Unit, String] {
  match result {
    Some(error) => Err(error)
    None => Ok(())
  }
}

///|
extern "js" fn lib_js_host_last_error() -> String =
  #| () => globalThis.__bitGitJsLastError ?? ""

///|
extern "js" fn lib_js_host_write_file(
  host_id : Int,
  path : String,
  content : Array[Byte],
) -> String? =
  #| (hostId, path, content) => {
  #|   const state = globalThis.__bitGitJsState ??= { nextHostId: 1, hosts: new Map() };
  #|   const host = state.hosts.get(hostId);
  #|   if (!host) {
  #|     return `bit-git js host ${hostId} not found`;
  #|   }
  #|   if (typeof host.writeFile !== 'function') {
  #|     return 'bit-git js host.writeFile(path, bytes) is required';
  #|   }
  #|   try {
  #|     host.writeFile(path, Uint8Array.from(content ?? []));
  #|     return undefined;
  #|   } catch (error) {
  #|     return String(error?.message ?? error);
  #|   }
  #| }

///|
extern "js" fn lib_js_host_write_string(
  host_id : Int,
  path : String,
  content : String,
) -> String? =
  #| (hostId, path, content) => {
  #|   const state = globalThis.__bitGitJsState ??= { nextHostId: 1, hosts: new Map() };
  #|   const host = state.hosts.get(hostId);
  #|   if (!host) {
  #|     return `bit-git js host ${hostId} not found`;
  #|   }
  #|   if (typeof host.writeString !== 'function') {
  #|     return 'bit-git js host.writeString(path, content) is required';
  #|   }
  #|   try {
  #|     host.writeString(path, content);
  #|     return undefined;
  #|   } catch (error) {
  #|     return String(error?.message ?? error);
  #|   }
  #| }

///|
extern "js" fn lib_js_host_mkdir_p(host_id : Int, path : String) -> String? =
  #| (hostId, path) => {
  #|   const state = globalThis.__bitGitJsState ??= { nextHostId: 1, hosts: new Map() };
  #|   const host = state.hosts.get(hostId);
  #|   if (!host) {
  #|     return `bit-git js host ${hostId} not found`;
  #|   }
  #|   if (typeof host.mkdirP !== 'function') {
  #|     return 'bit-git js host.mkdirP(path) is required';
  #|   }
  #|   try {
  #|     host.mkdirP(path);
  #|     return undefined;
  #|   } catch (error) {
  #|     return String(error?.message ?? error);
  #|   }
  #| }

///|
extern "js" fn lib_js_host_remove_file(host_id : Int, path : String) -> String? =
  #| (hostId, path) => {
  #|   const state = globalThis.__bitGitJsState ??= { nextHostId: 1, hosts: new Map() };
  #|   const host = state.hosts.get(hostId);
  #|   if (!host) {
  #|     return `bit-git js host ${hostId} not found`;
  #|   }
  #|   if (typeof host.removeFile !== 'function') {
  #|     return 'bit-git js host.removeFile(path) is required';
  #|   }
  #|   try {
  #|     host.removeFile(path);
  #|     return undefined;
  #|   } catch (error) {
  #|     return String(error?.message ?? error);
  #|   }
  #| }

///|
extern "js" fn lib_js_host_remove_dir(host_id : Int, path : String) -> String? =
  #| (hostId, path) => {
  #|   const state = globalThis.__bitGitJsState ??= { nextHostId: 1, hosts: new Map() };
  #|   const host = state.hosts.get(hostId);
  #|   if (!host) {
  #|     return `bit-git js host ${hostId} not found`;
  #|   }
  #|   if (typeof host.removeDir !== 'function') {
  #|     return 'bit-git js host.removeDir(path) is required';
  #|   }
  #|   try {
  #|     host.removeDir(path);
  #|     return undefined;
  #|   } catch (error) {
  #|     return String(error?.message ?? error);
  #|   }
  #| }

///|
extern "js" fn lib_js_host_read_file(
  host_id : Int,
  path : String,
) -> Array[Byte]? =
  #| (hostId, path) => {
  #|   const state = globalThis.__bitGitJsState ??= { nextHostId: 1, hosts: new Map() };
  #|   const host = state.hosts.get(hostId);
  #|   if (!host) {
  #|     globalThis.__bitGitJsLastError = `bit-git js host ${hostId} not found`;
  #|     return { $tag: 0 };
  #|   }
  #|   if (typeof host.readFile !== 'function') {
  #|     globalThis.__bitGitJsLastError = 'bit-git js host.readFile(path) is required';
  #|     return { $tag: 0 };
  #|   }
  #|   try {
  #|     const value = host.readFile(path);
  #|     if (value instanceof Uint8Array) {
  #|       return { $tag: 1, _0: Array.from(value) };
  #|     }
  #|     if (value instanceof ArrayBuffer) {
  #|       return { $tag: 1, _0: Array.from(new Uint8Array(value)) };
  #|     }
  #|     if (Array.isArray(value)) {
  #|       return { $tag: 1, _0: value.map((item) => Number(item) & 0xff) };
  #|     }
  #|     if (typeof value === 'string') {
  #|       return { $tag: 1, _0: Array.from(new TextEncoder().encode(value)) };
  #|     }
  #|     globalThis.__bitGitJsLastError = 'bit-git js host.readFile must return Uint8Array, ArrayBuffer, Array<number>, or string';
  #|     return { $tag: 0 };
  #|   } catch (error) {
  #|     globalThis.__bitGitJsLastError = String(error?.message ?? error);
  #|     return { $tag: 0 };
  #|   }
  #| }

///|
extern "js" fn lib_js_host_readdir(
  host_id : Int,
  path : String,
) -> Array[String]? =
  #| (hostId, path) => {
  #|   const state = globalThis.__bitGitJsState ??= { nextHostId: 1, hosts: new Map() };
  #|   const host = state.hosts.get(hostId);
  #|   if (!host) {
  #|     globalThis.__bitGitJsLastError = `bit-git js host ${hostId} not found`;
  #|     return { $tag: 0 };
  #|   }
  #|   if (typeof host.readdir !== 'function') {
  #|     globalThis.__bitGitJsLastError = 'bit-git js host.readdir(path) is required';
  #|     return { $tag: 0 };
  #|   }
  #|   try {
  #|     return {
  #|       $tag: 1,
  #|       _0: Array.from(host.readdir(path) ?? [], (item) => String(item)),
  #|     };
  #|   } catch (error) {
  #|     globalThis.__bitGitJsLastError = String(error?.message ?? error);
  #|     return { $tag: 0 };
  #|   }
  #| }

///|
extern "js" fn lib_js_host_is_dir(host_id : Int, path : String) -> Bool =
  #| (hostId, path) => {
  #|   const state = globalThis.__bitGitJsState ??= { nextHostId: 1, hosts: new Map() };
  #|   const host = state.hosts.get(hostId);
  #|   if (!host || typeof host.isDir !== 'function') {
  #|     return false;
  #|   }
  #|   try {
  #|     return !!host.isDir(path);
  #|   } catch (_error) {
  #|     return false;
  #|   }
  #| }

///|
extern "js" fn lib_js_host_is_file(host_id : Int, path : String) -> Bool =
  #| (hostId, path) => {
  #|   const state = globalThis.__bitGitJsState ??= { nextHostId: 1, hosts: new Map() };
  #|   const host = state.hosts.get(hostId);
  #|   if (!host || typeof host.isFile !== 'function') {
  #|     return false;
  #|   }
  #|   try {
  #|     return !!host.isFile(path);
  #|   } catch (_error) {
  #|     return false;
  #|   }
  #| }

///|
extern "js" fn lib_js_create_memory_host() -> Int =
  #| () => {
  #|   const state = globalThis.__bitGitJsState ??= { nextHostId: 1, hosts: new Map() };
  #|   const encoder = new TextEncoder();
  #|   const decoder = new TextDecoder();
  #|   const normalizePath = (path) => {
  #|     if (path === '' || path == null) return '/';
  #|     let normalized = String(path).replace(/\/+/g, '/');
  #|     if (!normalized.startsWith('/')) normalized = `/${normalized}`;
  #|     if (normalized.length > 1 && normalized.endsWith('/')) {
  #|       normalized = normalized.slice(0, -1);
  #|     }
  #|     return normalized;
  #|   };
  #|   const parentDir = (path) => {
  #|     const normalized = normalizePath(path);
  #|     if (normalized === '/') return '/';
  #|     const index = normalized.lastIndexOf('/');
  #|     return index <= 0 ? '/' : normalized.slice(0, index);
  #|   };
  #|   const baseName = (path) => {
  #|     const normalized = normalizePath(path);
  #|     if (normalized === '/') return '/';
  #|     const index = normalized.lastIndexOf('/');
  #|     return index < 0 ? normalized : normalized.slice(index + 1);
  #|   };
  #|   const ensureDirs = (dirs, path) => {
  #|     const normalized = normalizePath(path);
  #|     if (normalized === '/') {
  #|       dirs.add('/');
  #|       return;
  #|     }
  #|     const parts = normalized.split('/').filter(Boolean);
  #|     let current = '';
  #|     for (const part of parts) {
  #|       current += `/${part}`;
  #|       dirs.add(current);
  #|     }
  #|   };
  #|   const createHost = () => {
  #|     const files = new Map();
  #|     const dirs = new Set(['/']);
  #|     return {
  #|       mkdirP(path) {
  #|         ensureDirs(dirs, path);
  #|       },
  #|       writeFile(path, content) {
  #|         const normalized = normalizePath(path);
  #|         ensureDirs(dirs, parentDir(normalized));
  #|         files.set(normalized, Uint8Array.from(content));
  #|       },
  #|       writeString(path, content) {
  #|         this.writeFile(path, encoder.encode(String(content)));
  #|       },
  #|       removeFile(path) {
  #|         const normalized = normalizePath(path);
  #|         if (!files.delete(normalized)) {
  #|           throw new Error(`File not found: ${normalized}`);
  #|         }
  #|       },
  #|       removeDir(path) {
  #|         const normalized = normalizePath(path);
  #|         if (!dirs.has(normalized)) {
  #|           throw new Error(`Directory not found: ${normalized}`);
  #|         }
  #|         for (const filePath of files.keys()) {
  #|           if (parentDir(filePath) === normalized) {
  #|             throw new Error(`Directory not empty: ${normalized}`);
  #|           }
  #|         }
  #|         for (const dirPath of dirs.values()) {
  #|           if (dirPath !== normalized && parentDir(dirPath) === normalized) {
  #|             throw new Error(`Directory not empty: ${normalized}`);
  #|           }
  #|         }
  #|         dirs.delete(normalized);
  #|       },
  #|       readFile(path) {
  #|         const normalized = normalizePath(path);
  #|         const value = files.get(normalized);
  #|         if (!value) {
  #|           throw new Error(`File not found: ${normalized}`);
  #|         }
  #|         return Uint8Array.from(value);
  #|       },
  #|       readdir(path) {
  #|         const normalized = normalizePath(path);
  #|         if (!dirs.has(normalized)) {
  #|           throw new Error(`Directory not found: ${normalized}`);
  #|         }
  #|         const entries = new Set();
  #|         for (const filePath of files.keys()) {
  #|           if (parentDir(filePath) === normalized) {
  #|             entries.add(baseName(filePath));
  #|           }
  #|         }
  #|         for (const dirPath of dirs.values()) {
  #|           if (dirPath !== normalized && parentDir(dirPath) === normalized) {
  #|             entries.add(baseName(dirPath));
  #|           }
  #|         }
  #|         return Array.from(entries).sort();
  #|       },
  #|       isDir(path) {
  #|         return dirs.has(normalizePath(path));
  #|       },
  #|       isFile(path) {
  #|         return files.has(normalizePath(path));
  #|       },
  #|       readString(path) {
  #|         return decoder.decode(this.readFile(path));
  #|       },
  #|     };
  #|   };
  #|   const hostId = state.nextHostId++;
  #|   state.hosts.set(hostId, createHost());
  #|   return hostId;
  #| }

///|
extern "js" fn lib_js_destroy_host(host_id : Int) -> Unit =
  #| (hostId) => {
  #|   const state = globalThis.__bitGitJsState ??= { nextHostId: 1, hosts: new Map() };
  #|   state.hosts.delete(hostId);
  #| }

///|
pub fn js_create_memory_host() -> Int {
  lib_js_create_memory_host()
}

///|
pub fn js_destroy_host(host_id : Int) -> Unit {
  lib_js_destroy_host(host_id)
}

///|
pub fn js_host_write_string(
  host_id : Int,
  path : String,
  content : String,
) -> Result[Unit, String] {
  js_unwrap_host_write(lib_js_host_write_string(host_id, path, content))
}

///|
pub fn js_host_read_string(
  host_id : Int,
  path : String,
) -> Result[String, String] {
  match lib_js_host_read_file(host_id, path) {
    Some(bytes) => {
      let content = Bytes::from_array(bytes)
      Ok(@utf8.decode_lossy(content[:]))
    }
    None => Err(js_host_error_message())
  }
}

///|
impl @bit.FileSystem for LibJsHostFs with mkdir_p(self, path) {
  match lib_js_host_mkdir_p(self.host_id, path) {
    Some(error) => raise @bit.GitError::IoError(error)
    None => ()
  }
}

///|
impl @bit.FileSystem for LibJsHostFs with write_file(self, path, content) {
  match lib_js_host_write_file(self.host_id, path, js_bytes_to_array(content)) {
    Some(error) => raise @bit.GitError::IoError(error)
    None => ()
  }
}

///|
impl @bit.FileSystem for LibJsHostFs with write_string(self, path, content) {
  match lib_js_host_write_string(self.host_id, path, content) {
    Some(error) => raise @bit.GitError::IoError(error)
    None => ()
  }
}

///|
impl @bit.FileSystem for LibJsHostFs with remove_file(self, path) {
  match lib_js_host_remove_file(self.host_id, path) {
    Some(error) => raise @bit.GitError::IoError(error)
    None => ()
  }
}

///|
impl @bit.FileSystem for LibJsHostFs with remove_dir(self, path) {
  match lib_js_host_remove_dir(self.host_id, path) {
    Some(error) => raise @bit.GitError::IoError(error)
    None => ()
  }
}

///|
impl @bit.RepoFileSystem for LibJsHostFs with read_file(self, path) {
  match lib_js_host_read_file(self.host_id, path) {
    Some(content) => Bytes::from_array(content)
    None => raise @bit.GitError::IoError(js_host_error_message())
  }
}

///|
impl @bit.RepoFileSystem for LibJsHostFs with readdir(self, path) {
  match lib_js_host_readdir(self.host_id, path) {
    Some(entries) => entries
    None => raise @bit.GitError::IoError(js_host_error_message())
  }
}

///|
impl @bit.RepoFileSystem for LibJsHostFs with is_dir(self, path) {
  lib_js_host_is_dir(self.host_id, path)
}

///|
impl @bit.RepoFileSystem for LibJsHostFs with is_file(self, path) {
  lib_js_host_is_file(self.host_id, path)
}
