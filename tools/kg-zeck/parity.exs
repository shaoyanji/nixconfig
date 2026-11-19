Code.require_file("kg_zeck.exs", __DIR__)

defmodule KGZeckParity do
  def cmd!(command, args, opts \\ []) do
    case System.cmd(command, args, opts) do
      {out, 0} -> out
      {out, code} -> raise "#{command} exited #{code}: #{out}"
    end
  end

  def assert!(true, _), do: :ok
  def assert!(false, message), do: raise(message)

  def sorted(graph),
    do: %{graph | "nodes" => Enum.sort(graph["nodes"]), "edges" => Enum.sort(graph["edges"])}

  def timings(source, repo, root, doc) do
    elixir = System.fetch_env!("KG_ELIXIR")
    opts = [cd: repo, env: [{"REPO", repo}, {"XDG_CACHE_HOME", Path.join(root, "timings")}]]
    zeck = fn -> cmd!(elixir, [Path.join(source, "tools/kg-zeck/cli.exs"), "graph"], opts) end

    baseline = fn ->
      cmd!(
        "bash",
        ["-c", ~S(. "$REPO/scripts/task/lib/kg-graph.sh"; KG_BACKEND= kg_graph_path)],
        opts
      )
    end

    {cold, _} = :timer.tc(zeck)
    baseline.()
    path = Path.join(repo, doc["path"])
    original = File.read!(path)

    try do
      File.write!(path, original <> "\ntiming edit\n")
      {incremental, _} = :timer.tc(zeck)
      {baseline_dirty, _} = :timer.tc(baseline)
      {warm, _} = :timer.tc(zeck)
      {baseline_warm, _} = :timer.tc(baseline)
      show = fn us -> Float.round(us / 1000, 1) end

      IO.puts(
        "timing (one-shot): cold leap #{show.(cold)} ms; incremental #{show.(incremental)} ms; warm #{show.(warm)} ms; HEAD+diff dirty #{show.(baseline_dirty)} ms; HEAD+diff warm #{show.(baseline_warm)} ms"
      )
    after
      File.write!(path, original)
    end
  end

  def compare(repo, cache, label) do
    before =
      if File.exists?(Path.join(cache, "manifest.json")),
        do: KGZeck.status(repo, cache),
        else: nil

    if before && before["next_leaps"], do: IO.puts("leap reason: #{before["reason"]}")

    old =
      Path.wildcard(Path.join(cache, "segments/*.json"))
      |> Map.new(&{&1, Map.take(File.stat!(&1, time: :posix), [:mtime, :ctime, :inode, :size])})

    {ms, path} = :timer.tc(fn -> KGZeck.graph(repo, cache) end)

    fresh =
      cmd!("nix", ["eval", "--impure", "--json", ".#knowledgeGraph.graph"], cd: repo)
      |> JSON.decode!()

    assert!(sorted(KGZeck.read(path)) == sorted(fresh), "graph mismatch: #{label}")

    Enum.each(old, fn {p, stat} ->
      assert!(
        Map.take(File.stat!(p, time: :posix), [:mtime, :ctime, :inode, :size]) == stat,
        "segment rewritten: #{p}"
      )
    end)

    status = KGZeck.status(repo, cache)

    if before && not before["next_leaps"],
      do: assert!(before["epoch"] == status["epoch"], "unexpected leap: #{label}")

    IO.puts(
      "ok    #{label}: n=#{status["n"]} terms=#{inspect(Enum.map(status["segments"], & &1["term"]), charlists: :as_lists)} #{Float.round(ms / 1000, 1)} ms"
    )

    {fresh, status, ms / 1000}
  end

  def run do
    source = System.fetch_env!("REPO")
    base = System.get_env("XDG_CACHE_HOME") || Path.expand("~/.cache")
    root = Path.join(base, "nixconfig/kg-zeck/parity-#{System.unique_integer([:positive])}")
    repo = Path.join(root, "worktree")
    cache = Path.join(root, "cache")
    File.mkdir_p!(root)

    cmd!("git", ["-C", source, "worktree", "add", "--detach", repo, "HEAD"],
      stderr_to_stdout: true
    )

    try do
      patch = KGZeck.git(source, ["diff", "--binary", "HEAD"])

      if patch != "" do
        patchfile = Path.join(root, "changes.patch")
        File.write!(patchfile, patch)
        cmd!("git", ["-C", repo, "apply", "--index", patchfile], stderr_to_stdout: true)
      end

      {graph, initial, cold} = compare(repo, cache, "cold epoch")

      docs =
        KGZeck.eligible(graph)
        |> Enum.filter(&String.starts_with?(&1["path"], "docs/"))
        |> Enum.take(12)

      [host | _] = Enum.filter(graph["nodes"], &(&1["type"] == "host"))
      [skill | _] = Enum.filter(graph["nodes"], &(&1["type"] == "skill"))
      [first | _] = docs
      timings(source, repo, root, first)
      original = File.read!(Path.join(repo, first["path"]))
      text = "\n#{host["label"]} #{skill["label"]} [manual](../MANUAL.md)\n"

      Enum.with_index(docs, 1)
      |> Enum.each(fn {doc, i} ->
        path = Path.join(repo, doc["path"])
        File.write!(path, "# Synthetic heading #{i}\n" <> File.read!(path) <> text)
        {_, status, _} = compare(repo, cache, "doc #{i}")

        assert!(
          status["epoch"] == initial["epoch"] and status["n"] == i,
          "doc edit invalidated core"
        )

        if i == 1 do
          File.write!(path, File.read!(path) <> "\nre-edit\n")
          {_, again, _} = compare(repo, cache, "same doc re-edit")
          assert!(again["n"] == 1, "re-edit appended")
        end
      end)

      File.write!(Path.join(repo, first["path"]), original)
      {_, reverted, incremental} = compare(repo, cache, "doc restored (log position retained)")
      assert!(reverted["n"] == 12, "log shrank")
      {warm_us, _} = :timer.tc(fn -> KGZeck.graph(repo, cache) end)
      File.write!(Path.join(repo, "lib/knowledge-graph.nix"), "\n# parity edit\n", [:append])
      {_, nix_leap, _} = compare(repo, cache, "Nix edit leaps")

      assert!(
        nix_leap["epoch"] != initial["epoch"] and nix_leap["n"] == 0,
        "Nix edit did not leap"
      )

      File.write!(Path.join(repo, "inventory.toml"), "\n# parity edit\n", [:append])
      {_, inventory_leap, _} = compare(repo, cache, "inventory edit leaps")
      assert!(inventory_leap["epoch"] != nix_leap["epoch"], "inventory edit did not leap")

      File.write!(Path.join(repo, "docs/zeck-synthetic.md"), "# Added document\n" <> text)
      cmd!("git", ["-C", repo, "add", "docs/zeck-synthetic.md"])
      {_, added, _} = compare(repo, cache, "added doc leaps")
      assert!(added["epoch"] != inventory_leap["epoch"], "added doc did not leap")
      File.rm!(Path.join(repo, "docs/zeck-synthetic.md"))
      {_, deleted, _} = compare(repo, cache, "deleted doc leaps")
      assert!(deleted["epoch"] != added["epoch"], "deleted doc did not leap")
      cite_doc = Enum.find(KGZeck.eligible(graph), &(&1["cites"] != []))
      path = Path.join(repo, cite_doc["path"])
      File.write!(path, String.replace(File.read!(path), "[[flake/policies.nix#", "[[removed#"))
      {_, cited, _} = compare(repo, cache, "citation change leaps")
      assert!(cited["epoch"] != deleted["epoch"], "citation edit did not leap")
      System.put_env("KG_ZECK_EPOCH", "2")
      path = Path.join(repo, first["path"])
      File.write!(path, File.read!(path) <> "\nthreshold\n")
      {_, threshold, _} = compare(repo, cache, "threshold leaps")

      assert!(
        threshold["epoch"] != cited["epoch"] and threshold["n"] == 0,
        "threshold did not leap"
      )

      IO.puts(
        "timing (in-process): cold leap #{Float.round(cold, 1)} ms; incremental #{Float.round(incremental, 1)} ms; warm #{Float.round(warm_us / 1000, 1)} ms"
      )

      IO.puts("PASS  kg-zeck parity, append-only log, immutable segments and epoch leaps")
    after
      cmd!("git", ["-C", source, "worktree", "remove", "--force", repo], stderr_to_stdout: true)
      File.rm_rf!(root)
    end
  end
end

KGZeckParity.run()
