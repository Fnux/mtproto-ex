defmodule MTProto.Supervisor do
  use Supervisor

  @moduledoc false
  @name MTProto.Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: @name)
  end

  def init(_) do
    children = [
      worker(MTProto.Registry, [:main], [restart: :permanent, id: Registry]),
      worker(MTProto.Registry, [:session], [restart: :permanent, id: SessionRegistry]),
      supervisor(MTProto.Session.Supervisor, [], [restart: :permanent]),
    ]

    supervise(children, strategy: :one_for_one)
  end

  def stop do
    Supervisor.stop(@name)
  end
end
