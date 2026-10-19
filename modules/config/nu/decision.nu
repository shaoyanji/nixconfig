# =============================================================================
# decision.nu — decision models (TypeSafe Jev, local Julia-1 / Laya)
#
# A decision model is not a chat model: one forward pass returns a calibrated
# choice, probability or score, with no generated text. The wire shape is the
# System One spec:
#
#   POST https://api.typesafe.ai/v1/systemone
#   {
#     model: "jev-latest"
#     state: {...}
#     questions: {
#       q1: {type: "choice", instructions: "...", criteria: {key: "description"}}
#     }
#   }
#
# Responses:
#   choice  answers.q1.{choice, probabilities, confidence}
#   noul    answers.q1.noul                      (yes/no probability)
#   score   answers.q1.{score, confidence, legend, probabilities}
#
# Providers:
#   typesafe  TypeSafe Jev (cloud, TYPESAFE_API_KEY, best accuracy — 0.966 macro)
#   local     `systemone-decision` from services.systemoneDecision (julia-1 or
#             laya, CPU, no key, weaker — 0.583 macro for laya)
#   auto      typesafe first, then local (laya)
#
# Caveat on `local`: the in-repo CLI scores options by lexical overlap (hash
# embeddings + softmax), it is not the 421M checkpoint. Treat its confidence as
# low signal — it is an offline fallback and a smoke test, not a Jev stand-in.
#
# A decision is a signal, not an authorisation: never let one gate a
# destructive action on its own. See `.agents/skills/decision-picker/SKILL.md`.
# =============================================================================

const DECISION_ENDPOINT = "https://api.typesafe.ai/v1/systemone"
const DECISION_MODEL = "jev-latest"
const DECISION_LOCAL_MODEL = "laya"

def "decision-key" [] {
  let k = ($env | get -o TYPESAFE_API_KEY)
  if ($k | is-empty) {
    error make {
      msg: "TYPESAFE_API_KEY is not set"
    }
  }
  $k
}

def "decision-post" [payload: record] {
  let body = ($payload | to json)
  # nushell has no `\` line continuation — backslashes are passed to curl as
  # arguments (curl exit 3, malformed URL). Splat a list instead.
  let args = [
    -sS
    --connect-timeout 8
    --max-time 30
    -X POST $DECISION_ENDPOINT
    -H $"Authorization: Bearer (decision-key)"
    -H "Content-Type: application/json"
    -d $body
  ]
  let out = (^curl ...$args | complete)
  if $out.exit_code != 0 {
    error make {
      msg: $"TypeSafe request failed (exit ($out.exit_code)): ($out.stderr | str trim)"
    }
  }
  let resp = ($out.stdout | from json)
  # FastAPI validation errors arrive as `detail`; a silent empty answers object
  # would be indistinguishable from a confident answer, so fail loudly.
  if ($resp | get -o detail) != null {
    error make {
      msg: $"TypeSafe rejected the request: ($resp.detail | to json)"
    }
  }
  let q = ($resp | get -o answers.q1)
  if $q == null {
    error make {
      msg: $"TypeSafe returned no answers: ($resp | to json)"
    }
  }
  {model: ($resp | get -o model | default $DECISION_MODEL), answer: $q}
}

def "decision-local" [
  qtype: string
  instructions: string
  state: record
  model: string
  options: list
] {
  let bin = (which systemone-decision | get -o 0 | get -o path)
  if $bin == null {
    error make {
      msg: "systemone-decision is not installed on this host"
    }
  }
  let base = [
    --model
    $model
    query
    --type
    $qtype
    --state
    ($state | to json)
    --prompt
    $instructions
  ]
  let args = if ($options | is-empty) { $base } else { $base ++ [--options] ++ $options }
  let out = (^systemone-decision ...$args | complete)
  if $out.exit_code != 0 {
    error make {
      msg: $"systemone-decision failed: ($out.stderr | str trim)"
    }
  }
  ($out.stdout | from json)
}

# -----------------------------------------------------------------------------
# choice: pick one of N options
# -----------------------------------------------------------------------------

export def "decide jev" [
  instructions: string
  --options: list = []
  --state: record = {}
  --model: string = $DECISION_MODEL
] {
  let criteria = ($options | reduce -f {} { |o, acc| $acc | merge {($o): $o} })
  let payload = {
    model: $model
    state: $state
    questions: {
      q1: {
        type: "choice"
        instructions: $instructions
        criteria: $criteria
      }
    }
  }
  let r = (decision-post $payload)
  {
    provider: "typesafe"
    model: $r.model
    choice: $r.answer.choice
    confidence: $r.answer.confidence
    probabilities: $r.answer.probabilities
  }
}

export def "decide local" [
  instructions: string
  --options: list = []
  --state: record = {}
  --model: string = $DECISION_LOCAL_MODEL
] {
  let r = (decision-local "choice" $instructions $state $model $options)
  {
    provider: "local"
    model: $r.model
    choice: $r.decision
    confidence: $r.confidence
    probabilities: $r.probabilities
  }
}

# -----------------------------------------------------------------------------
# yes/no (noul): a calibrated probability that a condition holds
# -----------------------------------------------------------------------------

export def "decide yes jev" [
  condition: string
  --state: record = {}
  --model: string = $DECISION_MODEL
] {
  let payload = {
    model: $model
    state: $state
    questions: {q1: {type: "noul", instructions: $condition}}
  }
  let r = (decision-post $payload)
  {
    provider: "typesafe"
    model: $r.model
    probability: $r.answer.noul
    holds: ($r.answer.noul >= 0.5)
  }
}

