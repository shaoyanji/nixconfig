export def mget [] {
  let url = "https://mataroa.blog/api/posts/"
  let blob = http get -H ["Authorization" $"Bearer ($env.MATAROA_BEARER_TOKEN)"] ($url)
  let slug =  ($blob)| get post_list
  http get -H ["Authorization" $"Bearer ($env.MATAROA_BEARER_TOKEN)"] $"($url)($slug| get slug | input list)/"
}

export def mpost [] {
  let url = "https://mataroa.blog/api/posts/"
  let title = input "title> "
  let body = gum write
  {title: ($title) body: ($body)}
  | to json
  | http post -H ["Authorization" $"Bearer ($env.MATAROA_BEARER_TOKEN)"] ($url)
}

export def mpublish [] {
  let url = "https://mataroa.blog/api/posts/"
  let blob = http get -H ["Authorization" $"Bearer ($env.MATAROA_BEARER_TOKEN)"] ($url)
  let slug =  ($blob)| get post_list
  let publish = date now | format date "%Y-%m-%d"
  {published_at: ($publish)}
  | to json
  | http patch -H ["Authorization" $"Bearer ($env.MATAROA_BEARER_TOKEN)"] $"($url)($slug | where published_at == null | get slug | input list)/"
}

export def medit [] {
  let url = "https://mataroa.blog/api/posts/"
  let blob = http get -H ["Authorization" $"Bearer ($env.MATAROA_BEARER_TOKEN)"] ($url)
  let slug =  ($blob)| get post_list
  let choice = $slug | get slug | input list
  let selection = ($blob).post_list | where slug == ($choice)
  let title = input -d ($selection | get title | to text) "title> "
  let body = gum write --value ($selection | get body | to text)
  {title: ($title) body: ($body) }
  | to json
  | http patch -H ["Authorization" $"Bearer ($env.MATAROA_BEARER_TOKEN)"] $"($url)($choice)/"
}
