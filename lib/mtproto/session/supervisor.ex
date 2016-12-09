defmodule MTProto.Session.Supervisor do
  use Supervisor
  alias MTProto.Crypto

  @moduledoc false
  @name SessionSupervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: @name)
  end

  def init(_) do
    children = []

    supervise(children, strategy: :one_for_one)
  end

  # Create a new session, called by MTProto.create_session/0
  def pop() do
    session_id = Crypto.rand_bytes(8)
    session_id_str = Integer.to_string(session_id)

    listener_id = String.to_atom("listener" <> session_id_str)
    handler_id = String.to_atom("handler" <> session_id_str)

    handler = worker(MTProto.Session.Handler, [session_id], [id: handler_id])
    listener = worker(MTProto.Session.Listener, [session_id], [id: listener_id])

    {:ok, handler} = Supervisor.start_child(@name, handler)
    {:ok, _} = Supervisor.start_child(@name, listener)

    {:ok, handler}
  end
end
