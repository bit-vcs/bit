///|
#external
priv type JsPromise[T]

///|
fn[T, U] JsPromise::cast(self : JsPromise[T]) -> @js_async.Promise[U] = "%identity"

///|
extern "js" fn js_read_file(path : String) -> JsPromise[String] =
  #| async (path) => {
  #|   const fs = await import('node:fs/promises');
  #|   return await fs.readFile(path, 'utf-8');
  #| }

///|
extern "js" fn js_write_file(
  path : String,
  content : Bytes,
  create_mode : Int32,
  permission : Int32,
  sync : Int32,
  append : Bool,
) -> JsPromise[Unit] =
  #| async (path, content, createMode, permission, syncMode, append) => {
  #|   const fs = await import('node:fs/promises');
  #|   const mode = permission || 0o644;
  #|   const data = Buffer.from(content);
  #|   const openExisting = async () => fs.open(path, append ? 'a' : 'r+', mode);
  #|   let fh;
  #|   switch (createMode | 0) {
  #|     case 0:
  #|       fh = await openExisting();
  #|       break;
  #|     case 1:
  #|       fh = await fs.open(path, 'r+', mode);
  #|       await fh.truncate(0);
  #|       break;
  #|     case 2:
  #|       if (append) {
  #|         fh = await fs.open(path, 'a', mode);
  #|       } else {
  #|         try { fh = await fs.open(path, 'r+', mode); }
  #|         catch (err) {
  #|           if (err?.code !== 'ENOENT') throw err;
  #|           fh = await fs.open(path, 'w+', mode);
  #|         }
  #|       }
  #|       break;
  #|     case 3:
  #|       fh = await fs.open(path, append ? 'a' : 'w', mode);
  #|       break;
  #|     case 4:
  #|       fh = await fs.open(path, append ? 'ax' : 'wx', mode);
  #|       break;
  #|     default:
  #|       throw new Error(`unknown create mode: ${createMode}`);
  #|   }
  #|   try {
  #|     if (data.length > 0) await fh.write(data, 0, data.length, null);
  #|     if (syncMode === 1) await fh.datasync();
  #|     else if (syncMode === 2) await fh.sync();
  #|   } finally {
  #|     await fh.close();
  #|   }
  #| }

///|
extern "js" fn js_exists(path : String) -> JsPromise[Bool] =
  #| async (path) => {
  #|   const fs = await import('node:fs/promises');
  #|   try { await fs.access(path); return true; }
  #|   catch { return false; }
  #| }

///|
extern "js" fn js_mkdir(path : String, recursive : Bool) -> JsPromise[Unit] =
  #| async (path, recursive) => {
  #|   const fs = await import('node:fs/promises');
  #|   await fs.mkdir(path, { recursive });
  #| }

///|
extern "js" fn js_readdir(
  path : String,
  include_hidden : Bool,
  include_special : Bool,
  sort : Bool,
) -> JsPromise[FixedArray[String]] =
  #| async (path, includeHidden, includeSpecial, sort) => {
  #|   const fs = await import('node:fs/promises');
  #|   let entries = await fs.readdir(path);
  #|   if (!includeSpecial) {
  #|     entries = entries.filter(n => n !== '.' && n !== '..');
  #|   }
  #|   if (!includeHidden) {
  #|     entries = entries.filter(n => !n.startsWith('.'));
  #|   }
  #|   if (sort) {
  #|     entries.sort();
  #|   }
  #|   return entries;
  #| }

///|
extern "js" fn js_remove(path : String) -> JsPromise[Unit] =
  #| async (path) => {
  #|   const fs = await import('node:fs/promises');
  #|   await fs.rm(path, { force: true });
  #| }

///|
extern "js" fn js_rename(
  old_path : String,
  new_path : String,
  replace : Bool,
) -> JsPromise[Unit] =
  #| async (oldPath, newPath, replace) => {
  #|   const fs = await import('node:fs/promises');
  #|   if (!replace) {
  #|     try {
  #|       await fs.lstat(newPath);
  #|       throw new Error(`target already exists: ${newPath}`);
  #|     } catch (err) {
  #|       if (!err || err.code !== 'ENOENT') throw err;
  #|     }
  #|   }
  #|   await fs.rename(oldPath, newPath);
  #| }

///|
extern "js" fn js_rmdir(path : String, recursive : Bool) -> JsPromise[Unit] =
  #| async (path, recursive) => {
  #|   const fs = await import('node:fs/promises');
  #|   if (recursive) {
  #|     await fs.rm(path, { recursive: true, force: true });
  #|   } else {
  #|     await fs.rmdir(path);
  #|   }
  #| }

///|
priv struct JsTime {
  seconds : Int32
  nanos : Int32
}

///|
priv struct JsFileOpenResult {
  id : Int32
  fd : Int32
  kind : Int32
}

