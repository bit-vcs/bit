///|
/// Git モジュール構造の作成
///
/// サブディレクトリを git submodule 風の構造で初期化し、
/// 標準の git コマンドが透過的に動作するようにする。

///|
/// サブディレクトリをモジュールとして初期化
pub fn init_module(
  fs : &@git.FileSystem,
  rfs : &@git.RepoFileSystem,
  git_dir : String,
  repo_root : String,
  subdir_path : String
) -> Unit raise SubdirError {
  let normalized_path = normalize_subdir_path(subdir_path)
  let module_name = path_to_module_name(normalized_path)
  let module_dir = git_dir + "/modules/" + module_name
  let subdir_abs = repo_root + "/" + normalized_path
  // 1. modules ディレクトリを作成
  fs.mkdir_p(module_dir) catch {
    _ => raise IoError("failed to create module directory")
  }
  fs.mkdir_p(module_dir + "/refs/heads") catch { _ => () }
  fs.mkdir_p(module_dir + "/refs/tags") catch { _ => () }
  // 2. HEAD を作成（親の HEAD を参照）
  let parent_head = read_parent_head(rfs, git_dir)
  let head_content = match parent_head {
    Some(ref_str) => ref_str
    None => "ref: refs/heads/main\n"
  }
  fs.write_file(module_dir + "/HEAD", string_to_bytes_mod(head_content)) catch {
    _ => raise IoError("failed to write HEAD")
  }
  // 3. config を作成
  let depth = count_path_depth(normalized_path)
  let rel_worktree = build_relative_path(depth + 2, normalized_path)
  let config_content = build_module_config(rel_worktree, normalized_path)
  fs.write_file(module_dir + "/config", string_to_bytes_mod(config_content)) catch {
    _ => raise IoError("failed to write config")
  }
  // 4. objects へのシンボリックリンク（または共有参照）
  // MoonBit の FileSystem には symlink がないので、代わりに alternates を使う
  let objects_dir = module_dir + "/objects"
  fs.mkdir_p(objects_dir) catch { _ => () }
  fs.mkdir_p(objects_dir + "/info") catch { _ => () }
  let alternates_content = git_dir + "/objects\n"
  fs.write_file(
    objects_dir + "/info/alternates",
    string_to_bytes_mod(alternates_content),
  ) catch {
    _ => raise IoError("failed to write alternates")
  }
  // 5. サブディレクトリに .git ファイルを作成
  let gitdir_rel = build_gitdir_path(depth, module_name)
  let gitfile_content = "gitdir: " + gitdir_rel + "\n"
  fs.write_file(subdir_abs + "/.git", string_to_bytes_mod(gitfile_content)) catch {
    _ => raise IoError("failed to write .git file")
  }
  // 6. exclude ファイルを作成（.git ファイルを除外しない設定）
  let info_dir = module_dir + "/info"
  fs.mkdir_p(info_dir) catch { _ => () }
  fs.write_file(info_dir + "/exclude", string_to_bytes_mod("")) catch { _ => () }
}

///|
/// モジュールが初期化済みかチェック
pub fn is_module_initialized(
  rfs : &@git.RepoFileSystem,
  git_dir : String,
  subdir_path : String
) -> Bool {
  let normalized_path = normalize_subdir_path(subdir_path)
  let module_name = path_to_module_name(normalized_path)
  let module_dir = git_dir + "/modules/" + module_name
  rfs.is_dir(module_dir) && rfs.is_file(module_dir + "/HEAD")
}

///|
/// モジュールを削除
pub fn deinit_module(
  fs : &@git.FileSystem,
  rfs : &@git.RepoFileSystem,
  git_dir : String,
  repo_root : String,
  subdir_path : String
) -> Unit raise SubdirError {
  let normalized_path = normalize_subdir_path(subdir_path)
  let module_name = path_to_module_name(normalized_path)
  let module_dir = git_dir + "/modules/" + module_name
  let subdir_abs = repo_root + "/" + normalized_path
  // .git ファイルを削除
  fs.remove_file(subdir_abs + "/.git") catch { _ => () }
  // モジュールディレクトリを削除
  if rfs.is_dir(module_dir) {
    remove_module_dir(fs, rfs, module_dir)
  }
}

