defmodule TurnsBench.Router do
  @moduledoc "The read path: the page, one history frame, and a fan-out."
  use Plug.Router

  plug :match
  plug :dispatch

  get "/" do
    send_bytes(conn, :index, "text/html; charset=utf-8")
  end

  get "/style.css" do
    send_bytes(conn, :css, "text/css")
  end

  get "/app.js" do
    send_bytes(conn, :js, "text/javascript")
  end

  get "/api/stream" do
    conn =
      conn
      |> put_resp_header("content-type", "text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> send_chunked(200)

    :ok = TurnsBench.Bus.join(self())
    history = :persistent_term.get({:turns, :history})
    {:ok, conn} = chunk(conn, "event: patch\ndata: selector #log\ndata: mode inner\ndata: elements " <> history <> "\n\n")
    hold(conn)
  end

  # Bench-only: publish one turn the way the shim relay would.
  post "/api/broadcast" do
    seq = :atomics.add_get(:persistent_term.get({:turns, :seq}), 1, 1)
    rows = :persistent_term.get({:turns, :rows})
    row = TurnsBench.render(Enum.at(rows, rem(seq, length(rows))))
    ms = System.system_time(:millisecond)

    frame =
      "event: patch\ndata: selector #log\ndata: mode prepend\ndata: " <>
        row <> "\n: bench #{seq} #{ms}\n\n"

    TurnsBench.Bus.publish(frame)

    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(200, ~s({"seq":#{seq},"clients":#{TurnsBench.Bus.size()}}))
  end

  get "/healthz" do
    send_resp(conn, 200, Integer.to_string(length(:persistent_term.get({:turns, :rows}))))
  end

  match _ do
    send_resp(conn, 404, "not found")
  end

  defp send_bytes(conn, key, ctype) do
    conn
    |> put_resp_header("content-type", ctype)
    |> put_resp_header("cache-control", "no-cache")
    |> send_resp(200, :persistent_term.get({:turns, key}))
  end

  defp hold(conn) do
    receive do
      {:frame, frame} ->
        case chunk(conn, frame) do
          {:ok, conn} -> hold(conn)
          {:error, _} -> conn
        end
    end
  end
end

defmodule TurnsBench do
  @moduledoc "Row markup, one function, so the three prototypes agree on bytes."

  def render(t) do
    ~s(<article class="turn" id="turn-#{esc(t["id"])}"><div class="shard" aria-hidden="true"></div><header class="head"><span class="out done">done</span><span class="src">#{esc(t["source"])}</span><span class="when">#{esc(t["when"])}</span></header><h2 class="subject">#{esc(t["subject"])}</h2><p class="action">#{esc(t["action"])}</p><div class="meta">) <>
      tag(t["branch"], "branch") <> tag(t["commit"], "base") <>
      ~s(</div><div class="req"></div></article>)
  end

  defp tag("", _), do: ""
  defp tag(nil, _), do: ""
  defp tag(value, label), do: ~s(<span class="tag">#{label} #{esc(value)}</span>)

  defp esc(nil), do: ""

  defp esc(s) do
    s
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end
end
