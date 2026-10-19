# ==============================================================================
# tools/kg-engine/kg_engine.exs — High-Performance Reactive Knowledge Graph Engine
# ==============================================================================
# In-memory ETS property graph engine with zero-overhead UNIX domain socket IPC.
# Built with pure native Elixir 1.18 + Erlang/OTP 28 (zero external dependencies).
#
# Provides sub-millisecond agent traversals (< 0.5 ms):
#   - GET /stats                          -> graph node & edge metrics
#   - GET /node?id=<id>                   -> 1-hop inbound & outbound neighborhood
#   - GET /neighbors?id=<id>&depth=2      -> N-hop BFS subgraph extraction
#   - GET /blast-radius?id=<id>           -> Transitive dependency & impact analysis
#   - GET /query?q=<term>                 -> Substring entity search
# ==============================================================================

defmodule KGEngine.Store do
  @moduledoc """
  Lock-free in-memory graph store backed by Erlang Term Storage (ETS).
  """

  @nodes_table :kg_nodes
  @edges_out :kg_edges_out
  @edges_in :kg_edges_in

  def init do
    if :ets.info(@nodes_table) == :undefined do
      :ets.new(@nodes_table, [:set, :public, :named_table, read_concurrency: true])
      :ets.new(@edges_out, [:duplicate_bag, :public, :named_table, read_concurrency: true])
      :ets.new(@edges_in, [:duplicate_bag, :public, :named_table, read_concurrency: true])
    end
    :ok
  end

  def clear do
    :ets.delete_all_objects(@nodes_table)
    :ets.delete_all_objects(@edges_out)
    :ets.delete_all_objects(@edges_in)
    :ok
  end

  def load_data(%{"nodes" => nodes, "edges" => edges} = data) do
    clear()

    # Bulk insert nodes
    Enum.each(nodes, fn node ->
      id = node["id"] || node[:id]
      type = node["type"] || node[:type] || "unknown"
      label = node["label"] || node[:label] || id

      # Normalize properties
      props = Map.new(node, fn {k, v} -> {to_string(k), v} end)
      :ets.insert(@nodes_table, {id, type, label, props})
    end)

    # Bulk insert edges
    Enum.each(edges, fn edge ->
      from = edge["from"] || edge[:from] || edge["source"] || edge[:source]
      to = edge["to"] || edge[:to] || edge["target"] || edge[:target]
      type = edge["type"] || edge[:type] || edge["relation"] || edge[:relation] || "mentions"

      if from && to do
        :ets.insert(@edges_out, {from, to, type})
        :ets.insert(@edges_in, {to, from, type})
      end
    end)

    node_count = :ets.info(@nodes_table, :size)
    edge_count = :ets.info(@edges_out, :size)

    # Type counts are a property of the LOAD, not of the call: recomputing them
    # meant tab2list + group_by over every node on each /stats (0.4-0.6 ms, and
    # it made the health endpoint slower than the queries it reports on).
    types =
      :ets.tab2list(@nodes_table)
      |> Enum.group_by(fn {_, type, _, _} -> type end)
      |> Map.new(fn {type, list} -> {type, length(list)} end)

    :persistent_term.put({__MODULE__, :type_counts}, types)
    {:ok, %{nodes: node_count, edges: edge_count, source_stats: data["stats"] || %{}}}
  end

  def stats do
    nodes_count = :ets.info(@nodes_table, :size)
    edges_count = :ets.info(@edges_out, :size)
    types = :persistent_term.get({__MODULE__, :type_counts}, %{})

    %{
      nodes: nodes_count,
      edges: edges_count,
      node_types: types,
      status: "operational",
      source: :persistent_term.get({__MODULE__, :source}, "unknown"),
      engine: "Elixir/OTP 28 ETS"
    }
  end

  def exists?(id), do: :ets.member(@nodes_table, id)

  def get_node(id) do
    case :ets.lookup(@nodes_table, id) do
      [{^id, type, label, props}] ->
        outbound =
          :ets.lookup(@edges_out, id)
          |> Enum.map(fn {_, to, rel} -> %{target: to, relation: rel} end)

        inbound =
          :ets.lookup(@edges_in, id)
          |> Enum.map(fn {_, from, rel} -> %{source: from, relation: rel} end)

        %{
          id: id,
          type: type,
          label: label,
          properties: props,
          outbound_count: length(outbound),
          inbound_count: length(inbound),
          outbound: outbound,
          inbound: inbound
        }

      [] ->
        nil
    end
  end

  def query(term) do
    q = String.downcase(term)

    :ets.tab2list(@nodes_table)
    |> Enum.filter(fn {id, type, label, _} ->
      String.contains?(String.downcase(id), q) or
        String.contains?(String.downcase(label), q) or
        String.contains?(String.downcase(type), q)
    end)
    |> Enum.take(50)
    |> Enum.map(fn {id, type, label, props} ->
      %{id: id, type: type, label: label, properties: props}
    end)
  end

  # Multi-hop BFS neighborhood search
  def neighbors(start_id, max_depth \\ 1) do
    max_depth = min(max_depth, 4) # prevent unbounded explosion
    queue = [{start_id, 0}]
    visited = MapSet.new([start_id])
    {nodes, edges} = bfs(queue, max_depth, visited, [], [])

    %{
      center: start_id,
      depth: max_depth,
      nodes_count: length(nodes),
      edges_count: length(edges),
      nodes: nodes,
      edges: edges
    }
  end

  defp bfs([], _max_depth, _visited, acc_nodes, acc_edges) do
    {acc_nodes, acc_edges}
  end

  defp bfs([{curr_id, depth} | rest], max_depth, visited, acc_nodes, acc_edges) do
    curr_node =
      case :ets.lookup(@nodes_table, curr_id) do
        [{^curr_id, type, label, props}] -> %{id: curr_id, type: type, label: label, properties: props}
        [] -> %{id: curr_id, type: "unknown", label: curr_id, properties: %{}}
      end

    new_acc_nodes = [curr_node | acc_nodes]

    if depth >= max_depth do
      bfs(rest, max_depth, visited, new_acc_nodes, acc_edges)
    else
      out_edges = :ets.lookup(@edges_out, curr_id)
      in_edges = :ets.lookup(@edges_in, curr_id)

      neighbors_out = Enum.map(out_edges, fn {from, to, rel} -> {to, %{from: from, to: to, relation: rel}} end)
      neighbors_in = Enum.map(in_edges, fn {to, from, rel} -> {from, %{from: from, to: to, relation: rel}} end)

      all_connections = neighbors_out ++ neighbors_in

      {new_queue, new_visited, new_edges} =
        Enum.reduce(all_connections, {rest, visited, acc_edges}, fn {next_id, edge}, {q, v, e} ->
          new_e = [edge | e]
          if MapSet.member?(v, next_id) do
            {q, v, new_e}
          else
            {q ++ [{next_id, depth + 1}], MapSet.put(v, next_id), new_e}
          end
        end)

      bfs(new_queue, max_depth, new_visited, new_acc_nodes, new_edges)
    end
  end

  # Transitive blast radius / impact analysis
  def blast_radius(target_id) do
    # Follow inbound edges transitively (who references / depends on target_id?)
    queue = [target_id]
    visited = MapSet.new([target_id])
    {impacted_ids, edges} = reverse_bfs(queue, visited, [], [])

    impacted_nodes =
      impacted_ids
      |> Enum.reject(&(&1 == target_id))
      |> Enum.map(fn id ->
        case :ets.lookup(@nodes_table, id) do
          [{^id, type, label, _}] -> %{id: id, type: type, label: label}
          [] -> %{id: id, type: "external", label: id}
        end
      end)

    %{
      target: target_id,
      impacted_count: length(impacted_nodes),
      impacted_entities: impacted_nodes,
      dependency_chains: edges
    }
  end

  defp reverse_bfs([], _visited, acc_ids, acc_edges) do
    {acc_ids, acc_edges}
  end

  defp reverse_bfs([curr_id | rest], visited, acc_ids, acc_edges) do
    in_edges = :ets.lookup(@edges_in, curr_id)

    {new_queue, new_visited, new_edges} =
      Enum.reduce(in_edges, {rest, visited, acc_edges}, fn {to, from, rel}, {q, v, e} ->
        edge_info = %{dependent: from, target: to, relation: rel}
        if MapSet.member?(v, from) do
          {q, v, [edge_info | e]}
        else
          {q ++ [from], MapSet.put(v, from), [edge_info | e]}
        end
      end)

    reverse_bfs(new_queue, new_visited, [curr_id | acc_ids], new_edges)
  end
