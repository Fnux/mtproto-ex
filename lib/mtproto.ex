defmodule MTProto do
  require Logger
  alias MTProto.Registry
  alias MTProto.DC

  @moduledoc """
  /!\ EXPERIMENTAL /!\

  This module provides a basics methods to deal with
  sessions and send messages.
  """

  @doc """
    Start the supervision tree and register default values.
    Automatically started.
  """
  def start(_type, _args) do
    out = MTProto.Supervisor.start_link

    # Register DCs
    Registry.set :dc, 1, %DC{id: 1, address: "149.154.175.50"}
    Registry.set :dc, 2, %DC{id: 2, address: "149.154.167.51"}
    Registry.set :dc, 3, %DC{id: 3, address: "149.154.175.100"}
    Registry.set :dc, 4, %DC{id: 4, address: "149.154.167.91"}
    Registry.set :dc, 1, %DC{id: 5, address: "149.154.171.5"}

    out
  end
end