///|
extern "js" fn js_access(path : String, mode : Int32) -> JsPromise[Bool] =
  #| async (path, mode) => {
  #|   const fs = await import('node:fs/promises');
  #|   const nodeFs = await import('node:fs');
  #|   const flag = mode === 1 ? nodeFs.constants.R_OK : mode === 2 ? nodeFs.constants.W_OK : nodeFs.constants.X_OK;
  #|   try { await fs.access(path, flag); return true; }
  #|   catch { return false; }
  #| }

///|
extern "js" fn js_chmod(path : String, permission : Int32) -> JsPromise[Unit] =
  #| async (path, permission) => {
  #|   const fs = await import('node:fs/promises');
  #|   await fs.chmod(path, permission);
  #| }

///|
extern "js" fn js_time(
  path : String,
  follow_symlink : Bool,
  kind : Int32,
) -> JsPromise[JsTime] =
  #| async (path, followSymlink, kind) => {
  #|   const fs = await import('node:fs/promises');
  #|   const stat = followSymlink ? await fs.stat(path) : await fs.lstat(path);
  #|   const ms = kind === 1 ? stat.atimeMs : kind === 2 ? stat.mtimeMs : stat.ctimeMs;
  #|   const seconds = Math.floor(ms / 1000);
  #|   const nanos = Math.floor((ms - seconds * 1000) * 1000000);
  #|   return { seconds: seconds | 0, nanos: nanos | 0 };
  #| }

///|
extern "js" fn js_tmpdir(prefix : String) -> JsPromise[String] =
  #| async (prefix) => {
  #|   const fs = await import('node:fs/promises');
  #|   const os = await import('node:os');
  #|   const path = await import('node:path');
  #|   return await fs.mkdtemp(path.join(os.tmpdir(), prefix));
  #| }

///|
extern "js" fn js_file_open(
  path : String,
  mode : Int32,
  create_mode : Int32,
  permission : Int32,
  append : Bool,
  sync : Int32,
) -> JsPromise[JsFileOpenResult] =
  #| async (path, mode, createMode, permission, append, syncMode) => {
  #|   const fs = await import('node:fs/promises');
  #|   const state = globalThis.__xfsFiles ??= { nextId: 1, files: new Map() };
  #|   const writable = mode !== 0;
  #|   const readable = mode !== 1;
  #|   const rwFlag = append ? 'a+' : 'r+';
  #|   const wFlag = append ? 'a' : 'r+';
  #|   const truncateFlag = readable ? 'w+' : 'w';
  #|   const createNewFlag = readable ? (append ? 'ax+' : 'wx+') : (append ? 'ax' : 'wx');
  #|   let fh;
  #|   switch (createMode | 0) {
  #|     case 0:
  #|       fh = await fs.open(path, mode === 0 ? 'r' : (readable ? rwFlag : wFlag), permission);
  #|       break;
  #|     case 1:
  #|       fh = await fs.open(path, readable ? 'r+' : 'r+', permission);
  #|       await fh.truncate(0);
  #|       break;
  #|     case 2:
  #|       if (append) {
  #|         fh = await fs.open(path, readable ? 'a+' : 'a', permission);
  #|       } else {
  #|         try { fh = await fs.open(path, readable ? 'r+' : 'r+', permission); }
  #|         catch (err) {
  #|           if (err?.code !== 'ENOENT') throw err;
  #|           fh = await fs.open(path, readable ? 'w+' : 'w+', permission);
  #|         }
  #|       }
  #|       break;
  #|     case 3:
  #|       fh = await fs.open(path, truncateFlag, permission);
  #|       break;
  #|     case 4:
  #|       fh = await fs.open(path, createNewFlag, permission);
  #|       break;
  #|     default:
  #|       throw new Error(`unknown create mode: ${createMode}`);
  #|   }
  #|   const stat = await fh.stat();
  #|   const kind = stat.isFile() ? 1 : stat.isDirectory() ? 2 : stat.isSymbolicLink() ? 3 : stat.isSocket() ? 4 : stat.isFIFO() ? 5 : stat.isBlockDevice() ? 6 : stat.isCharacterDevice() ? 7 : 0;
  #|   const id = state.nextId++;
  #|   state.files.set(id, { fh, path, syncMode: syncMode | 0 });
  #|   return { id, fd: fh.fd | 0, kind: kind | 0 };
  #| }

///|
extern "js" fn js_file_close(id : Int32) -> Unit =
  #| (id) => {
  #|   const state = globalThis.__xfsFiles;
  #|   const handle = state?.files?.get(id);
  #|   if (!handle) return;
  #|   state.files.delete(id);
  #|   handle.fh.close().catch(() => {});
  #| }

///|
extern "js" fn js_file_read(id : Int32, max_len : Int32) -> JsPromise[Bytes] =
  #| async (id, maxLen) => {
  #|   const handle = globalThis.__xfsFiles?.files?.get(id);
  #|   if (!handle) throw new Error('file handle not found');
  #|   const buf = Buffer.alloc(Math.max(0, maxLen | 0));
  #|   const result = await handle.fh.read(buf, 0, buf.length, null);
  #|   return new Uint8Array(buf.subarray(0, result.bytesRead));
  #| }