end

defmodule KGEngine.Server do
  @moduledoc """
  Zero-overhead UNIX domain socket HTTP/1.1 JSON server.
  """

  def start(socket_path) do
    # Ensure parent dir exists
    Path.dirname(socket_path) |> File.mkdir_p!()
    File.rm(socket_path)

    # Listen on UNIX domain socket using Erlang's AF_UNIX support
    case :gen_tcp.listen(0, [:binary, packet: :raw, active: false, reuseaddr: true, ifaddr: {:local, socket_path}]) do
      {:ok, listen_socket} ->
        # Ensure permissions allow user access
        File.chmod(socket_path, 0o660)
        IO.puts("[kg-engine] 🟢 Listening on unix:#{socket_path}")
        accept_loop(listen_socket)

      {:error, reason} ->
        IO.puts("[kg-engine] 🔴 Failed to bind socket #{socket_path}: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp accept_loop(listen_socket) do
    case :gen_tcp.accept(listen_socket) do
      {:ok, client_socket} ->
        spawn(fn -> handle_connection(client_socket) end)
        accept_loop(listen_socket)

      {:error, :closed} ->
        :ok

      {:error, reason} ->
        IO.puts("[kg-engine] Accept error: #{inspect(reason)}")
        accept_loop(listen_socket)
    end
  end

  defp handle_connection(socket) do
    t0 = :erlang.monotonic_time(:microsecond)
    case :gen_tcp.recv(socket, 0, 3000) do
      {:ok, data} ->
        response = route_request(data, t0)
        :gen_tcp.send(socket, response)
        :gen_tcp.close(socket)

      _ ->
        :gen_tcp.close(socket)
    end
  end

  defp route_request(data, t0) do
    # Extract request line
    first_line = data |> String.split("\r\n", parts: 2) |> hd()
    
    case String.split(first_line, " ") do
      ["GET", path_and_query | _] ->
        dispatch(path_and_query, t0)

      _ ->
        format_json_response(400, %{error: "Bad Request"})
    end
  end

  defp dispatch(path_and_query, t0) do
    uri = URI.parse(path_and_query)
    query_params = (uri.query && URI.decode_query(uri.query)) || %{}

    payload =
      case uri.path do
        "/stats" ->
          KGEngine.Store.stats()

        "/node" ->
          case query_params["id"] do
            nil -> %{error: "Missing required parameter 'id'"}
            id ->
              case KGEngine.Store.get_node(id) do
                nil -> %{error: "Node not found", id: id}
                node -> node
              end
          end

        "/neighbors" ->
          case query_params["id"] do
            nil -> %{error: "Missing required parameter 'id'"}
            id ->
              if KGEngine.Store.exists?(id) do
                depth = (query_params["depth"] && String.to_integer(query_params["depth"])) || 1
                KGEngine.Store.neighbors(id, depth)
              else
                %{error: "Node not found", id: id}
              end
          end

        "/blast-radius" ->
          case query_params["id"] do
            nil -> %{error: "Missing required parameter 'id'"}
            id ->
              if KGEngine.Store.exists?(id) do
                KGEngine.Store.blast_radius(id)
              else
                %{error: "Node not found", id: id}
              end
          end

        "/query" ->
          q = query_params["q"] || ""
          %{query: q, matches: KGEngine.Store.query(q)}

        _ ->
          %{
            engine: "KGEngine 1.0 (Elixir/OTP 28)",
            endpoints: [
              "/stats",
              "/node?id=<node_id>",
              "/neighbors?id=<node_id>&depth=<1-4>",
              "/blast-radius?id=<node_id>",
              "/query?q=<term>"
            ]
          }
      end

    elapsed_us = :erlang.monotonic_time(:microsecond) - t0
    enriched = Map.put(payload, :_latency_us, elapsed_us)
    format_json_response(status_for(payload), enriched)
  end

  # A missing id and a typo are not successes. They used to return 200 with an
  # `error` body, which every HTTP client (`curl --fail`, fetch, requests) reads
  # as success — the same silent-failure class the jq surface's exit codes exist
  # to prevent.
  defp status_for(%{error: "Missing required parameter" <> _}), do: 400
  defp status_for(%{error: "Node not found"}), do: 404
  defp status_for(_), do: 200

  defp format_json_response(status, payload) do
    json_bytes = JSON.encode!(payload)
    status_msg = if status == 200, do: "200 OK", else: "#{status} Error"

    """
    HTTP/1.1 #{status_msg}\r
    Server: kg-engine-elixir\r
    Content-Type: application/json\r
    Content-Length: #{byte_size(json_bytes)}\r
    Connection: close\r
    \r
    #{json_bytes}
    """
  end
end

defmodule KGEngine.Watcher do
  @moduledoc """
  Lightweight mtime poll watcher that triggers graph reload on file changes.
  """
  def start_link(repo_root, reload_fn) do
    spawn_link(fn -> loop(repo_root, %{}, reload_fn) end)
  end

  # The watch list is DERIVED, not hand-written. It used to name four files while
  # the projection reads the eight living docs, docs/*.md, every SKILL.md,
  # inventory.toml and lib/knowledge-graph.nix — so most inputs could change
  # without the in-memory graph noticing. Measured: editing
  # docs/closure-reduction.md triggered nothing, editing MANUAL.md did.
  @root_docs ~w(AGENTS.md MANUAL.md ARCHITECTURE.md AUDIT.md TODO.md HANDOFF.md EXPERIMENTS.md README.md)

  def inputs(repo_root) do
    roots = Enum.map(@root_docs, &Path.join(repo_root, &1))
    docs = Path.wildcard(Path.join(repo_root, "docs/*.md"))
    skills = Path.wildcard(Path.join(repo_root, ".agents/skills/*/SKILL.md"))

    (roots ++ docs ++ skills ++ [
       Path.join(repo_root, "inventory.toml"),
       Path.join(repo_root, "lib/knowledge-graph.nix")
     ])
    |> Enum.filter(&File.regular?/1)
  end

  defp loop(repo_root, last_mtimes, reload_fn) do
    # 500 ms: the reload itself costs a nix eval (seconds), so a faster poll buys
    # nothing but churn. Each poll is ~67 stats, well under a millisecond.
    :timer.sleep(500)
    targets = inputs(repo_root)

    current_mtimes =
      Enum.reduce(targets, %{}, fn path, acc ->
        case File.stat(path) do
          {:ok, %File.Stat{mtime: mtime}} -> Map.put(acc, path, mtime)
          _ -> acc
        end
      end)

    if map_size(last_mtimes) > 0 and current_mtimes != last_mtimes do
      changed = Enum.filter(current_mtimes, fn {p, m} -> Map.get(last_mtimes, p) != m end)
      IO.puts("[kg-engine] ⚡ Change detected in: #{inspect(Enum.map(changed, &elem(&1, 0)))} -> reloading graph")
      reload_fn.()
    end

    loop(repo_root, current_mtimes, reload_fn)
  end
end

defmodule KGEngine.NixSource do
  @moduledoc "Opt-in escape hatch: evaluate the projection with nix (used to diff against the native builder)."

  def load(repo_root) do
    IO.puts("[kg-engine] Evaluating projection via nix eval .#knowledgeGraph.json...")

    case System.cmd("nix", ["eval", "--raw", ".#knowledgeGraph.json"],
           cd: repo_root,
           stderr_to_stdout: false
         ) do
      {json, 0} ->
        JSON.decode!(json)

      {err, code} ->
        IO.puts("[kg-engine] ⚠️ Nix eval failed (exit #{code}): #{err}")
        %{"nodes" => [], "edges" => []}
    end
  end
end

defmodule KGEngine.Native do
  @moduledoc """
  Builds the projection from the files themselves — no `nix` subprocess.

  The engine used to shell out to `nix eval` on every cold boot and every reload,
  which cost 1-3 s and made a 500 ms watcher pointless. This reads the same
  inputs `lib/knowledge-graph.nix` reads and produces the same node/edge sets in
  well under 100 ms.

  It IS a second implementation of the projection, so it is only safe because
  `checks:kg:sidecar` compares it to the compiled graph field by field (node
  ids, types, counts, blast answers). A divergence fails that gate instead of
  quietly answering from a different graph.

  Deliberately mirrors lib/knowledge-graph.nix:
    * doc sources are the eight living documents plus NON-recursive docs/*.md;
    * a mention is an exact TOKEN, split on [^A-Za-z0-9_-]+ — so `dev` does not
      match `devji`, and `nix-eval-jobs` is not `nix-eval`;
    * skill names are directory names, not the frontmatter `name:`;
    * tags come from frontmatter, deduped across skills.
  """

  @root_docs ~w(AGENTS.md MANUAL.md ARCHITECTURE.md AUDIT.md TODO.md HANDOFF.md EXPERIMENTS.md README.md)
  @token_re ~r/[^A-Za-z0-9_-]+/

  @root_docs ~w(AGENTS.md MANUAL.md ARCHITECTURE.md AUDIT.md TODO.md HANDOFF.md EXPERIMENTS.md README.md)

  def build(repo) do
    hosts = hosts(repo)
    skills = skills(repo)
    docs = docs(repo, hosts, skills)
    tags = skills |> Enum.flat_map(& &1.tags) |> Enum.uniq()

    host_nodes =
      Enum.map(hosts, fn {name, h} ->
        %{"id" => "host:" <> name, "type" => "host", "label" => name}
        |> maybe_put("status", h[:status])
        |> maybe_put("kind", h[:kind])
      end)

    skill_nodes =
      Enum.map(skills, fn s ->
        %{
          "id" => "skill:" <> s.name,
          "type" => "skill",
          "label" => s.name,
          "description" => s.description,
          "path" => s.path,
          "tags" => s.tags
        }
      end)

    doc_nodes =
      Enum.map(docs, fn d ->
        %{"id" => d.id, "type" => "doc", "label" => d.label, "path" => d.path}
      end)

    tag_nodes = Enum.map(tags, fn t -> %{"id" => "tag:" <> t, "type" => "tag", "label" => t} end)

    mention_edges =
      Enum.flat_map(docs, fn d ->
        Enum.map(d.hosts, &%{"from" => d.id, "to" => "host:" <> &1, "type" => "mentions"}) ++
          Enum.map(d.skills, &%{"from" => d.id, "to" => "skill:" <> &1, "type" => "mentions"})
      end)

    tag_edges =
      Enum.flat_map(skills, fn s ->
        Enum.map(s.tags, &%{"from" => "skill:" <> s.name, "to" => "tag:" <> &1, "type" => "tagged"})
      end)

    edges = mention_edges ++ tag_edges

    %{
      "nodes" => host_nodes ++ skill_nodes ++ doc_nodes ++ tag_nodes,
      "edges" => edges,
      "stats" => %{
        "hosts" => length(hosts),
        "skills" => length(skills),
        "docs" => length(docs),
        "edges" => length(edges)
      }
    }
  end

  # Only `[hosts.<name>]` starts a host; a sub-table (`[hosts.x.hardware]`) ends
  # it, so a nested `status`/`kind` can never be attributed to the host.
  defp hosts(repo) do
    path = Path.join(repo, "inventory.toml")
    {_, acc} =
      path
      |> File.read!()
      |> String.split("\n")
      |> Enum.reduce({nil, %{}}, fn line, {cur, acc} ->
        t = String.trim(line)

        cond do
          String.starts_with?(t, "[") and String.ends_with?(t, "]") ->
            case String.slice(t, 1..-2//1) |> String.split(".") do
              ["hosts", h] -> {h, Map.put_new(acc, h, %{})}
              _ -> {nil, acc}
            end

          cur == nil ->
            {nil, acc}

          true ->
            case Regex.run(~r/^(status|kind)\s*=\s*"([^"]*)"/, t) do
              [_, k, v] -> {cur, put_in(acc, [cur, String.to_atom(k)], v)}
              _ -> {cur, acc}
            end
        end
      end)

    Enum.sort(acc)
  end

  defp skills(repo) do
    dir = Path.join(repo, ".agents/skills")

    dir
    |> File.ls!()
    |> Enum.sort()
    |> Enum.filter(&File.dir?(Path.join(dir, &1)))
    |> Enum.map(fn name ->
      file = Path.join([dir, name, "SKILL.md"])
      text = if File.exists?(file), do: File.read!(file), else: ""
      fields = frontmatter(text)

      %{
        name: name,
        description: fields["description"] || "",
        tags: parse_list(fields["tags"] || ""),
        path: ".agents/skills/" <> name
      }
    end)
  end

  defp frontmatter(text) do
    lines = String.split(text, "\n")
    # `---` fences; the block is what sits between the first two.
    body =
      case Enum.split_while(lines, &(String.trim(&1) != "---")) do
        {_, ["---" | rest]} ->
          case Enum.split_while(rest, &(String.trim(&1) != "---")) do
            {fm, _} -> fm
          end

        _ ->
          []
      end

    Enum.reduce(body, %{}, fn line, acc ->
      case Regex.run(~r/^([A-Za-z0-9_-]+):\s*(.*)$/, String.trim(line)) do
        [_, k, v] -> Map.put(acc, k, v)
        _ -> acc
      end
    end)
  end

  # `[linux, macos]` -> ["linux", "macos"]; bare scalar -> [scalar]; quotes
  # stripped. Mirrors parseList in lib/skills.nix.
  defp parse_list(v) do
    s = String.trim(v)

    cond do
      s == "" ->
        []

      String.starts_with?(s, "[") and String.ends_with?(s, "]") ->
        s
        |> String.slice(1..-2//1)
        |> String.split(",")
        |> Enum.map(&(&1 |> String.trim() |> unquote_str()))
        |> Enum.reject(&(&1 == ""))

      true ->
        [unquote_str(s)]
    end
  end

  defp unquote_str(s) do
    s = String.trim(s)

    cond do
      String.starts_with?(s, "\"") and String.ends_with?(s, "\"") and byte_size(s) >= 2 ->
        String.slice(s, 1..-2//1)

      String.starts_with?(s, "'") and String.ends_with?(s, "'") and byte_size(s) >= 2 ->
        String.slice(s, 1..-2//1)

      true ->
        s
    end
  end

  defp docs(repo, hosts, skills) do
    roots = Enum.map(@root_docs, &Path.join(repo, &1))
    docs = Path.wildcard(Path.join(repo, "docs/*.md"))
    host_names = Enum.map(hosts, &elem(&1, 0))
    skill_names = Enum.map(skills, & &1.name)

    # `lib/knowledge-graph.nix` filters docs/*.md on readDir type == "regular",
    # so a SYMLINK (docs/vision.md -> control-plane-vision.md) is skipped. Wildcard
    # follows symlinks, which made the native builder invent a 22nd doc and five
    # extra edges — caught by the parity check, not by review.
    roots = Enum.filter(roots, &File.exists?/1)
    docs = Enum.filter(docs, &match?({:ok, %File.Stat{type: :regular}}, File.lstat(&1)))

    # Token-split, mirroring the Nix `builtins.split` exactly. Two faster-looking
    # alternatives were measured and rejected: `Task.async_stream` over the docs
    # (194 ms vs 95 ms — scheduler and copy cost exceed the win on 21 small files)
    # and a single regex alternation of the 77 names with boundary assertions
    # (81 ms — PCRE tries every alternative at every position). The split is
    # 72 ms for 510 KB, and it is the algorithm the projection uses, so parity is
    # by construction rather than by argument.
    (roots ++ docs)
    |> Enum.map(fn path ->
      rel = Path.relative_to(path, repo)
      text = File.read!(path)
      toks = text |> String.split(@token_re, trim: true) |> MapSet.new()

      %{
        id: "doc:" <> rel,
        path: rel,
        label: first_heading(text),
        hosts: Enum.filter(host_names, &MapSet.member?(toks, &1)),
        skills: Enum.filter(skill_names, &MapSet.member?(toks, &1))
      }
    end)
  end

  defp first_heading(text) do
    case text |> String.split("\n") |> Enum.find(&String.starts_with?(&1, "# ")) do
      nil -> "(untitled)"
      line -> String.replace_prefix(line, "# ", "")
    end
  end

  defp maybe_put(map, _k, nil), do: map
  defp maybe_put(map, k, v), do: Map.put(map, k, v)
end

# ------------------------------------------------------------------------------
# Entrypoint & CLI Orchestration
# ------------------------------------------------------------------------------
{opts, _, _} =
  OptionParser.parse(System.argv(),
    switches: [socket: :string, file: :string, repo: :string, native: :boolean, nix: :boolean],
    aliases: [s: :socket, f: :file, r: :repo]
  )

runtime_dir = System.get_env("XDG_RUNTIME_DIR") || "/tmp"
socket_path = opts[:socket] || Path.join(runtime_dir, "kg.sock")
repo_root = opts[:repo] || File.cwd!()

IO.puts("""
================================================================================
KGEngine — In-Memory Reactive Knowledge Graph Sidecar
================================================================================
Runtime: Elixir #{System.version()} / OTP #{:erlang.system_info(:otp_release)}
Socket:  unix:#{socket_path}
Repo:    #{repo_root}
================================================================================
""")

KGEngine.Store.init()

# Graph loader function
reload_graph = fn ->
  # Priority 1: explicitly passed file (KG_GRAPH), 2: native build from the
  # files, 3: `nix eval` only when asked for with --nix. Native is the default
  # because it is the only source fast enough for a 500 ms watcher and it never
  # runs a subprocess; `checks:kg:sidecar` proves it matches the compiled graph.
  {json_data, source} =
    cond do
      opts[:file] && File.exists?(opts[:file]) ->
        IO.puts("[kg-engine] Loading graph from #{opts[:file]}...")
        {File.read!(opts[:file]) |> JSON.decode!(), "file"}

      opts[:nix] ->
        {KGEngine.NixSource.load(repo_root), "nix"}

      true ->
        # Timed, because "cold bootstrap" has a number attached to it and a
        # claim nobody measures is how the last set of latency numbers rotted.
        {us, built} = :timer.tc(fn -> KGEngine.Native.build(repo_root) end)
        IO.puts("[kg-engine] native build: #{Float.round(us / 1000, 1)} ms (no nix)")
        {built, "native"}

      # Priority 2: evaluate the projection. The runner normally passes --file
      # (resolved by scripts/task/lib/kg-graph.sh, which caches per revision), so
      # this branch is for a hand-started engine only. A `data/kg.json` tier used
      # to sit here: it won silently whenever such a file existed, and nothing in
      # the repo creates or ignores it, so a stale snapshot could serve for weeks.
    end

  :persistent_term.put({KGEngine.Store, :source}, source)

  case KGEngine.Store.load_data(json_data) do
    {:ok, %{nodes: n, edges: e}} ->
      IO.puts("[kg-engine] 🚀 Loaded #{n} nodes and #{e} edges into ETS.")

    error ->
      IO.puts("[kg-engine] ⚠️ Error loading graph: #{inspect(error)}")
  end
end

# Initial load
reload_graph.()

# Start background file watcher
KGEngine.Watcher.start_link(repo_root, reload_graph)

# Trap signals for clean exit and socket cleanup
System.at_exit(fn _ ->
  IO.puts("\n[kg-engine] Cleaning up socket #{socket_path}...")
  File.rm(socket_path)
end)

# Start UNIX domain socket HTTP server (blocking accept loop)
KGEngine.Server.start(socket_path)
