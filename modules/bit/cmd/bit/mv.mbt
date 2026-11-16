///|
/// One validated `git mv` move: `src` -> `dst` (repo-relative), with the
/// index entries it carries (a file, or every entry below a directory).
priv struct MvMove {
  src : String
  dst : String
  gitlink : Bool
}

///|
async fn handle_mv(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let fs = OsFs::new()
  let mut force = false
  let mut skip_errors = false
  let mut dry_run = false
  let mut verbose = false
  let paths : Array[String] = []
  let mut after_separator = false
  for arg in args {
    if after_separator {
      paths.push(arg)
      continue
    }
    match arg {
      "--" => after_separator = true
      "-f" | "--force" => force = true
      "-k" => skip_errors = true
      "-n" | "--dry-run" => dry_run = true
      "-v" | "--verbose" => verbose = true
      _ if !arg.has_prefix("-") => paths.push(arg)
      _ => warn_unimplemented_arg("mv", arg)
    }
  }
  if paths.length() < 2 {
    eprint_line("usage: git mv [<options>] <source>... <destination>")
    @sys.exit(129)
  }
  let git_dir = resolve_git_dir(fs, root)
  let dest_raw = paths[paths.length() - 1]
  let dest = mv_normalize(dest_raw)
  let dest_abs = mv_abs(root, dest)
  let dest_is_dir = dest.length() == 0 ||
    (@bitio.worktree_entry_meta_sync(fs, dest_abs) is Some(m) &&
    !(m.kind is @bitio.WorktreeKindMeta::Symlink) &&
    fs.is_dir(dest_abs))
  if paths.length() > 2 && !dest_is_dir {
    mv_fatal("destination '\{dest_raw}' is not a directory")
  }
  let entries = @bitlib.read_index_entries(fs, git_dir)
  let skip = @bitlib.read_skip_worktree_paths(fs, git_dir)
  let unmerged = @bitlib.read_unmerged_paths(fs, git_dir)
  let by_path : Map[String, @bitlib.IndexEntry] = Map([])
  for e in entries {
    by_path[e.path] = e
  }
  let moves : Array[MvMove] = []
  let claimed : Map[String, Bool] = Map([])
  for i in 0..<(paths.length() - 1) {
    let src_raw = paths[i]
    let src = mv_normalize(src_raw)
    let dst = if dest_is_dir {
      let base = match src.rev_find("/") {
        Some(j) => String::unsafe_substring(src, start=j + 1, end=src.length())
        None => src
      }
      if dest.length() == 0 {
        base
      } else {
        dest + "/" + base
      }
    } else {
      dest
    }
    let src_abs = mv_abs(root, src)
    let dst_abs = mv_abs(root, dst)
    let src_meta = @bitio.worktree_entry_meta_sync(fs, src_abs)
    if src.length() == 0 || src_meta is None {
      if !skip_errors {
 mv_fatal("bad source, source=\{src}, destination=\{dst}")
 }
 continue
    }
    if src == dst || dst.has_prefix(src + "/") {
      if !skip_errors {
 mv_fatal("can not move directory into itself, source=\{src}, destination=\{dst}")
 }
 continue
    }
    let src_is_link = src_meta is Some(m) &&
      m.kind is @bitio.WorktreeKindMeta::Symlink
    let gitlink = by_path.get(src) is Some(e) && e.mode == 0o160000
    let src_is_dir = !src_is_link && !gitlink && fs.is_dir(src_abs)
    if src_is_dir {
      let prefix = src + "/"
      let has_entries = entries.iter().any(e => e.path.has_prefix(prefix))
      if !has_entries {
        if !skip_errors {
 mv_fatal("source directory is empty, source=\{src}, destination=\{dst}")
 }
 continue
      }
      if @bitio.worktree_entry_meta_sync(fs, dst_abs) is Some(_) {
        if !skip_errors {
 mv_fatal("destination already exists, source=\{src}, destination=\{dst}")
 }
 continue
      }
    } else {
      if unmerged.contains(src) {
        if !skip_errors {
 mv_fatal("conflicted, source=\{src}, destination=\{dst}")
 }
 continue
      }
      if !by_path.contains(src) {
        if !skip_errors {
 mv_fatal("not under version control, source=\{src}, destination=\{dst}")
 }
 continue
      }
      if skip.contains(src) {
        if !skip_errors {
 mv_fatal("bad source, source=\{src}, destination=\{dst}")
 }
 continue
      }
      match @bitio.worktree_entry_meta_sync(fs, dst_abs) {
        Some(m) =>
          if !force {
            if !skip_errors {
 mv_fatal("destination exists, source=\{src}, destination=\{dst}")
 }
 continue
          } else if !(m.kind is @bitio.WorktreeKindMeta::Symlink) &&
            fs.is_dir(dst_abs) {
            if !skip_errors {
 mv_fatal("cannot move directory over file, source=\{src}, destination=\{dst}")
 }
 continue
          }
        None => ()
      }
    }
    if claimed.contains(dst) {
      if !skip_errors {
 mv_fatal("multiple sources for the same target, source=\{src}, destination=\{dst}")
 }
 continue
    }
    let parent = match dst_abs.rev_find("/") {
      Some(j) => String::unsafe_substring(dst_abs, start=0, end=j)
      None => root
    }
    if !fs.is_dir(parent) {
      if skip_errors {
        continue
      }
      mv_fatal("renaming '\{src}' failed: No such file or directory")
    }
    claimed[dst] = true
    moves.push({ src, dst, gitlink })
  }
  for mv in moves {
    if verbose || dry_run {
      print_line("Renaming \{mv.src} to \{mv.dst}")
    }
  }
  if dry_run {
    return
  }
  // Gitlinks keep the library path (it also rewrites .gitmodules and the
  // submodule's gitfile); everything else is renamed on disk, so modes,
  // symlinks and unstaged edits move with the file.
  let plain = moves.filter(m => !m.gitlink)
  for mv in plain {
    @asyncfs.rename(mv_abs(root, mv.src), mv_abs(root, mv.dst), replace=force) catch {
      err => mv_fatal("renaming '\{mv.src}' failed: \{err}")
    }
  }
  if plain.length() > 0 {
    let entries = @bitlib.read_index_entries(fs, git_dir)
    let out : Array[@bitlib.IndexEntry] = []
    let moved_dst : Map[String, Bool] = Map([])
    for mv in plain {
      moved_dst[mv.dst] = true
    }
    for e in entries {
      let mut path = e.path
      for mv in plain {
        if path == mv.src {
          path = mv.dst
          break
        } else if path.has_prefix(mv.src + "/") {
          path = mv.dst +
            String::unsafe_substring(path, start=mv.src.length(), end=path.length())
          break
        }
      }
      if path == e.path && moved_dst.contains(path) {
        // Overwritten by `-f`.
        continue
      }
      out.push(
        @bitlib.IndexEntry::new(
          path,
          e.id,
          e.mode,
          e.size,
          mtime_sec=e.mtime_sec,
          mtime_nsec=e.mtime_nsec,
          intent_to_add=e.intent_to_add,
          dev=e.dev,
          ino=e.ino,
          uid=e.uid,
          gid=e.gid,
        ),
      )
    }
    @bitlib.write_index_entries_with_skip_worktree(fs, git_dir, out, skip)
  }
  for mv in moves.filter(m => m.gitlink) {
    @bitlib.mv_path(fs, fs, root, mv.src, mv.dst, force~)
  }
}

///|
fn mv_normalize(path : String) -> String {
  let parts : Array[String] = []
  for seg in path.split("/") {
    let s = seg.to_string()
    if s == "" || s == "." {
      continue
    }
    if s == ".." && parts.length() > 0 {
      ignore(parts.pop())
      continue
    }
    parts.push(s)
  }
  parts.join("/")
}

///|
fn mv_abs(root : String, path : String) -> String {
  if path.length() == 0 {
    root
  } else {
    root + "/" + path
  }
}

///|
async fn mv_fatal(msg : String) -> Unit {
  eprint_line("fatal: " + msg)
  @sys.exit(128)
}
