defmodule TurnsBench.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    port = String.to_integer(System.get_env("PORT", "9102"))
    site = System.get_env("SITE", "modules/services/turns-dashboard/web")
    fixture = System.get_env("FIXTURE", "fixture/turns.json")

    turns = fixture |> File.read!() |> Jason.decode!()

    history =
      turns
      |> Enum.map(&TurnsBench.render/1)
      |> Enum.join()

    :persistent_term.put({:turns, :history}, history)
    :persistent_term.put({:turns, :rows}, turns)
    :persistent_term.put({:turns, :index}, File.read!(Path.join(site, "index.html")))
    :persistent_term.put({:turns, :css}, File.read!(Path.join(site, "style.css")))
    :persistent_term.put({:turns, :js}, File.read!(Path.join(site, "app.js")))
    :persistent_term.put({:turns, :seq}, :atomics.new(1, signed: true))

    IO.puts(:stderr, "turns-runtime elixir: 127.0.0.1:#{port}, #{length(turns)} turns, #{byte_size(history)} bytes of history")

    children = [
      TurnsBench.Bus,
      {Bandit, plug: TurnsBench.Router, port: port, ip: {127, 0, 0, 1}}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: TurnsBench.Supervisor)
  end
end
