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
