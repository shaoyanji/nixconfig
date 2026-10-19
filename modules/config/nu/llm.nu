# =============================================================================
# Provider definitions — each declares its URL, model, and API key
# =============================================================================
const LLM_PROVIDERS = {
  groq: {
    url: "https://api.groq.com/openai/v1/chat/completions"
    model: "openai/gpt-oss-20b"
    models: ["openai/gpt-oss-120b", "llama-3.3-70b-versatile", "qwen/qwen3-32b"]
    api_key: "GROQ_API_KEY"
  }
  nvidia: {
    url: "https://integrate.api.nvidia.com/v1/chat/completions"
    # Live on integrate.api.nvidia.com as of 2026-10-19. The previous default
    # (minimaxai/minimax-m2.7) was retired upstream and answers HTTP 410, and
    # llama-3.3-nemotron-super-48b is not served to this account (404).
    model: "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning"
    models: ["nvidia/nemotron-3-nano-omni-30b-a3b-reasoning", "nvidia/nemotron-3-super-120b-a12b", "nvidia/nemotron-3-ultra-550b-a55b"]
    api_key: "NVIDIA_API_KEY"
  }
  openrouter: {
    url: "https://openrouter.ai/api/v1/chat/completions"
    model: "nvidia/nemotron-3-super-120b-a12b:free"
    models: ["nvidia/nemotron-3-super-120b-a12b:free", "google/gemini-2.0-flash-exp"]
    api_key: "OPENROUTER_API_KEY"
  }
  gemini: {
    url_base: "https://generativelanguage.googleapis.com/v1/models"
    model: "gemini-2.5-flash"
    api_key: "GEMINI_API_KEY"
  }
  cohere: {
    url: "https://api.cohere.com/v2/chat"
    model: "command-a-03-2025"
    models: ["command-a-03-2025", "command-r-plus-08-2024", "command-r-03-2025"]
    api_key: "COHERE_API_KEY"
  }
  aihubmix: {
    url: "https://aihubmix.com/v1/chat/completions"
    model: "coding-glm-5.1-free"
    models: ["coding-glm-5.1-free", "coding-minimax-m2.7-free", "coding-glm-5-turbo-free", "coding-glm-5-free", "gpt-4o-free"]
    api_key: "AIHUBMIX_API_KEY"
  }

  opencode: {
    url: "https://opencode.ai/zen/v1/chat/completions"
    model: "minimax-m2.5-free"
    models: ["ling-2.6-flash", "hy3-preview-free", "nemotron-3-super-free", "minimax-m2.5-free", "big-pickle"]
    api_key: "OPENCODE_API_KEY"
  }
}

# =============================================================================
# Helper: validate API key is set
# =============================================================================
def "ensure-api-key" [key_name: string] {
  # `get -o`: a plain `get` throws column_not_found first, so the message below
  # never printed and every caller died with a generic parser error instead.
  let key_val = ($env | get -o $key_name)
  if $key_val == null or $key_val == "" {
    error make {
      msg: $"($key_name) environment variable is not set"
    }
  }
  $key_val
}

# =============================================================================
# Helper: generic OpenAI-compatible chat request
# =============================================================================
def "chat-request" [
  url: string,
  model: string,
  api_key: string,
  messages: list,
  --temperature: float = 0.7,
  --max_tokens: int = 4096,
  --stream = false
] {
  let body = {
    model: $model
    messages: $messages
    temperature: $temperature
    max_tokens: $max_tokens
    stream: $stream
  }

  let response = (
    $body | to json | curl -sS -X POST $url -H $"Authorization: Bearer ($api_key)" -H "Content-Type: application/json" -d ($in) | from json
  )

  # Debug: print response structure if it's not what we expect
  # OpenAI-style error object
  let api_err = ($response | get -o error)
  if $api_err != null {
    let msg = ($api_err | get -o message | default ($api_err | to json))
    error make {msg: $"API error: ($msg)"}
  }

  # Non-OpenAI error shapes: FastAPI {detail}, and RFC 7807 {status,title,detail}
  # which NVIDIA returns for a retired model. The old handler read
  # `error.code`/`error.message` unconditionally and died on the missing
  # columns instead of surfacing the actual API error.
  if ($response | get -o choices) == null {
    let status = ($response | get -o status | default "")
    let title = ($response | get -o title | default "")
    let detail = ($response | get -o detail | default "")
    let what = ([$status $title] | where { |s| $s != "" } | str join " ")
    error make {
      msg: $"API error ($what): ($detail | default ($response | to json))"
    }
  }

  # Handle OpenAI-style response. A reasoning model can return content: null
  # with a finish_reason (it spent the whole budget on reasoning) — that is an
  # empty completion, not a success, so fail and let the fallback chain move on.
  let content = (try { $response | get choices.0.message.content } catch { null })
  if ($content | is-empty) {
    error make {
      msg: $"Provider returned no content (finish_reason=($response | get -o choices.0.finish_reason | default 'unknown'))"
    }
  }
  $content
}

