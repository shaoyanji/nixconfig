defmodule TurnsBench.Bus do
  @moduledoc """
  The fan-out: every open stream registers the process that is writing it, and a
  new turn is one `send/2` per reader.

  A GenServer serialises publishes, which is fine at the cadence a turn log
  actually has (one every few seconds). At thousands of publishes a second the
  honest answer is `Phoenix.PubSub`/`Registry`, not this map — the benchmark
  reports what the simple shape costs rather than pretending it is a bus.
  """
  use GenServer

  def start_link(_), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def join(pid), do: GenServer.call(__MODULE__, {:join, pid})
  def leave(pid), do: GenServer.cast(__MODULE__, {:leave, pid})
  def size, do: GenServer.call(__MODULE__, :size)
  def publish(frame), do: GenServer.cast(__MODULE__, {:publish, frame})

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:join, pid}, _from, state) do
    Process.monitor(pid)
    {:reply, :ok, Map.put(state, pid, true)}
  end

  def handle_call(:size, _from, state), do: {:reply, map_size(state), state}

  @impl true
  def handle_cast({:leave, pid}, state), do: {:noreply, Map.delete(state, pid)}

  def handle_cast({:publish, frame}, state) do
    Enum.each(state, fn {pid, _} -> send(pid, {:frame, frame}) end)
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state),
    do: {:noreply, Map.delete(state, pid)}

  def handle_info(_msg, state), do: {:noreply, state}
end
