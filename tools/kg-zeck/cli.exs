Code.require_file("kg_zeck.exs", __DIR__)

try do
  repo = System.get_env("REPO") || File.cwd!()
  root = System.get_env("XDG_CACHE_HOME") || Path.expand("~/.cache")
  cache = Path.join(root, "nixconfig/kg-zeck/" <> KGZeck.hash(Path.expand(repo)))

  KGZeck.locked(cache, fn ->
    case System.argv() do
      ["graph"] -> IO.puts(KGZeck.graph(repo, cache))
      ["leap"] -> IO.puts(KGZeck.graph(repo, cache, true))
      ["status"] -> IO.puts(JSON.encode!(KGZeck.status(repo, cache)))
      _ -> raise "usage: kg-zeck graph|status|leap"
    end
  end)
rescue
  e ->
    IO.puts(:stderr, "kg-zeck: " <> Exception.message(e))
    System.halt(1)
end