///|
extern "js" fn js_file_write(
  id : Int32,
  data : Bytes,
  offset : Int32,
  len : Int32,
) -> JsPromise[Int32] =
  #| async (id, data, offset, len) => {
  #|   const handle = globalThis.__xfsFiles?.files?.get(id);
  #|   if (!handle) throw new Error('file handle not found');
  #|   const payload = Buffer.from(data).subarray(offset, offset + len);
  #|   const result = await handle.fh.write(payload, 0, payload.length, null);
  #|   if (handle.syncMode === 1) await handle.fh.datasync();
  #|   else if (handle.syncMode === 2) await handle.fh.sync();
  #|   return result.bytesWritten | 0;
  #| }

///|
extern "js" fn js_file_read_at(
  id : Int32,
  max_len : Int32,
  position : Int64,
) -> JsPromise[Bytes] =
  #| async (id, maxLen, position) => {
  #|   const handle = globalThis.__xfsFiles?.files?.get(id);
  #|   if (!handle) throw new Error('file handle not found');
  #|   const buf = Buffer.alloc(Math.max(0, maxLen | 0));
  #|   const result = await handle.fh.read(buf, 0, buf.length, Number(position));
  #|   return new Uint8Array(buf.subarray(0, result.bytesRead));
  #| }

///|
extern "js" fn js_file_write_at(
  id : Int32,
  data : Bytes,
  offset : Int32,
  len : Int32,
  position : Int64,
) -> JsPromise[Unit] =
  #| async (id, data, offset, len, position) => {
  #|   const handle = globalThis.__xfsFiles?.files?.get(id);
  #|   if (!handle) throw new Error('file handle not found');
  #|   const payload = Buffer.from(data).subarray(offset, offset + len);
  #|   await handle.fh.write(payload, 0, payload.length, Number(position));
  #|   if (handle.syncMode === 1) await handle.fh.datasync();
  #|   else if (handle.syncMode === 2) await handle.fh.sync();
  #| }

///|
extern "js" fn js_file_size(id : Int32) -> JsPromise[Int32] =
  #| async (id) => {
  #|   const handle = globalThis.__xfsFiles?.files?.get(id);
  #|   if (!handle) throw new Error('file handle not found');
  #|   const stat = await handle.fh.stat();
  #|   return stat.size | 0;
  #| }

///|
extern "js" fn js_file_time(id : Int32, kind : Int32) -> JsPromise[JsTime] =
  #| async (id, kind) => {
  #|   const handle = globalThis.__xfsFiles?.files?.get(id);
  #|   if (!handle) throw new Error('file handle not found');
  #|   const stat = await handle.fh.stat();
  #|   const ms = kind === 1 ? stat.atimeMs : kind === 2 ? stat.mtimeMs : stat.ctimeMs;
  #|   const seconds = Math.floor(ms / 1000);
  #|   const nanos = Math.floor((ms - seconds * 1000) * 1000000);
  #|   return { seconds: seconds | 0, nanos: nanos | 0 };
  #| }

///|
extern "js" fn js_file_sync(id : Int32, only_data : Bool) -> JsPromise[Unit] =
  #| async (id, onlyData) => {
  #|   const handle = globalThis.__xfsFiles?.files?.get(id);
  #|   if (!handle) throw new Error('file handle not found');
  #|   if (onlyData) await handle.fh.datasync();
  #|   else await handle.fh.sync();
  #| }

///|
async fn[T] run_js_promise(promise : JsPromise[T]) -> T raise IOError {
  @js_async.run_promise(fn(_signal) { promise.cast() }) catch {
    err => raise IOError::IOError(err.to_string())
  }
}

///|
fn create_mode_to_int(mode : CreateMode) -> Int32 {
  match mode {
    OpenExisting => 0
    TruncateExisting => 1
    OpenOrCreate => 2
    CreateOrTruncate => 3
    CreateNew => 4
  }
}

///|
fn sync_mode_to_int(sync : SyncMode) -> Int32 {
  match sync {
    NoSync => 0
    Data => 1
    Full => 2
  }
}

///|
fn mode_to_int(mode : Mode) -> Int32 {
  match mode {
    ReadOnly => 0
    WriteOnly => 1
    ReadWrite => 2
  }
}

///|
fn default_write_create_mode(
  create_mode? : CreateMode,
  create? : Int32,
  truncate? : Bool,
) -> CreateMode {
  match create_mode {
    Some(mode) => mode
    None =>
      match (create is Some(_), truncate.unwrap_or(true)) {
        (true, true) => CreateOrTruncate
        (true, false) => OpenOrCreate
        (false, true) => CreateOrTruncate
        (false, false) => OpenExisting
      }
  }
}

///|
fn permission_or_create(permission? : Int32, create? : Int32) -> Int32 {
  match permission {
    Some(p) => p
    None =>
      match create {
        Some(p) => p
        None => 0o644
      }
  }
}

///|
fn js_kind_to_file_kind(i : Int32) -> FileKind {
  match i {
    1 => Regular
    2 => Directory
    3 => SymLink
    4 => Socket
    5 => Pipe
    6 => BlockDevice
    7 => CharDevice
    _ => Unknown
  }
}

