///| JS-export specific record shapes.

///|
pub struct JsBranchInfo {
  name : String
  commit_id : String
  is_current : Bool
} derive(Debug, Eq)

///|
pub extend JsBranchInfo with Debug::{to_repr}

///|
pub extend JsBranchInfo with Eq::{not_equal, equal}

///|
pub struct JsLogEntry {
  id : String
  author : String
  message : String
  timestamp : Int
} derive(Debug, Eq)

///|
pub extend JsLogEntry with Debug::{to_repr}

///|
pub extend JsLogEntry with Eq::{not_equal, equal}

///|
pub struct JsRefInfo {
  name : String
  id : String
} derive(Debug, Eq)

///|
pub extend JsRefInfo with Debug::{to_repr}

///|
pub extend JsRefInfo with Eq::{not_equal, equal}

///|
pub struct JsReflogEntry {
  old_id : String
  new_id : String
  author : String
  email : String
  timestamp : Int
  timezone : String
  message : String
} derive(Debug, Eq)

///|
pub extend JsReflogEntry with Debug::{to_repr}

///|
pub extend JsReflogEntry with Eq::{not_equal, equal}

///|
pub struct JsStashEntry {
  id : String
  message : String
} derive(Debug, Eq)

///|
pub extend JsStashEntry with Debug::{to_repr}

///|
pub extend JsStashEntry with Eq::{not_equal, equal}

///|
pub struct JsRemoteVerboseEntry {
  name : String
  value : String
} derive(Debug, Eq)

///|
pub extend JsRemoteVerboseEntry with Debug::{to_repr}

///|
pub extend JsRemoteVerboseEntry with Eq::{not_equal, equal}

///|
pub struct JsMergeResult {
  status : String
  commit_id : String
  conflicts : Array[String]
} derive(Debug, Eq)

///|
pub extend JsMergeResult with Debug::{to_repr}

///|
pub extend JsMergeResult with Eq::{not_equal, equal}

///|
pub struct JsRebaseResult {
  status : String
  commit_id : String
  conflicts : Array[String]
} derive(Debug, Eq)

///|
pub extend JsRebaseResult with Debug::{to_repr}

///|
pub extend JsRebaseResult with Eq::{not_equal, equal}

///|
pub struct JsCherryPickResult {
  status : String
  commit_id : String
  conflicts : Array[String]
} derive(Debug, Eq)

///|
pub extend JsCherryPickResult with Debug::{to_repr}

///|
pub extend JsCherryPickResult with Eq::{not_equal, equal}

///|
pub struct JsFetchResult {
  status : String
  commit_id : String
  refname : String
  remote_ref : String
} derive(Debug, Eq)

///|
pub extend JsFetchResult with Debug::{to_repr}

///|
pub extend JsFetchResult with Eq::{not_equal, equal}

///|
pub struct JsCloneResult {
  status : String
  commit_id : String
  refname : String
} derive(Debug, Eq)

///|
pub extend JsCloneResult with Debug::{to_repr}

///|
pub extend JsCloneResult with Eq::{not_equal, equal}

///|
pub struct JsGcResult {
  pack_id : String
  object_count : Int
  pack_bytes : Int
  dangling : Array[String]
} derive(Debug, Eq)

///|
pub extend JsGcResult with Debug::{to_repr}

///|
pub extend JsGcResult with Eq::{not_equal, equal}

///|
pub struct JsFsckResult {
  errors : Int
  reachable : Int
  missing : Array[String]
  root_commits : Array[String]
  tag_objects : Array[String]
} derive(Debug, Eq)

///|
pub extend JsFsckResult with Debug::{to_repr}

///|
pub extend JsFsckResult with Eq::{not_equal, equal}

///|
pub struct JsWorktreeInfo {
  path : String
  head_id : String
  branch : String
  locked : Bool
  is_main : Bool
  is_bare : Bool
} derive(Debug, Eq)

///|
pub extend JsWorktreeInfo with Debug::{to_repr}

///|
pub extend JsWorktreeInfo with Eq::{not_equal, equal}