# =============================================================================
# Provider-specific commands
# =============================================================================
export def nugroq [
  message: string,
  --model: string = "",
  --system: string = "",
  --temperature: float = 0.7,
  --max_tokens: int = 4096,
  --stream = false
] {
  let p = $LLM_PROVIDERS.groq
  let m = if $model == "" { $p.model } else { $model }
  let key = ensure-api-key "GROQ_API_KEY"
  let messages = if $system == "" {
    [{role: "user", "content": $message}]
  } else {
    [{role: "system", "content": $system}, {role: "user", "content": $message}]
  }

  chat-request $p.url $m $key $messages --temperature $temperature --max_tokens $max_tokens --stream $stream
}

export def nunvidia [
  message: string,
  --model: string = "",
  --system: string = "",
  --temperature: float = 0.7,
  --max_tokens: int = 4096,
  --stream = false
] {
  let p = $LLM_PROVIDERS.nvidia
  let m = if $model == "" { $p.model } else { $model }
  let key = ensure-api-key "NVIDIA_API_KEY"
  let messages = if $system == "" {
    [{role: "user", "content": $message}]
  } else {
    [{role: "system", "content": $system}, {role: "user", "content": $message}]
  }

  chat-request $p.url $m $key $messages --temperature $temperature --max_tokens $max_tokens --stream $stream
}

export def nurouter [
  message: string,
  --model: string = "",
  --system: string = "",
  --temperature: float = 0.7,
  --max_tokens: int = 4096,
  --stream = false
] {
  let p = $LLM_PROVIDERS.openrouter
  let m = if $model == "" { $p.model } else { $model }
  let key = ensure-api-key "OPENROUTER_API_KEY"
  let messages = if $system == "" {
    [{role: "user", "content": $message}]
  } else {
    [{role: "system", "content": $system}, {role: "user", "content": $message}]
  }

  chat-request $p.url $m $key $messages --temperature $temperature --max_tokens $max_tokens --stream $stream
}

export def nugemini [
  message: string,
  --model: string = "",
  --system: string = "",
  --temperature: float = 0.7,
  --max_tokens: int = 4096
] {
  let p = $LLM_PROVIDERS.gemini
  let m = if $model == "" { $p.model } else { $model }
  let key = ensure-api-key "GEMINI_API_KEY"
  let url = $"($p.url_base)/($m):generateContent"
  # Gemini uses a different format
  let prompt = if $system == "" {
    $message
  } else {
    $"($system)\n\n($message)"
  }

  let body = {
    contents: [{parts: [{text: $prompt}]}]
    generationConfig: {
      temperature: $temperature
      maxOutputTokens: $max_tokens
    }
  }

  let resp = ($body | to json | curl -sS -X POST $url -H $"x-goog-api-key: ($key)" -H "Content-Type: application/json" -d ($in) | from json)

  # A thinking model returns content with no parts at all when the token budget
  # is spent on thoughts (finishReason MAX_TOKENS), and `get ...content.parts`
  # then dies with a column error. Read defensively and report the reason.
  let cand = ($resp | get -o candidates.0)
  if $cand == null {
    error make {
      msg: $"Gemini returned no candidate (($resp | get -o promptFeedback.blockReason) | default 'empty response')"
    }
  }
  let text = ($cand | get -o content.parts | default [] | each { |p| $p.text? } | compact | str join "")
  if ($text | is-empty) {
    error make {
      msg: $"Gemini returned no text (finishReason=(($cand | get -o finishReason) | default 'unknown'))"
    }
  }
  $text
}