///|
fn time_to_tuple(time : JsTime) -> (Int64, Int32) {
  (time.seconds.to_int64(), time.nanos)
}

///|
pub async fn read_file(
  path : StringView,
  sync_timestamp? : Bool,
) -> &@data.Data raise IOError {
  ignore(sync_timestamp)
  let s : String = run_js_promise(js_read_file(path.to_owned()))
  s
}

///|
pub async fn write_file(
  path : StringView,
  content : &@data.Data,
  create_mode? : CreateMode,
  permission? : Int32,
  sync? : SyncMode,
  append? : Bool,
  create? : Int32,
  truncate? : Bool,
) -> Unit raise IOError {
  let data = content.binary()
  let mode = default_write_create_mode(create_mode?, create?, truncate?)
  let permission = permission_or_create(permission?, create?)
  run_js_promise(
    js_write_file(
      path.to_owned(),
      data,
      create_mode_to_int(mode),
      permission,
      sync_mode_to_int(sync.unwrap_or(Data)),
      append.unwrap_or(false),
    ),
  )
}

///|
pub async fn exists(path : StringView) -> Bool {
  run_js_promise(js_exists(path.to_owned())) catch {
    _ => false
  }
}

///|
pub async fn can_read(path : StringView) -> Bool {
  run_js_promise(js_access(path.to_owned(), 1)) catch {
    _ => false
  }
}

///|
pub async fn can_write(path : StringView) -> Bool {
  run_js_promise(js_access(path.to_owned(), 2)) catch {
    _ => false
  }
}

///|
pub async fn can_execute(path : StringView) -> Bool {
  run_js_promise(js_access(path.to_owned(), 3)) catch {
    _ => false
  }
}

///|
pub async fn chmod(path : StringView, permission : Int32) -> Unit raise IOError {
  run_js_promise(js_chmod(path.to_owned(), permission))
}

///|
pub async fn atime(
  path : StringView,
  follow_symlink? : Bool,
) -> (Int64, Int32) raise IOError {
  run_js_promise(js_time(path.to_owned(), follow_symlink.unwrap_or(true), 1))
  |> time_to_tuple
}

///|
pub async fn mtime(
  path : StringView,
  follow_symlink? : Bool,
) -> (Int64, Int32) raise IOError {
  run_js_promise(js_time(path.to_owned(), follow_symlink.unwrap_or(true), 2))
  |> time_to_tuple
}

///|
pub async fn ctime(
  path : StringView,
  follow_symlink? : Bool,
) -> (Int64, Int32) raise IOError {
  run_js_promise(js_time(path.to_owned(), follow_symlink.unwrap_or(true), 3))
  |> time_to_tuple
}

///|
pub async fn mkdir(
  path : StringView,
  permission? : Int32,
  recursive? : Bool,
) -> Unit raise IOError {
  ignore(permission)
  run_js_promise(js_mkdir(path.to_owned(), recursive.unwrap_or(false)))
}

///|
pub async fn readdir(
  path : StringView,
  include_hidden? : Bool,
  include_special? : Bool,
  sort? : Bool,
) -> Array[String] raise IOError {
  let entries = run_js_promise(
    js_readdir(
      path.to_owned(),
      include_hidden.unwrap_or(false),
      include_special.unwrap_or(false),
      sort.unwrap_or(false),
    ),
  )
  entries.iter().collect()
}

///|
pub async fn remove(path : StringView) -> Unit raise IOError {
  run_js_promise(js_remove(path.to_owned()))
}

///|
pub async fn rename(
  old_path : StringView,
  new_path : StringView,
  replace? : Bool,
) -> Unit raise IOError {
  run_js_promise(
    js_rename(old_path.to_owned(), new_path.to_owned(), replace.unwrap_or(true)),
  )
}

///|
pub async fn rmdir(path : StringView, recursive? : Bool) -> Unit raise IOError {
  run_js_promise(js_rmdir(path.to_owned(), recursive.unwrap_or(false)))
}

///|
extern "js" fn js_kind(
  path : String,
  follow_symlink : Bool,
) -> JsPromise[Int32] =
  #| async (path, followSymlink) => {
  #|   const fs = await import('node:fs/promises');
  #|   const stat = followSymlink ? await fs.stat(path) : await fs.lstat(path);
  #|   if (stat.isFile()) return 1;
  #|   if (stat.isDirectory()) return 2;
  #|   if (stat.isSymbolicLink()) return 3;
  #|   if (stat.isSocket()) return 4;
  #|   if (stat.isFIFO()) return 5;
  #|   if (stat.isBlockDevice()) return 6;
  #|   if (stat.isCharacterDevice()) return 7;
  #|   return 0;
  #| }

///|
extern "js" fn js_realpath(path : String) -> JsPromise[String] =
  #| async (path) => {
  #|   const fs = await import('node:fs/promises');
  #|   return await fs.realpath(path);
  #| }

