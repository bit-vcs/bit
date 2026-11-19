///| rev-list --missing=<action> (git's builtin/rev-list.c MA_* handling)

///|
/// State for `rev-list --missing=<action>`. `action` is "" when the option
/// was not given; otherwise one of error, allow-any, allow-promisor, print
/// and print-info.
struct RevListMissing {
  action : String
  /// (object id hex, path, type) of each missing object, in the order
  /// they were found; path and type are "" when unknown (missing tips).
  entries : Array[(String, String, String)]
  seen : Map[String, Bool]
  mut promisor_objects : Map[String, Bool]?
  /// The message git would die with, set by the first fatal miss.
  mut fatal : String?
}

///|
fn RevListMissing::new(action : String) -> RevListMissing {
  { action, entries: [], seen: Map([]), promisor_objects: None, fatal: None }
}

///|
fn rev_list_missing_action_valid(value : String) -> Bool {
  value is ("error" | "allow-any" | "allow-promisor" | "print" | "print-info")
}

///|
fn RevListMissing::active(self : RevListMissing) -> Bool {
  self.action.length() > 0
}

///|
/// Whether missing objects are collected for output (print, print-info).
fn RevListMissing::collects(self : RevListMissing) -> Bool {
  self.action == "print" || self.action == "print-info"
}

///|
fn RevListMissing::record(
  self : RevListMissing,
  hex : String,
  path : String,
  obj_type : String,
) -> Unit {
  if self.seen.contains(hex) {
    return
  }
  self.seen[hex] = true
  self.entries.push((hex, path, obj_type))
}

///|
/// A tip given on the command line (or a tag's target) is missing. git
/// records these without a type and, unless the action is "error", does not
/// die on them.
fn RevListMissing::note_tip(
  self : RevListMissing,
  id : @bitcore.ObjectId,
) -> Unit {
  if self.fatal is Some(_) {
    return
  }
  if self.action == "error" {
    self.fatal = Some("bad object \{id.to_hex()}")
  } else if self.collects() {
    self.record(id.to_hex(), "", "")
  }
}

///|
/// An object reached by the walk is missing (git's finish_object__ma).
fn RevListMissing::note(
  self : RevListMissing,
  fs : OsFs,
  git_dir : String,
  db : @bitlib.ObjectDb,
  id : @bitcore.ObjectId,
  path : String,
  obj_type : String,
) -> Unit {
  if self.fatal is Some(_) {
    return
  }
  let hex = id.to_hex()
  match self.action {
    "error" =>
      self.fatal = Some(
        if obj_type == "tree" {
          "bad tree object \{hex}"
        } else {
          "missing \{obj_type} object '\{hex}'"
        },
      )
    "print" | "print-info" => self.record(hex, path, obj_type)
    "allow-promisor" => {
      let promisor = match self.promisor_objects {
        Some(set) => set
        None => {
          let set = rev_list_collect_promisor_objects(fs, git_dir, db)
          self.promisor_objects = Some(set)
          set
        }
      }
      if !promisor.contains(hex) {
        self.fatal = Some("unexpected missing \{obj_type} object '\{hex}'")
      }
    }
    _ => ()
  }
}

