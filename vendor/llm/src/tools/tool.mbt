///|
/// ToolDef defines a tool that can be called by the model.
pub(all) struct ToolDef {
  name : String
  description : String
  input_schema : Json
}

///|
pub fn ToolDef::new(
  name : String,
  description : String,
  input_schema : Json,
) -> ToolDef {
  { name, description, input_schema }
}

///|
/// ToolChoice controls how the model selects tools.
pub(all) enum ToolChoice {
  Auto
  None
  Required
  Specific(String)
}

///|
/// SchemaBuilder helps construct JSON Schema for tool input_schema.
pub(all) struct SchemaBuilder {
  properties : Map[String, Json]
  required : Array[String]
}

///|
pub fn SchemaBuilder::new() -> SchemaBuilder {
  { properties: Map([]), required: [] }
}

///|
/// Add a string property.
pub fn SchemaBuilder::string(
  self : SchemaBuilder,
  name : String,
  description : String,
  required? : Bool = false,
) -> SchemaBuilder {
  let prop : Map[String, Json] = Map([])
  prop["type"] = ToJson::to_json("string")
  prop["description"] = ToJson::to_json(description)
  self.properties[name] = Json::object(prop)
  if required {
    self.required.push(name)
  }
  self
}

///|
/// Add a number property.
pub fn SchemaBuilder::number(
  self : SchemaBuilder,
  name : String,
  description : String,
  required? : Bool = false,
) -> SchemaBuilder {
  let prop : Map[String, Json] = Map([])
  prop["type"] = ToJson::to_json("number")
  prop["description"] = ToJson::to_json(description)
  self.properties[name] = Json::object(prop)
  if required {
    self.required.push(name)
  }
  self
}

///|
/// Add an integer property.
pub fn SchemaBuilder::integer(
  self : SchemaBuilder,
  name : String,
  description : String,
  required? : Bool = false,
) -> SchemaBuilder {
  let prop : Map[String, Json] = Map([])
  prop["type"] = ToJson::to_json("integer")
  prop["description"] = ToJson::to_json(description)
  self.properties[name] = Json::object(prop)
  if required {
    self.required.push(name)
  }
  self
}

///|
/// Add a boolean property.
pub fn SchemaBuilder::boolean(
  self : SchemaBuilder,
  name : String,
  description : String,
  required? : Bool = false,
) -> SchemaBuilder {
  let prop : Map[String, Json] = Map([])
  prop["type"] = ToJson::to_json("boolean")
  prop["description"] = ToJson::to_json(description)
  self.properties[name] = Json::object(prop)
  if required {
    self.required.push(name)
  }
  self
}

///|
/// Add a string enum property.
pub fn SchemaBuilder::string_enum(
  self : SchemaBuilder,
  name : String,
  description : String,
  values : Array[String],
  required? : Bool = false,
) -> SchemaBuilder {
  let prop : Map[String, Json] = Map([])
  prop["type"] = ToJson::to_json("string")
  prop["description"] = ToJson::to_json(description)
  prop["enum"] = Json::array(values.map(fn(v) { ToJson::to_json(v) }))
  self.properties[name] = Json::object(prop)
  if required {
    self.required.push(name)
  }
  self
}

///|
/// Add an array property with item type.
pub fn SchemaBuilder::array(
  self : SchemaBuilder,
  name : String,
  description : String,
  item_type : String,
  required? : Bool = false,
) -> SchemaBuilder {
  let items : Map[String, Json] = Map([])
  items["type"] = ToJson::to_json(item_type)
  let prop : Map[String, Json] = Map([])
  prop["type"] = ToJson::to_json("array")
  prop["description"] = ToJson::to_json(description)
  prop["items"] = Json::object(items)
  self.properties[name] = Json::object(prop)
  if required {
    self.required.push(name)
  }
  self
}

///|
/// Build the JSON Schema object.
pub fn SchemaBuilder::build(self : SchemaBuilder) -> Json {
  let schema : Map[String, Json] = Map([])
  schema["type"] = ToJson::to_json("object")
  schema["properties"] = Json::object(self.properties)
  if !self.required.is_empty() {
    schema["required"] = Json::array(self.required.map(fn(s) { ToJson::to_json(s) }))
  }
  Json::object(schema)
}