///|
pub async fn kind(
  path : StringView,
  follow_symlink? : Bool,
) -> FileKind raise IOError {
  let i : Int32 = run_js_promise(
    js_kind(path.to_owned(), follow_symlink.unwrap_or(true)),
  )
  match i {
    1 => Regular
    2 => Directory
    3 => SymLink
    4 => Socket
    5 => Pipe
    6 => BlockDevice
    7 => CharDevice
    _ => Unknown
  }
}

///|
pub async fn realpath(path : StringView) -> String raise IOError {
  run_js_promise(js_realpath(path.to_owned()))
}

///|
extern "js" fn js_symlink(
  target : String,
  link_path : String,
) -> JsPromise[Unit] =
  #| async (target, linkPath) => {
  #|   const fs = await import('node:fs/promises');
  #|   await fs.symlink(target, linkPath);
  #| }

///|
pub async fn symlink(
  target~ : StringView,
  link_path : StringView,
) -> Unit raise IOError {
  run_js_promise(js_symlink(target.to_owned(), link_path.to_owned()))
}

///|
pub struct File {
  priv write_controller : @io.BinaryWriterController
  priv id : Int32
  priv fd : Int32
  priv path : String
  priv kind : FileKind
  priv read_buf : @io.BinaryReaderController
}

///|
pub async fn open(
  path : StringView,
  mode~ : Mode,
  sync? : SyncMode,
  append? : Bool,
  create_mode? : CreateMode,
  permission? : Int32,
  create? : Int32,
  truncate? : Bool,
) -> File raise IOError {
  let create_mode = match create_mode {
    Some(mode) => mode
    None =>
      match (create is Some(_), truncate.unwrap_or(false)) {
        (true, true) => CreateOrTruncate
        (true, false) => OpenOrCreate
        (false, true) => TruncateExisting
        (false, false) => OpenExisting
      }
  }
  let permission = permission_or_create(permission?, create?)
  let path_string = path.to_owned()
  let result = run_js_promise(
    js_file_open(
      path_string,
      mode_to_int(mode),
      create_mode_to_int(create_mode),
      permission,
      append.unwrap_or(false),
      sync_mode_to_int(sync.unwrap_or(NoSync)),
    ),
  )
  File::{
    write_controller: @io.BinaryWriterController(),
    id: result.id,
    fd: result.fd,
    path: path_string,
    kind: js_kind_to_file_kind(result.kind),
    read_buf: @io.BinaryReaderController(),
  }
}

///|
pub async fn create(
  path : StringView,
  allow_existing? : Bool,
  permission? : Int32,
  sync? : SyncMode,
) -> File raise IOError {
  open(
    path,
    mode=WriteOnly,
    sync?,
    create_mode=if allow_existing.unwrap_or(true) {
      CreateOrTruncate
    } else {
      CreateNew
    },
    permission=permission.unwrap_or(0o644),
  )
}

///|
pub fn File::close(self : File) -> Unit {
  js_file_close(self.id)
}

///|
pub fn File::fd(self : File) -> Int32 {
  self.fd
}

///|
pub fn File::as_dir(self : File) -> Directory raise IOError {
  self.close()
  raise IOError::IOError(
    "File::as_dir is not supported on js target: " + self.path,
  )
}

///|
pub fn File::kind(self : File) -> FileKind {
  self.kind
}

///|
pub async fn File::size(self : File) -> Int64 raise IOError {
  run_js_promise(js_file_size(self.id)).to_int64()
}

///|
pub async fn File::atime(self : File) -> (Int64, Int32) raise IOError {
  run_js_promise(js_file_time(self.id, 1)) |> time_to_tuple
}

///|
pub async fn File::mtime(self : File) -> (Int64, Int32) raise IOError {
  run_js_promise(js_file_time(self.id, 2)) |> time_to_tuple
}

///|
pub async fn File::ctime(self : File) -> (Int64, Int32) raise IOError {
  run_js_promise(js_file_time(self.id, 3)) |> time_to_tuple
}

///|
pub async fn File::read_at(
  self : File,
  buf : FixedArray[Byte],
  position~ : Int64,
  offset? : Int32,
  len? : Int32,
) -> Int32 raise IOError {
  let offset = offset.unwrap_or(0)
  let len = len.unwrap_or(buf.length() - offset)
  let data = run_js_promise(js_file_read_at(self.id, len, position))
  let n = if data.length() < len { data.length() } else { len }
  buf.blit_from_bytes(offset, data, 0, n)
  n
}

///|
pub async fn File::read_exactly_at(
  self : File,
  len : Int32,
  position~ : Int64,
) -> Bytes raise IOError {
  let data = run_js_promise(js_file_read_at(self.id, len, position))
  if data.length() < len {
    raise IOError::IOError("ReaderClosed")
  }
  data
}

///|
pub async fn File::write_at(
  self : File,
  buf : BytesView,
  position~ : Int64,
) -> Unit raise IOError {
  js_file_write_at(
    self.id,
    buf.data(),
    buf.start_offset(),
    buf.length(),
    position,
  )
  |> run_js_promise
}

///|
pub async fn File::sync(self : File, only_data? : Bool) -> Unit raise IOError {
  run_js_promise(js_file_sync(self.id, only_data.unwrap_or(false)))
}

