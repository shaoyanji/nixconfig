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
    model: "minimaxai/minimax-m2.7"
    models: ["minimaxai/minimax-m2.7", "nvidia/llama-3.3-nemotron-super-48b-instruct", "google/gemma-2-27b-it"]
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
  let key_val = $env | get $key_name
  if $key_val == null {
    error make {
      msg: $"($key_name) environment variable is not set"
      label: {text: $"Set $\($key_name) in your environment"}
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
  # Check for API errors first
  let has_err = try { $response | get error } catch { null }
  if $has_err != null {
    error make {
      msg: $"API error: ($has_err.message)"
      label: {text: "($has_err.code)"}
    }
  }

  # Verify response has choices field (some APIs return error in different format)
  let has_choices = try { $response | get choices } catch { null }
  if $has_choices == null {
    print $"Unexpected LLM response: ($response | to json)"
    error make {
      msg: $"API response missing 'choices' field. Response may be an error or rate limit."
      label: {text: "Unexpected response format"}
    }
  }

  # Handle OpenAI-style response
  try {
    $response | get choices.0.message.content
  } catch {
    # Log the actual response for debugging
    let debug_msg = $"LLM response parse failed. Response: ($response | to json)"
    print $debug_msg
    error make {
      msg: $"Failed to parse chat response. Check debug output for full response."
      label: {text: "Failed to parse chat response"}
    }
  }
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

  $body | to json | curl -sS -X POST $url -H $"x-goog-api-key: ($key)" -H "Content-Type: application/json" -d ($in) | from json | get candidates.0.content.parts.text.0
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

  let body = {
    model: $m
    messages: $messages
    temperature: $temperature
    max_tokens: $max_tokens
  }

  $body | to json -r | curl -sS -X POST $p.url -H "Content-Type: application/json" -H $"Authorization: Bearer ($key)" -d ($in) | from json | get choices.0.message.content
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
      label: {text: "Start ollama with: ollama serve"}
    }
  }

  let messages = if $system == "" {
    [{role: "user", content: $message}]
  } else {
    [{role: "system", content: $system}, {role: "user", content: $message}]
  }

  let prompt = (
    $messages
    | fold -s {role, content} | each { |m| $"($m.role): ($m.content)" }
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

  let body = {
    model: $m
    messages: $messages
    temperature: $temperature
    max_tokens: $max_tokens
  }

  $body | to json -r | curl -sS -X POST $p.url -H "Content-Type: application/json" -H $"Authorization: Bearer ($key)" -d ($in) | from json | get choices.0.message.content
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
      _ => { error make {msg: $"Unknown provider: ($provider)", label: {text: "Use groq, cohere, openrouter, nvidia, gemini, ollama, or aihubmix"}}}
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
    } catch {
      print $"($p.name): ($in)"
    }
  }

  error make {
    msg: "All LLM providers failed"
    label: {text: "Fallback chain exhausted"}
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
  let response = main $uinput

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
    main $prompt --provider $provider
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
  let code = main $prompt --system $system --provider $provider
  
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
  
  error make {msg: "pancakes failed", label: {text: "max iterations"}}
}