///|
/// ToolRegistry manages available tools and their handlers.
pub(all) struct ToolRegistry {
  tools : Array[ToolDef]
  handlers : Map[String, (Json) -> String]
}

///|
pub(all) enum ToolExecuteError {
  ToolNotFound(String)
  InvalidParams(tool_name~ : String, errors~ : Array[String])
}

///|
pub fn ToolExecuteError::to_message(self : ToolExecuteError) -> String {
  match self {
    ToolNotFound(name) => "Error: Tool '" + name + "' not found"
    InvalidParams(tool_name~, errors~) =>
      "Error: Invalid parameters for tool '" +
      tool_name +
      "': " +
      errors.join("; ")
  }
}

///|
pub fn ToolRegistry::new() -> ToolRegistry {
  { tools: [], handlers: Map([]) }
}

///|
pub fn ToolRegistry::register(
  self : ToolRegistry,
  name : String,
  description : String,
  input_schema : Json,
  handler : (Json) -> String,
) -> Unit {
  self.register_def(ToolDef::new(name, description, input_schema), handler)
}

///|
pub fn ToolRegistry::register_def(
  self : ToolRegistry,
  tool : ToolDef,
  handler : (Json) -> String,
) -> Unit {
  self.tools.push(tool)
  self.handlers[tool.name] = handler
}

///|
pub fn ToolRegistry::execute(
  self : ToolRegistry,
  name : String,
  input : Json,
) -> (String, Bool) {
  match self.handlers.get(name) {
    Some(handler) => (handler(input), false)
    None => ("Tool not found: " + name, true)
  }
}

///|
pub fn ToolRegistry::execute_result(
  self : ToolRegistry,
  name : String,
  input : Json,
) -> Result[String, ToolExecuteError] {
  match self.find_tool(name) {
    None => Err(ToolNotFound(name))
    Some(tool) =>
      match self.handlers.get(name) {
        None => Err(ToolNotFound(name))
        Some(handler) => {
          let errors = validate_tool_input(input, tool.input_schema)
          if !errors.is_empty() {
            return Err(InvalidParams(tool_name=name, errors~))
          }
          Ok(handler(input))
        }
      }
  }
}

///|
/// Execute with schema validation before handler invocation.
pub fn ToolRegistry::execute_validated(
  self : ToolRegistry,
  name : String,
  input : Json,
) -> (String, Bool) {
  match self.find_tool(name) {
    Some(tool) => {
      let errors = validate_tool_input(input, tool.input_schema)
      if !errors.is_empty() {
        return (
          "Invalid tool input for '" + name + "': " + errors.join("; "),
          true,
        )
      }
      self.execute(name, input)
    }
    None => self.execute(name, input)
  }
}

///|
pub fn ToolRegistry::get_defs(self : ToolRegistry) -> Array[ToolDef] {
  self.tools
}

///|
pub fn ToolRegistry::has(self : ToolRegistry, name : String) -> Bool {
  self.find_tool(name) is Some(_)
}

///|
pub fn ToolRegistry::definitions(self : ToolRegistry) -> Array[Json] {
  let out : Array[Json] = []
  for tool in self.tools {
    out.push(tool.to_openai_json())
  }
  out
}

///|
fn ToolRegistry::find_tool(self : ToolRegistry, name : String) -> ToolDef? {
  for tool in self.tools {
    if tool.name == name {
      return Some(tool)
    }
  }
  None
}

///|
/// Convert ToolDef to Anthropic format JSON.
pub fn ToolDef::to_anthropic_json(self : ToolDef) -> Json {
  {
    "name": ToJson::to_json(self.name),
    "description": ToJson::to_json(self.description),
    "input_schema": self.input_schema,
  }
}

///|
/// Convert ToolDef to OpenAI format JSON.
pub fn ToolDef::to_openai_json(self : ToolDef) -> Json {
  {
    "type": ToJson::to_json("function"),
    "function": {
      "name": ToJson::to_json(self.name),
      "description": ToJson::to_json(self.description),
      "parameters": self.input_schema,
    },
  }
}
