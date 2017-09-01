defmodule MTProto.Session.Supervisor do
  alias MTProto.Session
  use Supervisor

  @moduledoc false
  @name __MODULE__

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: @name)
  end

  def init(_) do
    children = [
      supervisor(MTProto.Session.Workers.Supervisor, [], restart: :transient)
    ]

    supervise(children, strategy: :simple_one_for_one)
  end

  def create(session_id) do
    Supervisor.start_child(@name, [session_id])
  end

  def destroy(session_id) do
    session = Session.get(session_id)
    Supervisor.terminate_child @name, session.listener
  end
end
