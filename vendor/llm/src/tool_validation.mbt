///|
/// Backward-compatible wrapper for `mizchi/llm/tools::validate_tool_input`.

///|
pub fn validate_tool_input(input : Json, schema : Json) -> Array[String] {
  @tools.validate_tool_input(input, schema)
}

///|
pub fn validate_params(input : Json, schema : Json) -> Array[String] {
  @tools.validate_params(input, schema)
}
