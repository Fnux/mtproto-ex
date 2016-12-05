defmodule MTProto.Session.Supervisor do
  use Supervisor

  @moduledoc false
  @name :mtproto_session_supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: @name)
  end

  def init(_) do
    children = []

    supervise(children, strategy: :one_for_one)
  end

  def create_session do
    session_handler = worker(MTProto.Session.Handler, [], [])
    Supervisor.start_child(@name, session_handler)
  end
end
