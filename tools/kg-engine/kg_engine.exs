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
    {:ok, %{nodes: node_count, edges: edge_count, source_stats: data["stats"] || %{}}}
  end

  def stats do
    nodes_count = :ets.info(@nodes_table, :size)
    edges_count = :ets.info(@edges_out, :size)

    types =
      :ets.tab2list(@nodes_table)
      |> Enum.group_by(fn {_, type, _, _} -> type end)
      |> Map.new(fn {type, list} -> {type, length(list)} end)

    %{
      nodes: nodes_count,
      edges: edges_count,
      node_types: types,
      status: "operational",
      engine: "Elixir/OTP 28 ETS"
    }
  end

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
              depth = (query_params["depth"] && String.to_integer(query_params["depth"])) || 1
              KGEngine.Store.neighbors(id, depth)
          end

        "/blast-radius" ->
          case query_params["id"] do
            nil -> %{error: "Missing required parameter 'id'"}
            id -> KGEngine.Store.blast_radius(id)
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
    format_json_response(200, enriched)
  end

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

  defp loop(repo_root, last_mtimes, reload_fn) do
    :timer.sleep(2000)

    # Monitored files
    targets = [
      Path.join(repo_root, "inventory.toml"),
      Path.join(repo_root, "lib/knowledge-graph.nix"),
      Path.join(repo_root, "TODO.md"),
      Path.join(repo_root, "MANUAL.md")
    ]

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

# ------------------------------------------------------------------------------
# Entrypoint & CLI Orchestration
# ------------------------------------------------------------------------------
{opts, _, _} =
  OptionParser.parse(System.argv(),
    switches: [socket: :string, file: :string, repo: :string],
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
  # Priority 1: Check explicitly passed file
  json_data =
    cond do
      opts[:file] && File.exists?(opts[:file]) ->
        IO.puts("[kg-engine] Loading graph from #{opts[:file]}...")
        File.read!(opts[:file]) |> JSON.decode!()

      # Priority 2: Check flake outputs knowledgeGraph.json
      File.exists?(Path.join(repo_root, "data/kg.json")) ->
        IO.puts("[kg-engine] Loading graph from data/kg.json...")
        File.read!(Path.join(repo_root, "data/kg.json")) |> JSON.decode!()

      # Priority 3: Query nix eval --raw .#knowledgeGraph.json
      true ->
        IO.puts("[kg-engine] Evaluating Nix AST projection via nix eval .#knowledgeGraph.json...")
        case System.cmd("nix", ["eval", "--raw", ".#knowledgeGraph.json"], cd: repo_root, stderr_to_stdout: false) do
          {json_str, 0} ->
            JSON.decode!(json_str)

          {err, code} ->
            IO.puts("[kg-engine] ⚠️ Nix eval failed (exit #{code}): #{err}")
            %{"nodes" => [], "edges" => []}
        end
    end

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
