defmodule MTProto do
  require Logger
  alias MTProto.TL
  alias MTProto.TCP
  alias MTProto.TL.Parse
  alias MTProto.TL.Build
  alias MTProto.Crypto
  alias MTProto.Registry

  @server "149.154.167.40"
  @port 80

  @moduledoc """
    EXPERIMENTAL!
  """

  @doc """
    Start the supervision tree. Initialize the procedure to generate 
    an authorization key if no authorization key is stored in the registry.
  """
  def start() do
    MTProto.Supervisor.start

    if Registry.get(:auth_key) == nil do
      Logger.debug "No auth key found, initilizing auth key request"
      send :handler, {:send_plain, TL.req_pq}
    end

    :ok
  end

  @doc """
    Returns the status of the main supervisor.
  """
  def status(), do: MTProto.Supervisor.status()

  @doc """
    Stop the main supervisor.
  """
  def stop(), do: MTProto.Supervisor.stop()

  @doc """
    Create a new session.

    Returns `{:ok, pid}`
  """
  def create_session do
    {status, pid} = MTProto.Session.Supervisor.create_session
  end
end
