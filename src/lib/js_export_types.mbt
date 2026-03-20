///| JS-export specific record shapes.

///|
pub struct JsBranchInfo {
  name : String
  commit_id : String
  is_current : Bool
} derive(Show, Eq)

///|
pub struct JsLogEntry {
  id : String
  author : String
  message : String
  timestamp : Int
} derive(Show, Eq)

///|
pub struct JsRefInfo {
  name : String
  id : String
} derive(Show, Eq)

///|
pub struct JsStashEntry {
  id : String
  message : String
} derive(Show, Eq)

///|
pub struct JsMergeResult {
  status : String
  commit_id : String
  conflicts : Array[String]
} derive(Show, Eq)

///|
pub struct JsRebaseResult {
  status : String
  commit_id : String
  conflicts : Array[String]
} derive(Show, Eq)

///|
pub struct JsCherryPickResult {
  status : String
  commit_id : String
  conflicts : Array[String]
} derive(Show, Eq)

///|
pub struct JsFetchResult {
  status : String
  commit_id : String
  refname : String
  remote_ref : String
} derive(Show, Eq)