///|
pub async fn File::lock(_self : File, _lock : Lock) -> Unit raise IOError {
  @async.sleep(0)
  raise IOError::IOError("File::lock is not supported on js target")
}

///|
pub fn File::try_lock(_self : File, _lock : Lock) -> Bool raise IOError {
  raise IOError::IOError("File::try_lock is not supported on js target")
}

///|
pub fn File::unlock(_self : File) -> Unit {

}

///|
impl @io.BinaryReaderImpl for File with fn get_controller(self) {
  self.read_buf
}

///|
impl @io.BinaryReaderImpl for File with fn raw_read_impl(
  self,
  buf,
  offset~,
  max_len~,
) {
  if max_len <= 0 {
    0
  } else {
    let data = run_js_promise(js_file_read(self.id, max_len)) catch {
      _ => return 0
    }
    let n = if data.length() < max_len { data.length() } else { max_len }
    buf.blit_from_bytes(offset, data, 0, n)
    n
  }
}

///|
impl @io.BinaryWriterImpl for File with fn raw_write_impl(
  self,
  buf,
  offset~,
  len~,
) {
  let available = buf.length() - offset
  let n = if len < available { len } else { available }
  if n <= 0 {
    0
  } else {
    run_js_promise(js_file_write(self.id, buf, offset, n)) catch {
      _ => 0
    }
  }
}

///|
pub async fn tmpdir(prefix~ : StringView) -> String raise IOError {
  run_js_promise(js_tmpdir(prefix.to_owned()))
}

///|
priv struct JsDirectoryEntry {
  done : Bool
  name : String
  is_dir : Bool
}

///|
#external
type JsWatcherHandle

///|
extern "js" fn js_watcher_new(
  root : String,
  debounce_timeout : Int32,
  max_debounce_delay : Int32,
) -> JsPromise[JsWatcherHandle] =
  #| async (root, debounceTimeout, maxDebounceDelay) => {
  #|   const fs = await import('node:fs');
  #|   const fsp = await import('node:fs/promises');
  #|   const path = await import('node:path');
  #|   const rootAbs = path.resolve(root);
  #|   const stat = await fsp.stat(rootAbs);
  #|   if (!stat.isDirectory()) {
  #|     throw new Error(`not a directory: ${root}`);
  #|   }
  #|   const debounceMs = Math.max(0, Number(debounceTimeout || 0));
  #|   const maxDelayMs = Math.max(debounceMs, Number(maxDebounceDelay || 0));
  #|   const handle = {
  #|     closed: false,
  #|     queue: [],
  #|     waiters: [],
  #|     known: new Map(),
  #|     timer: null,
  #|     firstEventAt: 0,
  #|     debounceMs,
  #|     maxDelayMs,
  #|     watcher: null,
  #|   };
  #|   const normalize = (filename) => {
  #|     if (filename == null || filename === '') return '';
  #|     const raw = Buffer.isBuffer(filename) ? filename.toString() : String(filename);
  #|     const rel = path.normalize(raw).split(path.sep).join('/');
  #|     return rel === '.' ? '' : (rel.startsWith('./') ? rel.slice(2) : rel);
  #|   };
  #|   const absForRel = (rel) => rel === '' ? rootAbs : path.join(rootAbs, ...rel.split('/'));
  #|   const fileKey = (stat) => `${stat.isDirectory() ? 'd' : 'f'}:${Number(stat.size)}:${Number(stat.mtimeMs)}`;
  #|   const snapshotPath = async (rel) => {
  #|     try {
  #|       const stat = await fsp.stat(absForRel(rel));
  #|       return { exists: true, key: fileKey(stat), isDir: stat.isDirectory() };
  #|     } catch (err) {
  #|       if (err?.code === 'ENOENT' || err?.code === 'ENOTDIR') {
  #|         return { exists: false, key: '', isDir: false };
  #|       }
  #|       throw err;
  #|     }
  #|   };
  #|   const snapshotTree = async (dirAbs, relPrefix) => {
  #|     let entries;
  #|     try {
  #|       entries = await fsp.readdir(dirAbs, { withFileTypes: true });
  #|     } catch {
  #|       return;
  #|     }
  #|     for (const entry of entries) {
  #|       const rel = relPrefix ? `${relPrefix}/${entry.name}` : entry.name;
  #|       const state = await snapshotPath(rel);
  #|       if (!state.exists) continue;
  #|       handle.known.set(rel, state.key);
  #|       if (state.isDir) {
  #|         await snapshotTree(absForRel(rel), rel);
  #|       }
  #|     }
  #|   };
  #|   const updatePath = async (rel) => {
  #|     const state = await snapshotPath(rel);
  #|     const prev = handle.known.get(rel);
  #|     if (!state.exists) {
  #|       if (prev === undefined) return false;
  #|       handle.known.delete(rel);
  #|       return true;
  #|     }
  #|     handle.known.set(rel, state.key);
  #|     if (state.isDir) {
  #|       await snapshotTree(absForRel(rel), rel);
  #|     }
  #|     return prev !== state.key;
  #|   };
  #|   const filterChanged = async (batch) => {
  #|     const changed = [];
  #|     for (const rel of batch) {
  #|       if (await updatePath(rel)) {
  #|         changed.push(rel);
  #|       }
  #|     }
  #|     return changed;
  #|   };
  #|   const flush = () => {
  #|     if (handle.timer) {
  #|       clearTimeout(handle.timer);
  #|       handle.timer = null;
  #|     }
  #|     if (handle.waiters.length === 0 || handle.queue.length === 0) return;
  #|     const seen = new Set();
  #|     const batch = [];
  #|     for (const item of handle.queue.splice(0)) {
  #|       if (seen.has(item)) continue;
  #|       seen.add(item);
  #|       batch.push(item);
  #|     }
  #|     handle.firstEventAt = 0;
  #|     const waiters = handle.waiters.splice(0);
  #|     for (const waiter of waiters) waiter.resolve(batch);
  #|   };
  #|   const schedule = () => {
  #|     if (handle.closed || handle.waiters.length === 0 || handle.queue.length === 0) return;
  #|     if (handle.timer) clearTimeout(handle.timer);
  #|     const elapsed = Date.now() - handle.firstEventAt;
  #|     const remainingMax = Math.max(0, handle.maxDelayMs - elapsed);
  #|     const delay = Math.min(handle.debounceMs, remainingMax);
  #|     handle.timer = setTimeout(flush, delay);
  #|   };
  #|   handle.watcher = fs.watch(rootAbs, { recursive: true, persistent: true }, (_eventType, filename) => {
  #|     if (handle.closed) return;
  #|     if (handle.firstEventAt === 0) handle.firstEventAt = Date.now();
  #|     handle.queue.push(normalize(filename));
  #|     schedule();
  #|   });
  #|   handle.flush = flush;
  #|   handle.schedule = schedule;
  #|   handle.filterChanged = filterChanged;
  #|   handle.known.set('', fileKey(stat));
  #|   await snapshotTree(rootAbs, '');
  #|   return handle;
  #| }