export def "decide yes local" [
  condition: string
  --state: record = {}
  --model: string = $DECISION_LOCAL_MODEL
] {
  let r = (decision-local "noul" $condition $state $model [])
  {
    provider: "local"
    model: $r.model
    probability: $r.probability_true
    holds: $r.holds
  }
}

# -----------------------------------------------------------------------------
# score: rate a state on an ordered scale
# -----------------------------------------------------------------------------

export def "decide score jev" [
  instructions: string
  --criteria: list
  --state: record = {}
  --model: string = $DECISION_MODEL
] {
  if ($criteria | is-empty) {
    error make {msg: "decide score needs --criteria (ordered list, lowest first)"}
  }
  let payload = {
    model: $model
    state: $state
    questions: {
      q1: {
        type: "score"
        instructions: $instructions
        criteria: $criteria
      }
    }
  }
  let r = (decision-post $payload)
  {
    provider: "typesafe"
    model: $r.model
    score: $r.answer.score
    confidence: $r.answer.confidence
    legend: $r.answer.legend
    probabilities: $r.answer.probabilities
  }
}

export def "decide score local" [
  instructions: string
  --criteria: list = []
  --state: record = {}
  --model: string = $DECISION_LOCAL_MODEL
] {
  # The CLI takes one criteria string, not a list. Fold the ordered scale into
  # the prompt so `decide score --criteria [...]` does not silently drop it.
  let prompt = if ($criteria | is-empty) {
    $instructions
  } else {
    $"($instructions) Score from lowest to highest: ($criteria | str join ', ')"
  }
  let r = (decision-local "score" $prompt $state $model [])
  {
    provider: "local"
    model: $r.model
    score: $r.score
    confidence: $r.confidence
  }
}

# -----------------------------------------------------------------------------
# dispatchers: `decide` (choice), `decide yes` and `decide score`, defaulting to
# Jev and falling back to the local model
# -----------------------------------------------------------------------------

export def decide [
  instructions: string
  --options: list = []
  --state: record = {}
  --provider: string = "auto"
  --model: string = ""
] {
  match $provider {
    "typesafe" => { decide jev $instructions --options $options --state $state --model (if $model == "" { $DECISION_MODEL } else { $model }) }
    "local" => { decide local $instructions --options $options --state $state --model (if $model == "" { $DECISION_LOCAL_MODEL } else { $model }) }
    "auto" => {
      try {
        return (decide jev $instructions --options $options --state $state --model (if $model == "" { $DECISION_MODEL } else { $model }))
      } catch { |e|
        print -e $"typesafe: ($e.msg)"
      }
      decide local $instructions --options $options --state $state --model (if $model == "" { $DECISION_LOCAL_MODEL } else { $model })
    }
    _ => {error make {msg: $"Unknown decision provider: ($provider)"}}
  }
}

export def "decide yes" [
  condition: string
  --state: record = {}
  --provider: string = "auto"
  --model: string = ""
] {
  match $provider {
    "typesafe" => { decide yes jev $condition --state $state --model (if $model == "" { $DECISION_MODEL } else { $model }) }
    "local" => { decide yes local $condition --state $state --model (if $model == "" { $DECISION_LOCAL_MODEL } else { $model }) }
    "auto" => {
      try {
        return (decide yes jev $condition --state $state --model (if $model == "" { $DECISION_MODEL } else { $model }))
      } catch { |e|
        print -e $"typesafe: ($e.msg)"
      }
      decide yes local $condition --state $state --model (if $model == "" { $DECISION_LOCAL_MODEL } else { $model })
    }
    _ => {error make {msg: $"Unknown decision provider: ($provider)"}}
  }
}

export def "decide score" [
  instructions: string
  --criteria: list = []
  --state: record = {}
  --provider: string = "auto"
  --model: string = ""
] {
  match $provider {
    "typesafe" => { decide score jev $instructions --criteria $criteria --state $state --model (if $model == "" { $DECISION_MODEL } else { $model }) }
    "local" => { decide score local $instructions --criteria $criteria --state $state --model (if $model == "" { $DECISION_LOCAL_MODEL } else { $model }) }
    "auto" => {
      try {
        return (decide score jev $instructions --criteria $criteria --state $state --model (if $model == "" { $DECISION_MODEL } else { $model }))
      } catch { |e|
        print -e $"typesafe: ($e.msg)"
      }
      decide score local $instructions --criteria $criteria --state $state --model (if $model == "" { $DECISION_LOCAL_MODEL } else { $model })
    }
    _ => {error make {msg: $"Unknown decision provider: ($provider)"}}
  }
}

# -----------------------------------------------------------------------------
# discovery
# -----------------------------------------------------------------------------

export def "decide models" [] {
  let local = (which systemone-decision | get -o 0 | get -o path | default "-")
  let key = (if ($env | get -o TYPESAFE_API_KEY | is-empty) { "missing" } else { "set" })
  [
    {provider: typesafe, model: $DECISION_MODEL, where: "api.typesafe.ai", ready: $key, accuracy: "0.966 macro", notes: "cloud, default"}
    {provider: local, model: julia-1, where: $local, ready: (if $local == "-" { "missing" } else { "ok" }), accuracy: "144M params", notes: "CPU, no key, lexical scorer"}
    {provider: local, model: laya, where: $local, ready: (if $local == "-" { "missing" } else { "ok" }), accuracy: "0.583 macro", notes: "CPU, auto fallback"}
  ]
}
