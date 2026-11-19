defmodule KGZeck do
  @excluded ".agents/skills/router/references/playbooks.md"

  def hash(value),
    do: :crypto.hash(:sha256, :erlang.term_to_binary(value)) |> Base.encode16(case: :lower)

  def sha(path), do: :crypto.hash(:sha256, File.read!(path)) |> Base.encode16(case: :lower)

  def terms(0), do: []

  def terms(n) when n > 0 do
    largest =
      Stream.unfold({1, 2}, fn {a, b} -> {a, {b, a + b}} end)
      |> Enum.take_while(&(&1 <= n))
      |> List.last()

    [largest | terms(n - largest)]
  end

  def threshold do
    index = System.get_env("KG_ZECK_EPOCH") || "10"

    case Integer.parse(index) do
      {n, ""} when n >= 2 and n <= 40 ->
        Enum.reduce(2..n, {0, 1}, fn _, {a, b} -> {b, a + b} end) |> elem(1)

      _ ->
        raise "KG_ZECK_EPOCH must be a Fibonacci index between 2 and 40"
    end
  end

  def normalise(path) do
    String.split(path, "/")
    |> Enum.reduce([], fn
      s, acc when s in ["", "."] -> acc
      "..", [] -> []
      "..", acc -> Enum.drop(acc, -1)
      s, acc -> acc ++ [s]
    end)
    |> Enum.join("/")
  end

  def fragment(node, content, graph) do
    tokens = content |> String.split(~r/[^A-Za-z0-9_-]+/, trim: true) |> MapSet.new()

    names = fn type ->
      graph["nodes"]
      |> Enum.filter(&(&1["type"] == type))
      |> Enum.map(& &1["label"])
      |> Enum.filter(&MapSet.member?(tokens, &1))
    end

    doc_paths =
      graph["nodes"]
      |> Enum.filter(&(&1["type"] == "doc"))
      |> Enum.map(& &1["path"])
      |> MapSet.new()

    policy_ids =
      graph["nodes"]
      |> Enum.filter(&(&1["type"] == "policy"))
      |> Enum.map(&String.replace_prefix(&1["id"], "policy:", ""))
      |> MapSet.new()

    citations =
      content
      |> String.split("[[flake/policies.nix#")
      |> Enum.drop(1)
      |> Enum.map(&(String.split(&1, "]]", parts: 2) |> hd()))
      |> Enum.uniq()

    cites =
      Enum.filter(
        citations,
        &(Regex.match?(~r/\A[a-z0-9][a-z0-9-]*\z/, &1) and MapSet.member?(policy_ids, &1))
      )

    references =
      content
      |> String.split("](")
      |> Enum.drop(1)
      |> Enum.map(fn chunk ->
        chunk
        |> String.split(")", parts: 2)
        |> hd()
        |> String.split("#", parts: 2)
        |> hd()
        |> String.replace_prefix("<", "")
        |> String.replace_suffix(">", "")
      end)
      |> Enum.filter(
        &(String.ends_with?(&1, ".md") and
            not Enum.any?(["/", "http", "mailto:"], fn p -> String.starts_with?(&1, p) end))
      )
      |> Enum.map(&normalise(Path.dirname(node["path"]) <> "/" <> &1))
      |> Enum.filter(&(&1 != node["path"] and MapSet.member?(doc_paths, &1)))
      |> Enum.uniq()

    heading = content |> String.split("\n") |> Enum.find(&String.starts_with?(&1, "# "))

    updated =
      Map.merge(node, %{
        "label" => if(heading, do: String.replace_prefix(heading, "# ", ""), else: "(untitled)"),
        "cites" => cites
      })

    edges =
      [
        {"mentions", "host", names.("host")},
        {"mentions", "skill", names.("skill")},
        {"references", "doc", references},
        {"cites", "policy", cites}
      ]
      |> Enum.flat_map(fn {type, prefix, ids} ->
        Enum.map(ids, &%{"from" => node["id"], "to" => prefix <> ":" <> &1, "type" => type})
      end)

    %{"node" => updated, "edges" => edges}
  end

  def eligible(graph),
    do: graph["nodes"] |> Enum.filter(&(&1["type"] == "doc" and &1["path"] != @excluded))

  def git(repo, args) do
    case System.cmd("git", ["-C", repo | args], stderr_to_stdout: true) do
      {out, 0} -> out
      {out, code} -> raise "git exited #{code}: #{out}"
    end
  end

  def core_key(repo, docs) do
    paths = MapSet.new(Map.keys(docs))

    git(repo, ["ls-files", "-s", "-z"])
    |> String.split(<<0>>, trim: true)
    |> Enum.reject(fn entry ->
      MapSet.member?(paths, entry |> String.split("\t", parts: 2) |> List.last())
    end)
    |> Enum.map(fn entry ->
      path = entry |> String.split("\t", parts: 2) |> List.last()
      full = Path.join(repo, path)

      content =
        case File.lstat(full) do
          {:ok, %{type: :regular}} ->
            sha(full)

          {:ok, %{type: :symlink}} ->
            hash(File.read_link!(full))

          {:ok, %{type: :directory}} ->
            if File.exists?(Path.join(full, ".git")) do
              core_key(full, %{})
            else
              "uninitialised gitlink"
            end

          {:error, :enoent} ->
            "deleted"

          other ->
            raise "cannot hash #{path}: #{inspect(other)}"
        end

      {entry, content}
    end)
    |> hash()
  end

  def atomic(path, data) do
    File.mkdir_p!(Path.dirname(path))
    tmp = path <> ".#{System.unique_integer([:positive])}.tmp"
    File.write!(tmp, JSON.encode!(data))
    File.rename!(tmp, path)
  end

  def read(path), do: path |> File.read!() |> JSON.decode!()

  def leap(repo, cache) do
    before = core_key(repo, %{})

    {out, code} =
      System.cmd(
        "bash",
        [
          "-c",
          ~S(. "$1/scripts/task/lib/kg-graph.sh"; cd "$1" && kg_eval_graph),
          "kg-zeck",
          repo
        ],
        stderr_to_stdout: false
      )

    if code != 0, do: raise("full graph evaluation failed (#{code})")
    graph = JSON.decode!(out)
    docs = Map.new(eligible(graph), &{&1["path"], sha(Path.join(repo, &1["path"]))})

    doc_shas =
      graph["nodes"]
      |> Enum.filter(&(&1["type"] == "doc"))
      |> Map.new(&{&1["path"], sha(Path.join(repo, &1["path"]))})

    key = core_key(repo, docs)
    epoch = hash({key, Enum.sort(doc_shas)})

    state = %{
      "epoch" => epoch,
      "core_key" => key,
      "docs" => docs,
      "doc_shas" => doc_shas,
      "log" => []
    }

    if core_key(repo, %{}) != before do
      raise "inputs changed during full graph evaluation; retry"
    end

    atomic(Path.join(cache, "cores/#{epoch}.json"), graph)
    atomic(Path.join(cache, "manifest.json"), state)
    {state, graph}
  end

  def inspect_state(repo, cache) do
    manifest = Path.join(cache, "manifest.json")

    if File.exists?(manifest) do
      state = read(manifest)
      graph = read(Path.join(cache, "cores/#{state["epoch"]}.json"))
      tracked = git(repo, ["ls-files", "-z"]) |> String.split(<<0>>, trim: true) |> MapSet.new()

      current =
        Map.new(state["docs"], fn {path, _} ->
          full = Path.join(repo, path)
          {path, if(File.regular?(full), do: sha(full), else: nil)}
        end)

      dirty = Enum.filter(eligible(graph), &(current[&1["path"]] != state["docs"][&1["path"]]))
      log = Enum.map(state["log"], &%{"path" => &1["path"], "sha" => current[&1["path"]]})
      seen = MapSet.new(log, & &1["path"])

      log =
        log ++
          (dirty
           |> Enum.reject(&MapSet.member?(seen, &1["path"]))
           |> Enum.map(&%{"path" => &1["path"], "sha" => current[&1["path"]]}))

      reason =
        cond do
          Enum.any?(state["docs"], fn {path, _} -> not MapSet.member?(tracked, path) end) ->
            "doc no longer tracked"

          core_key(repo, state["docs"]) != state["core_key"] ->
            "core key changed"

          Enum.any?(current, fn {_, v} -> is_nil(v) end) ->
            "doc deleted"

          length(log) >= threshold() ->
            "epoch threshold"

          Enum.any?(dirty, fn node ->
            previous = Enum.find(state["log"], &(&1["path"] == node["path"]))

            if previous && previous["sha"] == current[node["path"]] do
              false
            else
              content = File.read!(Path.join(repo, node["path"]))

              raw =
                  content
                  |> String.split("[[flake/policies.nix#")
                  |> Enum.drop(1)
                  |> Enum.map(&(String.split(&1, "]]", parts: 2) |> hd()))

              fresh =
                  Enum.filter(raw, &Regex.match?(~r/\A[a-z0-9][a-z0-9-]*\z/, &1))

              MapSet.new(fresh) != MapSet.new(node["cites"])
            end
          end) ->
            "doc citations changed"

          true ->
            nil
        end

      {%{state | "log" => log}, graph, reason}
    else
      {nil, nil, "no epoch"}
    end
  end

  def segments(state) do
    Enum.map_reduce(terms(length(state["log"])), state["log"], fn size, rest ->
      {block, tail} = Enum.split(rest, size)
      key = hash({state["epoch"], block |> Enum.map(&{&1["path"], &1["sha"]}) |> Enum.sort()})
      {{size, key, block}, tail}
    end)
    |> elem(0)
  end

  def merge(graph, fragments) do
    replacements = Map.new(fragments, &{&1["node"]["id"], &1["node"]})

    edges =
      Enum.reject(
        graph["edges"],
        &(Map.has_key?(replacements, &1["from"]) and
            &1["type"] in ["mentions", "references", "cites"])
      ) ++ Enum.flat_map(fragments, & &1["edges"])

    %{
      graph
      | "nodes" => Enum.map(graph["nodes"], &Map.get(replacements, &1["id"], &1)),
        "edges" => edges,
        "stats" => %{
          graph["stats"]
          | "edges" => length(edges),
            "recordedEdges" => Enum.count(edges, &Map.has_key?(&1, "evidence"))
        }
    }
  end

  def graph(repo, cache, force \\ false) do
    {state, core, reason} = inspect_state(repo, cache)
    {state, core} = if force or reason, do: leap(repo, cache), else: {state, core}
    blocks = segments(state)
    quotient = hash({state["epoch"], Enum.map(blocks, &elem(&1, 1))})
    path = Path.join(cache, "graphs/#{quotient}.json")

    unless File.exists?(path) do
      nodes = Map.new(eligible(core), &{&1["path"], &1})

      fragments =
        Enum.flat_map(blocks, fn {_, key, entries} ->
          segment = Path.join(cache, "segments/#{key}.json")

          unless File.exists?(segment) do
            fragments =
              Enum.map(entries, fn entry ->
                fragment(nodes[entry["path"]], File.read!(Path.join(repo, entry["path"])), core)
              end)

            atomic(segment, fragments)
          end

          read(segment)
        end)

      atomic(path, merge(core, fragments))
    end

    atomic(Path.join(cache, "manifest.json"), state)
    path
  end

  def status(repo, cache) do
    {state, _, reason} = inspect_state(repo, cache)

    %{
      "epoch" => state && state["epoch"],
      "n" => if(state, do: length(state["log"]), else: 0),
      "next_leaps" => not is_nil(reason),
      "reason" => reason,
      "segments" =>
        if(state,
          do:
            Enum.map(segments(state), fn {size, key, _} ->
              %{
                "term" => size,
                "hash" => key,
                "cached" => File.exists?(Path.join(cache, "segments/#{key}.json"))
              }
            end),
          else: []
        )
    }
  end

  def locked(cache, fun, attempts \\ 600) do
    File.mkdir_p!(cache)
    lock = Path.join(cache, "lock")

    case File.mkdir(lock) do
      :ok ->
        try do
          fun.()
        after
          File.rmdir!(lock)
        end

      {:error, :eexist} when attempts > 0 ->
        Process.sleep(100)
        locked(cache, fun, attempts - 1)

      other ->
        raise "cache lock unavailable: #{inspect(other)} (remove #{lock} if its writer died)"
    end
  end
end