///|
extern "js" fn js_watcher_wait(
  handle : JsWatcherHandle,
) -> JsPromise[FixedArray[String]] =
  #| async (handle) => {
  #|   if (!handle || handle.closed) throw new Error('watcher already closed');
  #|   while (true) {
  #|     const batch = await new Promise((resolve, reject) => {
  #|       handle.waiters.push({ resolve, reject });
  #|       handle.schedule();
  #|     });
  #|     if (!batch || batch.length === 0) return [];
  #|     const changed = await handle.filterChanged(batch);
  #|     if (changed.length > 0) return changed;
  #|     if (handle.closed) return [];
  #|   }
  #| }

///|
extern "js" fn js_watcher_close(handle : JsWatcherHandle) -> Unit =
  #| (handle) => {
  #|   if (!handle || handle.closed) return;
  #|   handle.closed = true;
  #|   if (handle.timer) {
  #|     clearTimeout(handle.timer);
  #|     handle.timer = null;
  #|   }
  #|   try { handle.watcher?.close?.(); } catch {}
  #|   const waiters = handle.waiters.splice(0);
  #|   for (const waiter of waiters) waiter.resolve([]);
  #|   handle.queue.length = 0;
  #| }

///|
extern "js" fn js_opendir(path : String) -> JsPromise[Int32] =
  #| async (path) => {
  #|   const fs = await import('node:fs/promises');
  #|   if (!globalThis.__xfsDirs) globalThis.__xfsDirs = { nextId: 1, dirs: new Map() };
  #|   const state = globalThis.__xfsDirs;
  #|   const dir = await fs.opendir(path);
  #|   const id = state.nextId++;
  #|   state.dirs.set(id, { dir, specialIndex: 0 });
  #|   return id | 0;
  #| }

///|
extern "js" fn js_dir_close(id : Int32) -> Unit =
  #| (id) => {
  #|   const state = globalThis.__xfsDirs;
  #|   const handle = state?.dirs?.get(id);
  #|   if (!handle) return;
  #|   state.dirs.delete(id);
  #|   handle.dir.close().catch(() => {});
  #| }

///|
extern "js" fn js_dir_next(
  id : Int32,
  include_hidden : Bool,
  include_special : Bool,
) -> JsPromise[JsDirectoryEntry] =
  #| async (id, includeHidden, includeSpecial) => {
  #|   const state = globalThis.__xfsDirs;
  #|   const handle = state?.dirs?.get(id);
  #|   if (!handle) throw new Error('directory handle not found');
  #|   if (includeSpecial && handle.specialIndex < 2) {
  #|     const name = handle.specialIndex === 0 ? '.' : '..';
  #|     handle.specialIndex++;
  #|     return { done: false, name, is_dir: true };
  #|   }
  #|   while (true) {
  #|     const entry = await handle.dir.read();
  #|     if (!entry) return { done: true, name: '', is_dir: false };
  #|     if (!includeHidden && entry.name.startsWith('.')) continue;
  #|     return { done: false, name: entry.name, is_dir: entry.isDirectory() };
  #|   }
  #| }

