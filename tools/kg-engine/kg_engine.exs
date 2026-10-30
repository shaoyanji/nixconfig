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

  @patterns ~w(host skill doc tag comention stats)
  def valid_pattern?(p), do: p in @patterns

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

  # --- the six traversals of `scripts/task/kg-query.sh` -----------------------
  # Same questions as the jq programs there, answered from ETS. This is a second
  # implementation of those semantics by construction (jq over a file vs Elixir
  # over tables), so `checks:kg:sidecar` compares every pattern's answer against
  # the jq one. A silent divergence between two implementations of one question
  # is the failure this project already paid for once.
  def pattern("host", id, _min, _top), do: id |> inbound_ids() |> Enum.uniq() |> Enum.sort()
  def pattern("tag", id, _min, _top), do: id |> inbound_ids() |> Enum.uniq() |> Enum.sort()
  def pattern("doc", id, _min, _top), do: id |> outbound_ids() |> Enum.uniq() |> Enum.sort()

  def pattern("skill", id, _min, _top),
    do: (inbound_ids(id) ++ outbound_ids(id)) |> Enum.uniq() |> Enum.sort()

  def pattern("comention", id, min, _top) do
    docs = id |> inbound_ids() |> Enum.uniq() |> MapSet.new()

    :ets.tab2list(@edges_out)
    |> Enum.filter(fn {from, to, type} ->
      type == "mentions" and MapSet.member?(docs, from) and String.starts_with?(to, "host:") and
        to != id
    end)
    |> Enum.map(fn {from, to, _type} -> {from, to} end)
    |> MapSet.new()
    |> Enum.map(fn {_from, to} -> to end)
    |> Enum.frequencies()
    |> Enum.filter(fn {_id, shared} -> shared >= min end)
    |> Enum.sort_by(fn {id, shared} -> {-shared, id} end)
    |> Enum.map(fn {id, shared} -> %{"id" => id, "shared" => shared} end)
  end

  # `{counts, top}` — `top` is [] when the caller did not ask for it. It is NOT
  # part of the counts object: `kg-query.sh --json` emits one object there, and
  # the top-degree table is a text-mode extra. Keeping it out of `results` is
  # what makes the fast path byte-identical to the jq one.
  def pattern("stats", _id, _min, top) do
    s = stats()
    types = Map.get(s, :node_types, %{})

    counts = %{
      "nodes" => s.nodes,
      "hosts" => Map.get(types, "host", 0),
      "skills" => Map.get(types, "skill", 0),
      "docs" => Map.get(types, "doc", 0),
      "tags" => Map.get(types, "tag", 0),
      "edges" => s.edges
    }

    degrees =
      if top > 0 do
        :ets.tab2list(@edges_out)
        |> Enum.map(fn {from, _to, _type} -> from end)
        |> Enum.frequencies()
        |> Enum.sort_by(fn {id, n} -> {-n, id} end)
        |> Enum.take(top)
        |> Enum.map(fn {id, n} -> %{"id" => id, "n" => n} end)
      else
        []
      end

    {counts, degrees}
  end

  def pattern(other, _id, _min, _top), do: {:error, "unknown pattern: #{other}"}

  defp inbound_ids(id) do
    :ets.lookup(@edges_in, id) |> Enum.map(fn {_to, from, _type} -> from end)
  end

  defp outbound_ids(id) do
    :ets.lookup(@edges_out, id) |> Enum.map(fn {_from, to, _type} -> to end)
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

        # The six traversals, so `kg-query.sh` can answer from memory when this
        # daemon is up. The envelope is that script's `--json` contract
        # verbatim: a fast path that changes the shape is not a fast path.
        "/pattern" ->
          p = query_params["p"]
          id = query_params["name"] || ""
          min = int_param(query_params["min"], 1)
          top = int_param(query_params["top"], 0)

          cond do
            p == nil ->
              %{error: "Missing required parameter 'p'"}

            not KGEngine.Store.valid_pattern?(p) ->
              %{error: "Unknown pattern", pattern: p}

            p == "stats" ->
              {counts, degrees} = KGEngine.Store.pattern("stats", nil, min, top)
              base = %{pattern: p, arg: "", count: 1, results: [counts]}
              if degrees == [], do: base, else: Map.put(base, :top, degrees)

            not KGEngine.Store.exists?(id) ->
              %{error: "Node not found", id: id}

            true ->
              results = KGEngine.Store.pattern(p, id, min, top)
              %{pattern: p, arg: id, count: length(results), results: results}
          end

        _ ->
          %{
            engine: "KGEngine 1.0 (Elixir/OTP 28)",
            endpoints: [
              "/stats",
              "/node?id=<node_id>",
              "/neighbors?id=<node_id>&depth=<1-4>",
              "/blast-radius?id=<node_id>",
              "/query?q=<term>",
              "/pattern?p=<host|skill|doc|tag|comention|stats>&name=<id>&min=<n>&top=<n>"
            ]
          }
      end

    elapsed_us = :erlang.monotonic_time(:microsecond) - t0
    # `/pattern` answers `kg-query.sh --json` verbatim, so it must not grow a
    # field that surface does not have: an extra key is a contract break even
    # when the answer is right. Every other endpoint is a diagnostic surface and
    # keeps the timing.
    enriched = if uri.path == "/pattern", do: payload, else: Map.put(payload, :_latency_us, elapsed_us)
    format_json_response(status_for(payload), enriched)
  end

  # A missing id and a typo are not successes. They used to return 200 with an
  # `error` body, which every HTTP client (`curl --fail`, fetch, requests) reads
  # as success — the same silent-failure class the jq surface's exit codes exist
  # to prevent.
  # Query params arrive as strings. A malformed number is a usage answer, not a
  # crash inside the accept loop.
  defp int_param(nil, default), do: default

  defp int_param(value, default) do
    case Integer.parse(value) do
      {n, ""} -> n
      _ -> default
    end
  end

  defp status_for(%{error: "Missing required parameter" <> _}), do: 400
  defp status_for(%{error: "Node not found"}), do: 404
  defp status_for(%{error: "Unknown pattern"}), do: 400
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
  # the projection reads the living docs, docs/*.md, every SKILL.md,
  # inventory.toml and lib/knowledge-graph.nix — so most inputs could change
  # without the in-memory graph noticing. Measured: editing
  # docs/closure-reduction.md triggered nothing, editing MANUAL.md did.
  #
  # ARCHITECTURE/TODO/HANDOFF/EXPERIMENTS moved to AGENTS.nix (2026-10-19) and
  # are one-line stubs; `lib/knowledge-graph.nix` does not index them, so neither
  # does this builder or its watch list (parity is enforced by checks:kg:sidecar).
  @root_docs ~w(AGENTS.md MANUAL.md AUDIT.md README.md)

  def inputs(repo_root) do
    roots = Enum.map(@root_docs, &Path.join(repo_root, &1))

    # Same derivation as `KGEngine.Native.docs/3` — a watcher with its own list
    # is how `docs/closure-reduction.md` once changed without a reload.
    docs =
      KGEngine.Native.md_files(repo_root, ["docs", ".agents", ".agents/deploy", "taskfiles"]) ++
        KGEngine.Native.md_files_in_subdirs(repo_root, ".agents/deploy") ++
        KGEngine.Native.md_files_in_subdirs(repo_root, "hosts")

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
    * doc sources are the four living documents plus NON-recursive docs/*.md;
    * a mention is an exact TOKEN, split on [^A-Za-z0-9_-]+ — so `dev` does not
      match `devji`, and `nix-eval-jobs` is not `nix-eval`;
    * skill names are directory names, not the frontmatter `name:`;
    * tags come from frontmatter, deduped across skills.
  """

  @root_docs ~w(AGENTS.md MANUAL.md AUDIT.md README.md)

  def build(repo) do
    debug = System.get_env("KG_NATIVE_DEBUG") == "1"
    phase = fn label, fun ->
      {us, value} = :timer.tc(fun)
      if debug, do: IO.puts(:stderr, "[kg-native] #{label}: #{Float.round(us / 1000, 1)} ms")
      value
    end

    hosts = phase.("hosts", fn -> hosts(repo) end)
    skills = phase.("skills", fn -> skills(repo) end)
    docs = phase.("docs", fn -> docs(repo, hosts, skills) end)
    tags = phase.("graph", fn -> skills |> Enum.flat_map(& &1.tags) |> Enum.uniq() end)

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

    # `references`: doc -> doc, from the markdown links the token scan cannot see.
    # Same shape as the Nix projection's edge set — `checks:kg:native` compares
    # counts, and `checks:kg:sidecar` compares answers, so a link parsed here but
    # not there fails a gate instead of quietly changing the graph.
    reference_edges =
      Enum.flat_map(docs, fn d ->
        Enum.map(d.refs, &%{"from" => d.id, "to" => "doc:" <> &1, "type" => "references"})
      end)

    edges = mention_edges ++ tag_edges ++ reference_edges

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
            with [k, v] <- String.split(t, "=", parts: 2),
                 true <- k in ["status", "kind"] do
              {cur, put_in(acc, [cur, String.to_atom(k)], v |> String.trim() |> String.trim("\""))}
            else
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

    # `String.split(line, ":", parts: 2)` instead of a regex per line: the
    # frontmatter schema is a subset of YAML with no nesting, so the first colon
    # is the separator and the key is alnum/_/- only.
    Enum.reduce(body, %{}, fn line, acc ->
      t = String.trim(line)

      case String.split(t, ":", parts: 2) do
        [k, v] ->
          if key?(k),
            do: Map.put(acc, k, String.trim_leading(v)),
            else: acc

        _ ->
          acc
      end
    end)
  end

  # The empty binary is the SUCCESSFUL end of the scan (every byte was a valid
  # key byte). Returning false here made every frontmatter key invalid, which
  # silently dropped all 151 tag edges — the parity gate is what caught it.
  defp key?(<<>>), do: true

  defp key?(<<c, rest::binary>>) do
    ok? = (c >= ?a and c <= ?z) or (c >= ?A and c <= ?Z) or (c >= ?0 and c <= ?9) or c == ?_ or c == ?-
    ok? and key?(rest)
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
    host_names = Enum.map(hosts, &elem(&1, 0))
    skill_names = Enum.map(skills, & &1.name)

    # The doc SET is the one `lib/knowledge-graph.nix` defines: living documents,
    # `docs/*.md`, the agent contract (`.agents/*.md`, `.agents/deploy/**`) and
    # `taskfiles/*.md`. This list used to stop at `docs/*.md`, which stayed
    # invisible until the projection gained the 13 agent/taskfile documents:
    # parity then read 226/394 against 239/539. Two lists for one projection is
    # the defect; `checks:kg:native` is what makes the next drift loud.
    #
    # `md_files` also mirrors the Nix side's readDir filter (type == "regular"),
    # so a SYMLINK (docs/vision.md -> control-plane-vision.md) is skipped.
    # Wildcard followed symlinks, which invented an extra doc and five edges.
    docs =
      md_files(repo, ["docs", ".agents", ".agents/deploy", "taskfiles"]) ++
        md_files_in_subdirs(repo, ".agents/deploy") ++
        md_files_in_subdirs(repo, "hosts")

    roots = Enum.filter(roots, &File.exists?/1)

    # Name membership, measured rather than guessed (22 documents, 77 names,
    # 526 KB):
    #
    #   String.split on the token regex + MapSet   117 ms  (the Nix algorithm;
    #                                                      allocates ~90k tokens)
    #   split on whitespace, trim the edges        137 ms  (and NOT parity-safe:
    #                                                      `hosts/frieren` stays one
    #                                                      token, so mentions vanish)
    #   one att/alternation regex                   81 ms  (PCRE retries every
    #                                                      alternative at every byte)
    #   :binary.matches per name + edge check       35 ms  (C scan, one pass per
    #                                                      name; only hits are
    #                                                      materialised)
    #   ONE compiled multi-pattern :binary.matches   4.7 ms  (Aho-Corasick over all
    #                                                      77 names at once)
    #   either of the above, 8-way parallel        2.05 s   (lost by 40× — NFS
    #                                                      reads and process copies
    #                                                      dominate 22 small files)
    #
    # The compiled pattern is used. Parity holds because a hit is a mention
    # exactly when the bytes on either side are not token characters — the same
    # condition the split encodes — so `dev` inside `devji` and `nix-eval` inside
    # `nix-eval-jobs` are rejected, and a non-ASCII neighbour counts as a
    # separator on both sides. Verified equal to the per-name scan on every
    # document in the repo, and `checks:kg:sidecar` compares the finished graph
    # to the Nix projection, so a divergence fails a gate rather than silently
    # dropping an edge.
    paths = roots ++ docs
    pattern = :binary.compile_pattern(host_names ++ skill_names)
    rels = Enum.map(paths, &Path.relative_to(&1, repo))

    Enum.map(paths, fn path ->
      rel = Path.relative_to(path, repo)
      text = File.read!(path)
      found = mentions(text, pattern)

      %{
        id: "doc:" <> rel,
        path: rel,
        label: first_heading(text),
        hosts: Enum.filter(host_names, &MapSet.member?(found, &1)),
        skills: Enum.filter(skill_names, &MapSet.member?(found, &1)),
        refs: references(text, rel, rels)
      }
    end)
  end

  # `[text](path.md#frag)` — the twin of `linkTargets`/`referencesIn` in
  # lib/knowledge-graph.nix. Deliberately built the same way the Nix side builds
  # it: split on "](", take up to the next ")", strip the fragment, keep only a
  # relative `.md` target that names another doc. A regex here would be a second
  # definition of the same syntax, and the two would drift on an edge case
  # neither side anticipated — which is what parity gates exist to prevent.
  defp references(text, rel, rels) do
    dir =
      case Path.dirname(rel) do
        "." -> ""
        d -> d
      end

    set = MapSet.new(rels)

    targets =
      case String.split(text, "](") do
        [_ | rest] -> rest
        [] -> []
      end

    targets
    |> Enum.map(fn chunk -> chunk |> String.split(")") |> hd() end)
    |> Enum.map(fn t -> t |> String.split("#") |> hd() end)
    |> Enum.map(&strip_angle/1)
    |> Enum.filter(&doc_link?/1)
    |> Enum.map(fn t -> normalise_path(if dir == "", do: t, else: dir <> "/" <> t) end)
    |> Enum.reject(&(&1 == rel))
    |> Enum.filter(&MapSet.member?(set, &1))
    |> Enum.uniq()
  end

  defp strip_angle(t) do
    t
    |> String.replace_prefix("<", "")
    |> String.replace_suffix(">", "")
  end

  defp doc_link?(t) do
    t != "" and String.ends_with?(t, ".md") and not String.starts_with?(t, "/") and
      not String.starts_with?(t, "http") and not String.starts_with?(t, "mailto:")
  end

  # Segment-wise `..` and `.`, the same rule as `normalisePath` on the Nix side.
  # `Path.expand` is not usable: it wants an absolute base and would turn a
  # repo-relative target into a filesystem path.
  defp normalise_path(path) do
    path
    |> String.split("/")
    |> Enum.reduce([], fn
      seg, acc when seg in ["", "."] -> acc
      "..", [] -> []
      "..", acc -> Enum.drop(acc, -1)
      seg, acc -> acc ++ [seg]
    end)
    |> Enum.join("/")
  end

  # Regular `*.md` files directly inside each `dirs` entry, sorted — the Elixir
  # twin of `mdIn` in lib/knowledge-graph.nix. A missing directory yields [], and
  # a symlink is skipped because `mdIn` keeps only `type == "regular"`.
  def md_files(repo, dirs) do
    Enum.flat_map(dirs, fn dir ->
      names =
        case File.ls(Path.join(repo, dir)) do
          {:ok, names} -> names
          {:error, _} -> []
        end

      names
      |> Enum.sort()
      |> Enum.filter(&String.ends_with?(&1, ".md"))
      |> Enum.map(&Path.join([repo, dir, &1]))
      |> Enum.filter(&regular?/1)
    end)
  end

  # `mdInSubdirs`: one level deeper, which is where `.agents/deploy/hosts/*.md`
  # lives. Shared with the watcher, which derives its watch list from the same
  # set instead of naming four files.
  def md_files_in_subdirs(repo, dir) do
    subdirs =
      case File.ls(Path.join(repo, dir)) do
        {:ok, names} -> names
        {:error, _} -> []
      end
      |> Enum.sort()
      |> Enum.filter(&File.dir?(Path.join([repo, dir, &1])))

    Enum.flat_map(subdirs, &md_files(repo, [Path.join(dir, &1)]))
  end

  defp regular?(path), do: match?({:ok, %File.Stat{type: :regular}}, File.lstat(path))

  # Every occurrence of any name, kept only when it stands as a whole token. 0
  # (out of range) is not a token byte, so document start/end are boundaries.
  defp mentions(text, pattern) do
    text
    |> :binary.matches(pattern)
    |> Enum.reduce(MapSet.new(), fn {pos, len}, acc ->
      if token_byte?(byte_at(text, pos - 1)) or token_byte?(byte_at(text, pos + len)) do
        acc
      else
        MapSet.put(acc, binary_part(text, pos, len))
      end
    end)
  end

  defp byte_at(_text, i) when i < 0, do: 0
  defp byte_at(text, i) when i >= byte_size(text), do: 0
  defp byte_at(text, i), do: :binary.at(text, i)

  defp token_byte?(c) when c in ?a..?z or c in ?A..?Z or c in ?0..?9 or c == ?_ or c == ?-, do: true
  defp token_byte?(_), do: false

  # First line that starts with `# `, without splitting the document into lines:
  # `String.split(text, "\n")` over 526 KB allocates ~90k binaries just to read
  # one heading (it was ~15 ms of the build by itself). SCAN finds a candidate
  # anywhere and only accepts it at a line start.
  defp first_heading(text) do
    case heading_start(text, 0) do
      nil -> "(untitled)"
      pos ->
        from = pos + 2
        rest = binary_part(text, from, byte_size(text) - from)
        len = case :binary.match(rest, "\n") do
          :nomatch -> byte_size(rest)
          {i, _} -> i
        end
        binary_part(rest, 0, len)
    end
  end

  defp heading_start(text, from) when from >= byte_size(text), do: nil

  defp heading_start(text, from) do
    scope = {from, byte_size(text) - from}

    case :binary.match(text, "# ", scope: scope) do
      :nomatch ->
        nil

      {pos, _} ->
        if pos == 0 or :binary.at(text, pos - 1) == ?\n,
          do: pos,
          else: heading_start(text, pos + 1)
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
    switches: [
      socket: :string,
      file: :string,
      repo: :string,
      native: :boolean,
      nix: :boolean,
      build_only: :boolean
    ],
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

# `--build-only` exists so the cold-bootstrap budget can be MEASURED by a gate
# (`checks:kg:native`) rather than quoted from a comment: it builds the native
# graph, prints {ms, nodes, edges} as JSON and exits without starting the server.
if opts[:build_only] do
  {us, graph} = :timer.tc(fn -> KGEngine.Native.build(repo_root) end)

  IO.puts(
    JSON.encode!(%{
      "ms" => Float.round(us / 1000, 1),
      "nodes" => length(graph["nodes"]),
      "edges" => length(graph["edges"]),
      "source" => "native"
    })
  )

  System.halt(0)
end

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
