ExUnit.start()
Code.require_file("kg_zeck.exs", __DIR__)

defmodule KGZeckTest do
  use ExUnit.Case

  def fixture do
    %{
      "nodes" => [
        %{"id" => "host:z", "type" => "host", "label" => "z"},
        %{"id" => "host:a", "type" => "host", "label" => "a"},
        %{"id" => "skill:nix-eval", "type" => "skill", "label" => "nix-eval"},
        %{
          "id" => "doc:docs/a.md",
          "type" => "doc",
          "path" => "docs/a.md",
          "label" => "old",
          "cites" => []
        },
        %{"id" => "doc:b.md", "type" => "doc", "path" => "b.md", "label" => "B", "cites" => []},
        %{"id" => "policy:real", "type" => "policy", "label" => "real"}
      ],
      "edges" => [],
      "stats" => %{"edges" => 0, "recordedEdges" => 0}
    }
  end

  def repo_fixture do
    root = Path.join(System.tmp_dir!(), "kg-zeck-repo-#{System.unique_integer([:positive])}")
    repo = Path.join(root, "repo")
    cache = Path.join(root, "cache")
    File.mkdir_p!(Path.join(repo, "scripts/task/lib"))
    File.mkdir_p!(Path.join(repo, "docs"))
    on_exit(fn -> File.rm_rf!(root) end)
    File.write!(Path.join(repo, "docs/a.md"), "# old\n[[flake/policies.nix#real]]\n")
    File.write!(Path.join(repo, "b.md"), "# B\n")
    File.write!(Path.join(repo, "core.nix"), "before")
    elixir = System.get_env("KG_ELIXIR") || System.find_executable("elixir")

    File.write!(
      Path.join(repo, "scripts/task/lib/kg-graph.sh"),
      "kg_eval_graph() { '#{elixir}' eval.exs; }\n"
    )

    File.write!(Path.join(repo, "eval.exs"), """
    graph = JSON.decode!(#{inspect(JSON.encode!(fixture()))})
    {tracked, 0} = System.cmd("git", ["ls-files", "docs/a.md"])
    content = File.read!("docs/a.md")
    cites = if tracked != "" and String.contains?(content, "[[flake/policies.nix#real]]"), do: ["real"], else: []
    nodes = Enum.flat_map(graph["nodes"], fn node ->
      cond do
        node["id"] == "doc:docs/a.md" and tracked == "" -> []
        node["id"] == "doc:docs/a.md" -> [Map.merge(node, %{"cites" => cites, "label" => content |> String.split("\\n") |> hd() |> String.replace_prefix("# ", "")})]
        node["type"] == "policy" and cites == [] -> []
        true -> [node]
      end
    end)
    edges = Enum.map(cites, &%{"from" => "doc:docs/a.md", "to" => "policy:" <> &1, "type" => "cites"})
    graph = %{graph | "nodes" => nodes, "edges" => edges, "stats" => %{"edges" => length(edges), "recordedEdges" => 0}}
    if File.exists?(".edit-on-eval") do
      [target, value] = ".edit-on-eval" |> File.read!() |> JSON.decode!()
      File.write!(target, value)
      File.rm!(".edit-on-eval")
    end
    IO.puts(JSON.encode!(graph))
    """)

    KGZeck.git(repo, ["init", "-q"])
    KGZeck.git(repo, ["add", "."])
    {repo, cache}
  end

  test "restoring a policy's last citation restores its node and edge" do
    {repo, cache} = repo_fixture()
    KGZeck.graph(repo, cache)
    path = Path.join(repo, "docs/a.md")
    original = File.read!(path)
    File.write!(path, "# old\n")
    removed = KGZeck.graph(repo, cache) |> KGZeck.read()
    refute Enum.any?(removed["nodes"], &(&1["id"] == "policy:real"))
    File.write!(path, original)
    restored = KGZeck.graph(repo, cache) |> KGZeck.read()
    assert Enum.any?(restored["nodes"], &(&1["id"] == "policy:real"))
    assert Enum.any?(restored["edges"], &(&1["type"] == "cites" and &1["to"] == "policy:real"))
  end

  test "a doc edit during full evaluation cannot persist an old graph under new hashes" do
    {repo, cache} = repo_fixture()

    File.write!(
      Path.join(repo, ".edit-on-eval"),
      JSON.encode!(["docs/a.md", "# concurrent\n[[flake/policies.nix#real]]\n"])
    )

    assert_raise RuntimeError, ~r/inputs changed during full graph evaluation/, fn ->
      KGZeck.graph(repo, cache)
    end

    refute File.exists?(Path.join(cache, "manifest.json"))
    graph = KGZeck.graph(repo, cache) |> KGZeck.read()
    assert Enum.find(graph["nodes"], &(&1["id"] == "doc:docs/a.md"))["label"] == "concurrent"
  end

  test "a core edit during evaluation leaves the previous epoch untouched" do
    {repo, cache} = repo_fixture()
    KGZeck.graph(repo, cache)
    manifest = File.read!(Path.join(cache, "manifest.json"))
    File.write!(Path.join(repo, ".edit-on-eval"), JSON.encode!(["core.nix", "concurrent"]))

    assert_raise RuntimeError, ~r/inputs changed during full graph evaluation/, fn ->
      KGZeck.graph(repo, cache, true)
    end

    assert File.read!(Path.join(cache, "manifest.json")) == manifest
    assert KGZeck.status(repo, cache)["next_leaps"]
    KGZeck.graph(repo, cache)
    refute KGZeck.status(repo, cache)["next_leaps"]
  end

  test "removing a doc from the index removes its cached node even when the file remains" do
    {repo, cache} = repo_fixture()
    KGZeck.graph(repo, cache)
    KGZeck.git(repo, ["rm", "--cached", "docs/a.md"])
    assert File.regular?(Path.join(repo, "docs/a.md"))
    graph = KGZeck.graph(repo, cache) |> KGZeck.read()
    refute Enum.any?(graph["nodes"], &(&1["id"] == "doc:docs/a.md"))
    refute Enum.any?(graph["edges"], &(&1["from"] == "doc:docs/a.md"))
  end

  test "a terminated VM does not leave the cache locked" do
    {_repo, cache} = repo_fixture()
    script = "KGZeck.locked(#{inspect(cache)}, fn -> System.halt(0) end)"

    {_, 0} =
      System.cmd(System.find_executable("elixir"), [
        "-r",
        Path.join(__DIR__, "kg_zeck.exs"),
        "-e",
        script
      ])

    assert KGZeck.locked(cache, fn -> :recovered end, 10) == :recovered
  end

  test "a live lock cannot be stolen and exceptions release it" do
    {_repo, cache} = repo_fixture()

    assert_raise RuntimeError, "callback failed", fn ->
      KGZeck.locked(cache, fn ->
        assert_raise RuntimeError, ~r/cache lock unavailable/, fn ->
          KGZeck.locked(cache, fn -> flunk("stole a live lock") end, 0)
        end

        raise "callback failed"
      end)
    end

    assert KGZeck.locked(cache, fn -> :released end) == :released
  end

  test "greedy terms have non-adjacent Fibonacci indexes and sum to n" do
    fibs = [1, 2, 3, 5, 8, 13, 21, 34, 55, 89]

    for n <- 0..100 do
      terms = KGZeck.terms(n)
      assert Enum.sum(terms) == n
      indexes = Enum.map(terms, &Enum.find_index(fibs, fn f -> f == &1 end))
      assert Enum.all?(Enum.chunk_every(indexes, 2, 1, :discard), fn [a, b] -> a - b > 1 end)
    end

    assert KGZeck.terms(12) == [8, 3, 1]
  end

  test "fragment matches tokens, heading, ordered vocabulary, links and policy syntax" do
    graph = fixture()
    node = Enum.at(graph["nodes"], 3)

    content =
      "## not first\n# Title  \na z nix-eval nix-eval-extra az\n[x](../b.md#h) [x](<../b.md>) [s](./a.md) [e](https://x/b.md) [r](/b.md)\n[[flake/policies.nix#real]] [[flake/policies.nix#unknown]] [[flake/policies.nix#BAD]]"

    fragment = KGZeck.fragment(node, content, graph)
    assert fragment["node"]["label"] == "Title  "
    assert fragment["node"]["cites"] == ["real"]

    assert Enum.map(fragment["edges"], & &1["to"]) == [
             "host:z",
             "host:a",
             "skill:nix-eval",
             "doc:b.md",
             "policy:real"
           ]
  end

  test "empty fragment removes old edges and preserves other edge types and statistics" do
    graph = fixture()
    node = Enum.at(graph["nodes"], 3)
    fragment = KGZeck.fragment(node, "", graph)
    assert fragment["node"]["label"] == "(untitled)"
    assert fragment["edges"] == []

    recorded = %{
      "from" => node["id"],
      "to" => "doc:b.md",
      "type" => "derives",
      "evidence" => "asserted"
    }

    graph = %{
      graph
      | "edges" => [recorded, %{"from" => node["id"], "to" => "host:a", "type" => "mentions"}]
    }

    merged = KGZeck.merge(graph, [fragment])
    assert merged["edges"] == [recorded]
    assert merged["stats"] == %{"edges" => 1, "recordedEdges" => 1}
  end

  test "segments reuse oldest block on append and key changes only affected blocks" do
    entries = Enum.map(1..11, &%{"path" => "#{&1}.md", "sha" => "sha"})
    state = %{"epoch" => "epoch", "log" => entries}
    [{8, hash, _} | _] = KGZeck.segments(state)

    assert [{8, ^hash, _}, {3, _, _}, {1, _, _}] =
             KGZeck.segments(%{
               state
               | "log" => entries ++ [%{"path" => "12.md", "sha" => "sha"}]
             })

    [first | rest] = entries

    refute KGZeck.segments(state) ==
             KGZeck.segments(%{state | "log" => [%{first | "sha" => "changed"} | rest]})
  end

  test "invalid threshold and missing input fail explicitly" do
    System.put_env("KG_ZECK_EPOCH", "bad")

    try do
      assert_raise RuntimeError, ~r/Fibonacci index/, &KGZeck.threshold/0
    after
      System.delete_env("KG_ZECK_EPOCH")
    end

    assert KGZeck.threshold() == 55
    assert_raise File.Error, fn -> KGZeck.sha("/nonexistent/kg-zeck-file") end
  end

  test "uninitialised gitlinks do not hash parent worktree dirtiness" do
    root = Path.join(System.tmp_dir!(), "kg-zeck-test-#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(root, "submodule"))

    try do
      KGZeck.git(root, ["init", "-q"])
      File.write!(Path.join(root, "doc.md"), "before")
      File.write!(Path.join(root, "core.nix"), "before")
      KGZeck.git(root, ["add", "doc.md", "core.nix"])

      KGZeck.git(root, [
        "update-index",
        "--add",
        "--cacheinfo",
        "160000,1111111111111111111111111111111111111111,submodule"
      ])

      docs = %{"doc.md" => "sha"}
      key = KGZeck.core_key(root, docs)
      File.write!(Path.join(root, "doc.md"), "edited")
      assert KGZeck.core_key(root, docs) == key
      File.write!(Path.join(root, "core.nix"), "edited")
      refute KGZeck.core_key(root, docs) == key
    after
      File.rm_rf!(root)
    end
  end
end