///|
pub struct Directory {
  id : Int32
}

///|
pub async fn opendir(path : StringView) -> Directory raise IOError {
  let id = run_js_promise(js_opendir(path.to_owned()))
  Directory::{ id, }
}

///|
pub fn Directory::close(self : Directory) -> Unit {
  js_dir_close(self.id)
}

///|
pub async fn Directory::next(
  self : Directory,
  include_hidden? : Bool,
  include_special? : Bool,
) -> DirectoryEntry? raise IOError {
  let entry = run_js_promise(
    js_dir_next(
      self.id,
      include_hidden.unwrap_or(true),
      include_special.unwrap_or(false),
    ),
  )
  if entry.done {
    None
  } else {
    Some({ name: entry.name, is_dir: entry.is_dir, })
  }
}

///|
pub async fn Directory::read_all(
  self : Directory,
  include_hidden? : Bool,
  include_special? : Bool,
) -> Array[String] raise IOError {
  let result : Array[String] = []
  while self.next(include_hidden?, include_special?) is Some(entry) {
    result.push(entry.name)
  }
  result
}

///|
pub struct Watcher {
  handle : JsWatcherHandle
  ignored_paths : (String) -> Bool
  mut closed : Bool
}

///|
pub async fn Watcher::Watcher(
  path : String,
  debounce_timeout? : Int32,
  max_debounce_delay? : Int32,
  ignored_paths? : (String) -> Bool,
) -> Watcher raise IOError {
  let handle = run_js_promise(
    js_watcher_new(
      path,
      debounce_timeout.unwrap_or(20),
      max_debounce_delay.unwrap_or(200),
    ),
  )
  Watcher::{
    handle,
    ignored_paths: ignored_paths.unwrap_or(_ => false),
    closed: false,
  }
}

///|
fn watcher_path_ignored(path : String, ignored : (String) -> Bool) -> Bool {
  if path == "" {
    return ignored(path)
  }
  let mut prefix = ""
  for part in path.split("/") {
    let owned = part.to_owned()
    prefix = if prefix == "" { owned } else { prefix + "/" + owned }
    if ignored(prefix) {
      return true
    }
  }
  false
}

///|
pub fn Watcher::close(self : Watcher) -> Unit {
  if self.closed {
    return
  }
  self.closed = true
  js_watcher_close(self.handle)
}

///|
pub async fn Watcher::wait_any(self : Watcher) -> Unit raise IOError {
  if self.closed {
    raise IOError::IOError("watcher already closed")
  }
  for ;; {
    let paths = run_js_promise(js_watcher_wait(self.handle))
    if self.closed {
      raise IOError::IOError("watcher already closed")
    }
    for path in paths {
      if !watcher_path_ignored(path, self.ignored_paths) {
        return
      }
    }
  }
}

///|
pub async fn walk(
  path : StringView,
  f : async (String, Array[String]) -> Unit,
  exclude? : (String) -> Bool,
  max_concurrency? : Int32,
  allow_failure? : Bool,
) -> Unit raise IOError {
  let max_concurrency = max_concurrency.unwrap_or(1000)
  guard max_concurrency > 0 else {
    raise IOError::IOError("max_concurrency must be positive")
  }
  let sem = @async.Semaphore(max_concurrency)
  @async.with_task_group(group => {
    fn should_exclude(path : String) -> Bool {
      match exclude {
        Some(f) => f(path)
        None => false
      }
    }

    fn handle_path(path : String) -> Unit {
      guard !should_exclude(path) else { return }
      group.spawn_bg(allow_failure=allow_failure.unwrap_or(false), () => {
        sem.acquire()
        defer sem.release()
        let dir = opendir(path)
        defer dir.close()
        let files : Array[String] = []
        while dir.next(include_hidden=true, include_special=false)
              is Some(entry) {
          let child_path = if path is [.., '/'] {
            path + entry.name
          } else {
            path + "/" + entry.name
          }
          if entry.is_dir {
            handle_path(child_path)
          }
          files.push(entry.name)
        }
        f(path, files)
      })
    }

    handle_path(path.to_owned())
  }) catch {
    err => raise IOError::IOError(err.to_string())
  }
}

///|
pub impl @io.BinaryReader for File

///|
pub extend File with @io.BinaryReader::{
  read_into,
  read_at_least,
  peek,
  peek_at_least,
  read_exactly,
  drop_exactly,
  peek_exactly,
  drop_all,
  peek_until,
}

///|
pub impl @io.BinaryWriter for File

///|
pub extend File with @io.BinaryWriter::{write_reader}

///|
impl @io.BinaryWriterImpl for File with fn get_controller(self) {
  self.write_controller
}

///|
impl @io.BinaryReaderImpl for File with fn name(_self) {
  "File"
}

///|
impl @io.BinaryWriterImpl for File with fn name(_self) {
  "File"
}

///|
impl @io.BinaryWriterImpl for File with fn flush_partial_data(_self) {
  ()
}
