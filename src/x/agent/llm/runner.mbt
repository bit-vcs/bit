///|
pub struct LlmAgentConfig {
  work_dir : String
  task : String
  branch_name : String
  target_branch : String
  provider_name : String
  model : String
  max_steps : Int
  auto_commit : Bool
  auto_pr : Bool
  pr_title : String
  verbose : Bool
}

///|
fn build_system_prompt(work_dir : String, task : String) -> String {
  let guidelines =
    #|
    #|Guidelines:
    #|- Read existing code before modifying it
    #|- Make minimal, focused changes
    #|- Use run_command to verify your changes (e.g., run tests, type-check)
    #|- When done, stop calling tools and summarize what you did
  let buf = StringBuilder::new()
  buf.write_string("You are a coding agent working in the directory: ")
  buf.write_string(work_dir)
  buf.write_string("\n\nYour task: ")
  buf.write_string(task)
  buf.write_string("\n")
  buf.write_string(guidelines)
  buf.to_string()
}

///|
fn create_provider(
  name : String,
  model : String,
  system_prompt : String,
) -> @llmlib.BoxedProvider {
  match name {
    "anthropic" => {
      let api_key = @ffi.get_env("ANTHROPIC_API_KEY")
      let m = if model.is_empty() {
        @llmlib.default_anthropic_model
      } else {
        model
      }
      let provider = @anthropic.AnthropicProvider::new(
        api_key,
        model=m,
        system_prompt~,
        max_tokens=8192,
      )
      @llmlib.BoxedProvider::new(provider)
    }
    "openai" => {
      let api_key = @ffi.get_env("OPENAI_API_KEY")
      let m = if model.is_empty() {
        @llmlib.default_openai_model
      } else {
        model
      }
      let provider = @openai.OpenAIProvider::new(
        api_key,
        model=m,
        system_prompt~,
        max_tokens=8192,
      )
      @llmlib.BoxedProvider::new(provider)
    }
    "openrouter" => {
      let api_key = @ffi.get_env("OPENROUTER_API_KEY")
      let m = if model.is_empty() {
        @llmlib.default_openrouter_model
      } else {
        model
      }
      let provider = @openai.OpenAIProvider::new(
        api_key,
        endpoint=OpenRouter,
        model=m,
        system_prompt~,
        max_tokens=8192,
      )
      @llmlib.BoxedProvider::new(provider)
    }
    "claude_code" => {
      let m = if model.is_empty() { "" } else { model }
      let provider = @claude_code.ClaudeCodeProvider::new(
        model=m,
        system_prompt~,
      )
      @llmlib.BoxedProvider::new(provider)
    }
    _ => {
      println("Unknown provider: " + name + ", falling back to anthropic")
      create_provider("anthropic", model, system_prompt)
    }
  }
}

///|
pub fn run_llm_agent(config : LlmAgentConfig) -> Unit {
  let system_prompt = build_system_prompt(config.work_dir, config.task)
  let provider = create_provider(
    config.provider_name,
    config.model,
    system_prompt,
  )
  let registry = create_tool_registry(config.work_dir)
  let messages : Array[@llmlib.Message] = [@llmlib.Message::user(config.task)]
  let verbose = config.verbose
  if verbose {
    println(
      "[agent] provider=" + config.provider_name + " model=" + config.model,
    )
    println("[agent] work_dir=" + config.work_dir)
    println("[agent] task=" + config.task)
    println("")
  }
  let text_buf = StringBuilder::new()
  @llmlib.run_agent(
    provider,
    registry,
    messages,
    @llmlib.StopCondition::MaxSteps(config.max_steps),
    fn(event) {
      match event {
        Stream(stream_event) =>
          match stream_event {
            TextDelta(s) => text_buf.write_string(s)
            _ => ()
          }
        ToolExecute(name~, input~) =>
          if verbose {
            let text = text_buf.to_string()
            if not(text.is_empty()) {
              println(text)
              text_buf.reset()
            }
            println("\n[tool] " + name + " " + input.stringify())
          }
        ToolResult(name~, result~, is_error~) =>
          if verbose {
            let status = if is_error { " ERROR" } else { " ok" }
            let preview = if result.length() > 200 {
              let buf = StringBuilder::new()
              let rchars : Array[Char] = []
              for ch in result {
                rchars.push(ch)
              }
              for j = 0; j < 200; j = j + 1 {
                buf.write_char(rchars[j])
              }
              buf.write_string("...")
              buf.to_string()
            } else {
              result
            }
            println("[result] " + name + status + ": " + preview)
          }
        StepComplete(step~) => {
          let text = text_buf.to_string()
          if not(text.is_empty()) {
            println(text)
            text_buf.reset()
          }
          if verbose {
            println("[step " + step.to_string() + " complete]")
          }
        }
        Done(reason~) => {
          let text = text_buf.to_string()
          if not(text.is_empty()) {
            println(text)
          }
          println("\n[done] " + reason)
        }
      }
    },
  )
  // Auto-commit
  if config.auto_commit {
    let branch = config.branch_name
    let wd = config.work_dir
    if verbose {
      println("[git] creating branch: " + branch)
    }
    ignore(
      exec(
        "cd " + shell_escape(wd) + " && git checkout -b " + shell_escape(branch),
      ),
    )
    ignore(exec("cd " + shell_escape(wd) + " && git add -A"))
    let msg = "agent: " + config.task
    ignore(
      exec("cd " + shell_escape(wd) + " && git commit -m " + shell_escape(msg)),
    )
    if verbose {
      println("[git] committed on branch: " + branch)
    }
  }
  // Auto-PR
  if config.auto_pr {
    let wd = config.work_dir
    let branch = config.branch_name
    let title = if config.pr_title.is_empty() {
      "agent: " + config.task
    } else {
      config.pr_title
    }
    ignore(
      exec_with_timeout(
        "cd " +
        shell_escape(wd) +
        " && git push -u origin " +
        shell_escape(branch),
        60000,
      ),
    )
    let result = exec_with_timeout(
      "cd " +
      shell_escape(wd) +
      " && gh pr create --title " +
      shell_escape(title) +
      " --body 'Created by bit agent' --base " +
      shell_escape(config.target_branch),
      60000,
    )
    println("[pr] " + result)
  }
}
