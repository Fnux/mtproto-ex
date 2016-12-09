defmodule MTProto do
  require Logger
  alias MTProto.Registry

  @moduledoc """
  EXPERIMENTAL!
  """

  @doc """
  Start the supervision tree.
  """
  def start(_type, _args) do
    out = MTProto.Supervisor.start_link

    # Register DCs
    Registry.set :main, :dc1, :address, "0.0.0.0"
    Registry.set :main, :dc2, :address, "149.154.167.40"
    Registry.set :main, :dc3, :address, "0.0.0.0"
    Registry.set :main, :dc4, :address, "0.0.0.0"
    Registry.set :main, :dc5, :address, "0.0.0.0"

    out
  end

  @doc """
  Create a new session.

  Returns `{:ok, pid}`
  """
  def create_session do
    MTProto.Session.Supervisor.pop()
  end

  def send(pid, message, plain \\ false) do
    unless plain do
      GenServer.call pid, {:send, message}
    else
      GenServer.call pid, {:send_plain, message}
    end
  end

  # if Registry.get(:auth_key) == nil do
  #  Logger.debug "No auth key found, initilizing auth key request"
  #  send :handler, {:send_plain, TL.req_pq}
  #end
 end
