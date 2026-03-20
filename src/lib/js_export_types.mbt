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