///|
/// Objects git's is_promisor_object() accepts: those stored in promisor
/// packs and the objects they reference directly.
fn rev_list_collect_promisor_objects(
  fs : OsFs,
  git_dir : String,
  db : @bitlib.ObjectDb,
) -> Map[String, Bool] {
  let pack_dir = resolve_common_git_dir(fs, git_dir) + "/objects/pack"
  let in_packs = collect_pack_ids_from_marker(fs, pack_dir, ".promisor")
  let out : Map[String, Bool] = Map([])
  for hex, _ in in_packs {
    out[hex] = true
    let id = @bitcore.ObjectId::from_hex(hex) catch { _ => continue }
    let obj = db.get(fs, id) catch { _ => None }
    guard obj is Some(o) else { continue }
    match o.obj_type {
      @bitcore.ObjectType::Commit => {
        let info = @bitcore.parse_commit(o.data) catch { _ => continue }
        out[info.tree.to_hex()] = true
        for p in info.parents {
          out[p.to_hex()] = true
        }
      }
      @bitcore.ObjectType::Tree => {
        let entries = @bitcore.parse_tree(o.data) catch { _ => continue }
        for e in entries {
          out[e.id.to_hex()] = true
        }
      }
      @bitcore.ObjectType::Tag => {
        let target = @bitlib.parse_tag_object(@utf8.decode_lossy(o.data[:])) catch {
          _ => None
        }
        match target {
          Some(t) => out[t.to_hex()] = true
          None => ()
        }
      }
      _ => ()
    }
  }
  out
}

///|
/// Whether `id` is stored locally (loose or packed). Unlike
/// `ObjectDb::get`, this does not fall back to the commit-graph, which can
/// still describe a commit whose object is gone.
fn rev_list_object_exists(
  db : @bitlib.ObjectDb,
  fs : OsFs,
  id : @bitcore.ObjectId,
) -> Bool {
  (db.find_object_disk_size(fs, id) catch { _ => None }) is Some(_)
}

///|
/// git's quote_path(..., QUOTE_PATH_QUOTE_SP): C-quote, and also quote a
/// path containing a space.
fn rev_list_quote_missing_path(path : String) -> String {
  let quoted = c_quote_path(path)
  if quoted == path && path.contains(" ") {
    "\"" + path + "\""
  } else {
    quoted
  }
}

///|
/// Print the collected missing objects (git's print_missing_object).
async fn RevListMissing::print(
  self : RevListMissing,
  use_nul : Bool,
  missing_only : Bool,
) -> Unit {
  let info = self.action == "print-info"
  for entry in self.entries {
    let (hex, path, obj_type) = entry
    if use_nul {
      @stdio.stdout.write(@utf8.encode(hex))
      @stdio.stdout.write(b"\x00")
      @stdio.stdout.write(@utf8.encode("missing=yes"))
      if info && path.length() > 0 {
        @stdio.stdout.write(b"\x00")
        @stdio.stdout.write(@utf8.encode("path=" + path))
      }
      if info && obj_type.length() > 0 {
        @stdio.stdout.write(b"\x00")
        @stdio.stdout.write(@utf8.encode("type=" + obj_type))
      }
      @stdio.stdout.write(b"\x00")
    } else {
      let line = StringBuilder()
      if !missing_only {
        line.write_char('?')
      }
      line.write_string(hex)
      if info && path.length() > 0 {
        line.write_string(" path=" + rev_list_quote_missing_path(path))
      }
      if info && obj_type.length() > 0 {
        line.write_string(" type=" + obj_type)
      }
      print_line(line.to_string())
    }
  }
}

///|
/// Mark `tree_id` and everything reachable from it as uninteresting for
/// `--objects` (git's mark_tree_uninteresting). Missing objects are skipped.
fn rev_list_mark_tree_uninteresting(
  db : @bitlib.ObjectDb,
  fs : OsFs,
  tree_id : @bitcore.ObjectId,
  out : Map[String, Bool],
) -> Unit {
  let stack = [tree_id]
  while stack.pop() is Some(id) {
    let hex = id.to_hex()
    if out.contains(hex) {
      continue
    }
    out[hex] = true
    let obj = db.get(fs, id) catch { _ => None }
    guard obj is Some(o) && o.obj_type == @bitcore.ObjectType::Tree else {
      continue
    }
    let entries = @bitcore.parse_tree(o.data) catch { _ => continue }
    for e in entries {
      if e.mode == "160000" {
        continue
      }
      if e.mode.has_prefix("40") {
        stack.push(e.id)
      } else {
        out[e.id.to_hex()] = true
      }
    }
  }
}