export def nuhere [
  message: string,
  --model: string = "",
  --system: string = "",
  --temperature: float = 0.7,
  --max_tokens: int = 4096
] {
  let p = $LLM_PROVIDERS.cohere
  let m = if $model == "" { $p.model } else { $model }
  let key = ensure-api-key "COHERE_API_KEY"

  # Cohere uses a different message format
  let messages = if $system == "" {
    [{role: "user", content: $message}]
  } else {
    [{role: "system", content: $system}, {role: "user", content: $message}]
  }

  let body = {
    model: $m
    messages: $messages
    temperature: $temperature
    max_tokens: $max_tokens
  }

  $body | to json | curl -sS -X POST $p.url -H $"Authorization: Bearer ($key)" -H "Content-Type: application/json" -d ($in) | from json | get message.content.text.0
}

export def nuaihubmix [
  message: string,
  --model: string = "",
  --system: string = "",
  --temperature: float = 0.7,
  --max_tokens: int = 4096
] {
  let p = $LLM_PROVIDERS.aihubmix
  let m = if $model == "" { $p.model } else { $model }
  let key = ensure-api-key "AIHUBMIX_API_KEY"

  let messages = if $system == "" {
    [{role: "user", content: $message}]
  } else {
    [{role: "system", content: $system}, {role: "user", content: $message}]
  }

  chat-request $p.url $m $key $messages --temperature $temperature --max_tokens $max_tokens
}

export def nullama [
  message: string,
  --system: string = "",
  --stream = false
] {
  # Get list of available models and pick the first (most recent) one
  let model = (
    ^ollama list
    | from ssv
    | get 0.NAME
  )

  if $model == null {
    error make {
      msg: "No Ollama models found. Is ollama running?"
    }
  }

  let messages = if $system == "" {
    [{role: "user", content: $message}]
  } else {
    [{role: "system", content: $system}, {role: "user", content: $message}]
  }

  # `fold` is not a nushell command (it resolved to coreutils and failed on the
  # closure); `each` + `str join` is what this was trying to do.
  let prompt = (
    $messages
    | each { |m| $"($m.role): ($m.content)" }
    | str join "\n"
  )

  let body = {
    model: $model
    prompt: $prompt
    stream: $stream
    options: {
      temperature: 0.7
      num_predict: 4096
    }
  }

  $body
  | to json
  | http post http://localhost:11434/api/generate
  | get response
}

export def nuopencode [
  message: string,
  --model: string = "",
  --system: string = "",
  --temperature: float = 0.7,
  --max_tokens: int = 4096
] {
  let p = $LLM_PROVIDERS.opencode
  let m = if $model == "" { $p.model } else { $model }
  let key = ensure-api-key "OPENCODE_API_KEY"

  let messages = if $system == "" {
    [{role: "user", content: $message}]
  } else {
    [{role: "system", content: $system}, {role: "user", content: $message}]
  }

  # Shared handler: surfaces provider error shapes instead of dying on a
  # missing `choices` column, and rejects an empty completion.
  chat-request $p.url $m $key $messages --temperature $temperature --max_tokens $max_tokens
}
# =============================================================================
# Default entrypoint — fallback chain with optional provider override
# =============================================================================
export def llm [
  adder?: string,
  --provider: string = "",
  --model: string = "",
  --system: string = "",
  --temperature: float = 0.7,
  --max_tokens: int = 4096
] {
  let msg = if $adder == null and ($in | is-empty) { "" } else if $adder == null { $in } else { $adder }

  # If provider specified, use it directly
  if $provider != "" {
    match $provider {
      "groq" => { return (nugroq $msg --model $model --system $system --temperature $temperature --max_tokens $max_tokens) }
      "cohere" => { return (nuhere $msg --model $model --system $system --temperature $temperature --max_tokens $max_tokens) }
      "openrouter" => { return (nurouter $msg --model $model --system $system --temperature $temperature --max_tokens $max_tokens) }
      "nvidia" => { return (nunvidia $msg --model $model --system $system --temperature $temperature --max_tokens $max_tokens) }
      "gemini" => { return (nugemini $msg --model $model --system $system --temperature $temperature --max_tokens $max_tokens) }
      "ollama" => { return (nullama $msg --system $system) }
      "aihubmix" => { return (nuaihubmix $msg --model $model --system $system --temperature $temperature --max_tokens $max_tokens) }
      "opencode" => { return (nuopencode $msg --model $model --system $system --temperature $temperature --max_tokens $max_tokens) }
      _ => { error make {msg: $"Unknown provider: ($provider)"}}
    }
  }

  # Fallback chain - model overrides apply to first provider that succeeds
  let providers = [
    {name: groq, fn: {|m| nugroq $m --model $model --system $system --temperature $temperature --max_tokens $max_tokens }},
    {name: opencode, fn: {|m| nuopencode $m --model $model --system $system --temperature $temperature --max_tokens $max_tokens }},
    {name: cohere, fn: {|m| nuhere $m --model $model --system $system --temperature $temperature --max_tokens $max_tokens }},
    {name: openrouter, fn: {|m| nurouter $m --model $model --system $system --temperature $temperature --max_tokens $max_tokens }},
    {name: nvidia, fn: {|m| nunvidia $m --model $model --system $system --temperature $temperature --max_tokens $max_tokens }},
    {name: gemini, fn: {|m| nugemini $m --model $model --system $system --temperature $temperature --max_tokens $max_tokens }},
    {name: aihubmix, fn: {|m| nuaihubmix $m --model $model --system $system --temperature $temperature --max_tokens $max_tokens }},
    # Ollama excluded from fallback - requires local server and is slow to probe
  ]

  for p in $providers {
    try {
      return (do $p.fn $msg)
    } catch { |err|
      # stderr, not stdout: `llm ... | save out.txt` must not get provider
      # error lines mixed into the answer. Bind the closure argument: bare `$in`
      # yields the whole error record (msg, debug, raw, rendered, details).
      print -e $"($p.name): ($err.msg)"
    }
  }

  error make {
    msg: "All LLM providers failed"
  }
}