///|
/// モジュールの状態を親リポジトリと同期
pub fn sync_module(
  fs : &@git.FileSystem,
  rfs : &@git.RepoFileSystem,
  git_dir : String,
  subdir_path : String
) -> Unit raise SubdirError {
  let normalized_path = normalize_subdir_path(subdir_path)
  let module_name = path_to_module_name(normalized_path)
  let module_dir = git_dir + "/modules/" + module_name
  // 親の HEAD を取得してモジュールの HEAD を更新
  let parent_head = read_parent_head(rfs, git_dir)
  match parent_head {
    Some(ref_str) => {
      fs.write_file(module_dir + "/HEAD", string_to_bytes_mod(ref_str)) catch {
        _ => raise IoError("failed to sync HEAD")
      }
    }
    None => ()
  }
}

///|
/// 初期化済みモジュール一覧を取得
pub fn list_modules(
  rfs : &@git.RepoFileSystem,
  git_dir : String
) -> Array[String] {
  let modules_dir = git_dir + "/modules"
  if not(rfs.is_dir(modules_dir)) {
    return []
  }
  let entries = rfs.readdir(modules_dir) catch { _ => return [] }
  let result : Array[String] = []
  for entry in entries {
    let module_path = modules_dir + "/" + entry
    if rfs.is_dir(module_path) && rfs.is_file(module_path + "/HEAD") {
      // モジュール名をパスに戻す
      result.push(module_name_to_path(entry))
    }
  }
  result
}

///|
/// パスをモジュール名に変換（/ を _ に）
fn path_to_module_name(path : String) -> String {
  let result = StringBuilder::new()
  for c in path {
    if c == '/' {
      result.write_char('_')
    } else {
      result.write_char(c)
    }
  }
  result.to_string()
}

///|
/// モジュール名をパスに戻す（_ を / に）
fn module_name_to_path(name : String) -> String {
  let result = StringBuilder::new()
  for c in name {
    if c == '_' {
      result.write_char('/')
    } else {
      result.write_char(c)
    }
  }
  result.to_string()
}

///|
/// パスの深さをカウント
fn count_path_depth(path : String) -> Int {
  let mut count = 0
  for c in path {
    if c == '/' {
      count += 1
    }
  }
  count + 1
}

///|
/// 相対パスを構築（../ を depth 回）
fn build_relative_path(depth : Int, subdir_path : String) -> String {
  let result = StringBuilder::new()
  for i = 0; i < depth; i = i + 1 {
    result.write_string("../")
  }
  result.write_string(subdir_path)
  result.to_string()
}

///|
/// gitdir パスを構築
fn build_gitdir_path(depth : Int, module_name : String) -> String {
  let result = StringBuilder::new()
  for i = 0; i < depth; i = i + 1 {
    result.write_string("../")
  }
  result.write_string(".git/modules/")
  result.write_string(module_name)
  result.to_string()
}

///|
/// モジュール用 config を生成
fn build_module_config(worktree_path : String, subdir_path : String) -> String {
  let config = StringBuilder::new()
  config.write_string("[core]\n")
  config.write_string("\trepositoryformatversion = 0\n")
  config.write_string("\tfilemode = true\n")
  config.write_string("\tbare = false\n")
  config.write_string("\tworktree = ")
  config.write_string(worktree_path)
  config.write_string("\n")
  config.write_string("[subdir]\n")
  config.write_string("\tpath = ")
  config.write_string(subdir_path)
  config.write_string("\n")
  config.write_string("\tactive = true\n")
  config.to_string()
}

///|
/// 親リポジトリの HEAD を読み取り
fn read_parent_head(rfs : &@git.RepoFileSystem, git_dir : String) -> String? {
  let head_path = git_dir + "/HEAD"
  let content = rfs.read_file(head_path) catch { _ => return None }
  Some(bytes_to_string_mod(content))
}

///|
/// モジュールディレクトリを再帰的に削除
fn remove_module_dir(
  fs : &@git.FileSystem,
  rfs : &@git.RepoFileSystem,
  path : String
) -> Unit {
  let entries = rfs.readdir(path) catch { _ => return () }
  for entry in entries {
    let child_path = path + "/" + entry
    if rfs.is_dir(child_path) {
      remove_module_dir(fs, rfs, child_path)
    } else {
      fs.remove_file(child_path) catch { _ => () }
    }
  }
  fs.remove_dir(path) catch { _ => () }
}

///|
fn string_to_bytes_mod(s : String) -> Bytes {
  let bytes : Array[Byte] = []
  for c in s {
    bytes.push(c.to_int().to_byte())
  }
  Bytes::from_array(bytes)
}

///|
fn bytes_to_string_mod(bytes : Bytes) -> String {
  let result = StringBuilder::new()
  for i = 0; i < bytes.length(); i = i + 1 {
    result.write_char(bytes[i].to_int().unsafe_to_char())
  }
  result.to_string()
}
