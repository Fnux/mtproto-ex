defmodule MTProto.Supervisor do
  use Supervisor

  # Main supervisor. Start the session's registry, the dc's registry and both
  # the listener and handler supervisors.

  @moduledoc false
  @name MTProto.Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: @name)
  end

  def init(_) do
    children = [
      worker(MTProto.Registry, [DCRegistry], [restart: :permanent, id: DCRegistry]),
      worker(MTProto.Registry, [SessionRegistry], [restart: :permanent, id: SessionRegistry]),
      supervisor(MTProto.Session.Supervisor, [], [restart: :permanent])
    ]

    supervise(children, strategy: :one_for_one)
  end

  def stop do
    Supervisor.stop(@name)
  end
end