export def "llm models" [] {
  print "Groq:"
  for m in $LLM_PROVIDERS.groq.models { print $"  - ($m)" }
  print "Nvidia:"
  for m in $LLM_PROVIDERS.nvidia.models { print $"  - ($m)" }
  print "OpenRouter:"
  for m in $LLM_PROVIDERS.openrouter.models { print $"  - ($m)" }
  print "Cohere:"
  for m in $LLM_PROVIDERS.cohere.models { print $"  - ($m)" }
  print "Aihubmix:"
  for m in $LLM_PROVIDERS.aihubmix.models { print $"  - ($m)" }
  print "Gemini:"
  print "  - gemini-2.5-flash (default)"
  print "Ollama: (uses first model from 'ollama list')"
}

export def "llm program" [code: string] {
  # Extract code block between ``` and ``` from LLM response
  llm $code
  | split row '```'
  | get 1
  | str trim -c '`'
}

# =============================================================================
# Chat history database functions
# =============================================================================

# This adds a local db (chatbot_conversation.db) if it doesn't exist and adds a new entry to it
export def "llm db" [uinput?: string] {
  let response = llm $uinput

  let db_path = $"($env.HOME)/chatbot_conversation.db"

  if ($db_path | path exists) {
    # Get the last ID and increment
    let last_id = (
      open $db_path
      | query db "SELECT MAX(id) FROM conversation_history"
      | get 0
    )
    let new_id = if $last_id == null { 1 } else { $last_id + 1 }

    open $db_path
    | query db $"INSERT INTO conversation_history VALUES (?, ?, ?, ?)" -p [
      $new_id
      $uinput
      $response
      (date now | format date "%Y-%m-%d %H:%M:%S")
    ]
    | print $"Saved to chat history (id: ($new_id))"
  } else {
    stor create -t conversation_history -c {id: int, user_input: str, chatbot_response: str, timestamp: datetime}
    stor insert -t conversation_history -d {id: 1, user_input: $uinput, chatbot_response: $response, timestamp: (date now)}
    stor export -f $db_path
    print "Created chat history database"
  }
}

# View conversation history
export def "llm db view" [] {
  let db_path = $"($env.HOME)/chatbot_conversation.db"

  if not ($db_path | path exists) {
    print "No conversation history found"
    return
  }

  open $db_path
  | query db "SELECT * FROM conversation_history ORDER BY id DESC LIMIT 10"
  | each { |row|
    print $"--- ID: ($row.id) ---"
    print $"User: ($row.user_input)"
    print $"Bot:  ($row.chatbot_response)"
    print $"Time: ($row.timestamp)"
    print ""
  }
}

