def "todoist get" [] {
  let url = "https://api.todoist.com/api/v1/tasks"
  let blob = http get -H ["Authorization" $"Bearer ($env.TODOIST_API_TOKEN)"] ($url)
  let tasks = ($blob | get results)
  let choice = ($tasks | input list)
  $choice
}

def "todoist post" [] {
  let url = "https://api.todoist.com/api/v1/tasks"
  let content = input "content> "
  let description = input "description> "
  let project = input "project_id (default Inbox)> "
  let labels = input "labels (comma-separated)> "
  let due_string = input "due string (e.g. tomorrow, 2026-04-15)> "

  let body = {content: ($content)}
  let body = if ($description | is-empty) { $body } else { $body | merge {description: ($description)} }
  let body = if ($project | is-empty) { $body } else { $body | merge {project_id: ($project)} }
  let body = if ($labels | is-empty) { $body } else { $body | merge {labels: ($labels | split row "," | str trim)} }
  let body = if ($due_string | is-empty) { $body } else { $body | merge {due_string: ($due_string)} }

  $body
  | to json -r
  | http post -H ["Authorization" $"Bearer ($env.TODOIST_API_TOKEN)"] -H ["Content-Type: application/json"] ($url)
}

def "todoist complete" [] {
  let url = "https://api.todoist.com/api/v1/tasks"
  let sync_url = "https://api.todoist.com/api/v1/sync"
  let blob = http get -H ["Authorization" $"Bearer ($env.TODOIST_API_TOKEN)"] ($url)
  let tasks = ($blob | get results)
  let choice = ($tasks | input list)
  let task_id = ($choice | get id)

  let cmd = {
    type: "item_close"
    uuid: (date now | format date "%Y%m%d%H%M%S%3f" | hash md5)
    args: {id: ($task_id)}
  }

  {sync_token: "*" commands: [$cmd]}
  | to json -r
  | http post -H ["Authorization" $"Bearer ($env.TODOIST_API_TOKEN)"] -H ["Content-Type: application/json"] ($sync_url)
  | ignore

  print $"Task ($task_id) completed."
}

def "todoist edit" [] {
  let url = "https://api.todoist.com/api/v1/tasks"
  let sync_url = "https://api.todoist.com/api/v1/sync"
  let blob = http get -H ["Authorization" $"Bearer ($env.TODOIST_API_TOKEN)"] ($url)
  let tasks = ($blob | get results)
  let choice = ($tasks | input list)
  let task_id = ($choice | get id)

  let content = input -d ($choice | get content | default "") "content> "
  let description = input -d ($choice | get description? | default "") "description> "
  let due_string = input -d (($choice | get due | default {} | get string?) | default "") "due string> "

  let args = {id: ($task_id)}
  let args = if ($content | is-empty) { $args } else { $args | merge {content: ($content)} }
  let args = if ($description | is-empty) { $args } else { $args | merge {description: ($description)} }
  let args = if ($due_string | is-empty) { $args } else { $args | merge {due_string: ($due_string)} }

  if (($args | columns | length) == 1) {
    print "No changes made."
    return
  }

  let cmd = {
    type: "item_update"
    uuid: (date now | format date "%Y%m%d%H%M%S%3f" | hash md5)
    args: ($args)
  }

  {sync_token: "*" commands: [$cmd]}
  | to json -r
  | http post -H ["Authorization" $"Bearer ($env.TODOIST_API_TOKEN)"] -H ["Content-Type: application/json"] ($sync_url)
  | ignore

  print $"Task ($task_id) updated."
}

def "todoist delete" [] {
  let url = "https://api.todoist.com/api/v1/tasks"
  let blob = http get -H ["Authorization" $"Bearer ($env.TODOIST_API_TOKEN)"] ($url)
  let tasks = ($blob | get results)
  let choice = ($tasks | input list)
  let task_id = ($choice | get id)

  http delete -H ["Authorization" $"Bearer ($env.TODOIST_API_TOKEN)"] $"($url)/($task_id)"
  print $"Task ($task_id) deleted."
}
