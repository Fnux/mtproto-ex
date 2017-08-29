defmodule MTProto.Session.Workers.Supervisor do
  alias MTProto.Session.{Workers, Workers.History}

  use Supervisor

  def start_link(session_id) do
    Supervisor.start_link(__MODULE__, session_id)
  end

  def init(session_id) do
    history_table = History.table_for(session_id)

    children = [
      worker(Workers.AuthKeyHandler, [session_id], [restart: :permanent, id: Auth]),
      worker(Workers.Handler, [session_id], [restart: :permanent, id: Handler]),
      worker(Workers.Listener, [session_id], [restart: :permanent, id: Listener]),
      worker(MTProto.Registry, [history_table], restart: :transient)
    ]

    supervise(children, strategy: :one_for_one)
  end
end