# Clear conversation history
export def "llm db clear" [] {
  let db_path = $"($env.HOME)/chatbot_conversation.db"

  if not ($db_path | path exists) {
    print "No conversation history to clear"
    return
  }

  open $db_path
  | query db "DELETE FROM conversation_history"
  | print "Cleared conversation history"
}

# =============================================================================
# llmcp: generate commit message from git diff and push
# =============================================================================
export def llmcp [
  --dry_run,
  --message: string = "",
  --provider: string = ""
] {
  # Check for staged changes
  let staged = try { ^git diff --staged --stat } catch { null }

  if $staged == null {
    print "No staged changes to commit"
    return
  }

  if $staged == "" {
    print "No staged changes to commit"
    return
  }

  print "Staged changes:"
  print $staged
  print ""

  # Get the full diff
  let diff = ^git diff --staged

  # Generate or use provided commit message
  let commit_msg = if $message == "" {
    print "Generating commit message..."
    let format_hint = "<type>(<scope>): <description>"
    let prompt = $"Generate a concise, conventional git commit message for this diff. Format: ($format_hint)

Diff:
($diff)"
    llm $prompt --provider $provider
  } else {
    $message
  }

  print $"Commit message: ($commit_msg)"
  print ""

  if $dry_run == true {
    print "Dry run - no changes made"
    return
  }

  # Commit
  print "Committing..."
  ^git commit -m $commit_msg

  # Push
  print "Pushing..."
  ^git push

  print "Done!"
}

# =============================================================================
# pancakes - LLM-powered agentic loop for code generation and execution
# =============================================================================
# Generates code via LLM, executes it, and iterates on failure.
# Gives the fallback chain real teeth.

def "pancakes-detect-lang" [code: string] {
  let trimmed = $code | str trim
  let first_line = ($trimmed | split row "\n" | get 0 | str trim)

  # Check for shebang
  if ($trimmed | str starts-with "#!/bin") {
    if ($trimmed | str contains "python") { return "python" }
    return "bash"
  }
  
  # Check for language hint
  if ($first_line == "python") { return "python" }
  if ($first_line == "bash" or $first_line == "sh") { return "bash" }

  # Check patterns
  if ($trimmed | str contains "def ") { return "python" }
  if ($trimmed | str contains "print(") { return "python" }
  if ($trimmed | str contains "echo ") { return "bash" }
  if ($trimmed | str contains "| sort") { return "nu" }
  
  "bash"
}

def "pancakes-gen" [prompt: string, --provider: string = ""] {
  let system = "You are a bash script generator. Output ONLY executable bash code that accomplishes the task. Use real commands like ls, echo, cat. Do NOT use placeholders. No explanation, no markdown."
  let code = llm $prompt --system $system --provider $provider
  
  try { $code | split row '```' | get 1 | str trim } catch { $code | str trim }
}

def "pancakes-exec" [code: string, --interpreter: string = ""] {
  let lang = if $interpreter == "" { pancakes-detect-lang $code } else { $interpreter }
  let path = "/tmp/pancakes_run.sh"
  
  $code | save -f $path
  chmod +x $path
  
  let result = match $lang {
    "nu" => { nu $path | complete }
    "bash" | "sh" => { bash $path | complete }
    "python" => { python $path | complete }
    _ => { bash $path | complete }
  }
  
  rm -f $path
  $result
}

# Main agentic loop
export def pancakes [
  task: string,
  --max_iters: int = 3,
  --provider: string = "",
  --interpreter: string = ""
] {
  let prompt1 = $"Task: ($task). Write a bash script that does this. Use real bash commands like ls, echo, cat."

  print "--- iter 1 ---"
  let code1 = pancakes-gen $prompt1 --provider $provider
  print $code1
  
  let result1 = pancakes-exec $code1 --interpreter $interpreter
  if ($result1.stdout != "") { return $result1.stdout }
  
  if ($max_iters >= 2) {
    print $"error: ($result1.stderr)"
    let prompt2 = $"Task: ($task). Previous error: ($result1.stderr). Fix and regenerate."
    
    print "--- iter 2 ---"
    let code2 = pancakes-gen $prompt2 --provider $provider
    print $code2
    
    let result2 = pancakes-exec $code2 --interpreter $interpreter
    if ($result2.stdout != "") { return $result2.stdout }
    
    print $"error: ($result2.stderr)"
  }
  
  error make {msg: "pancakes failed"}
}
