defmodule MTProto do
  require Logger
  alias MTProto.Registry

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
    Registry.set :main, :dc1, :address, "0.0.0.0"
    Registry.set :main, :dc2, :address, "149.154.167.40"
    Registry.set :main, :dc3, :address, "0.0.0.0"
    Registry.set :main, :dc4, :address, "0.0.0.0"
    Registry.set :main, :dc5, :address, "0.0.0.0"

    out
  end

  @doc """
  Create a new session and return the PID of the handler.

  Returns `{:ok, pid}`
  """
  def create_session do
    MTProto.Session.Supervisor.pop()
  end

  @doc """
  Send a message on the session related to the handler PID,
  user :plain to send a plain message instead of an encrypted
  one (default).
  """
  def send(pid, message, plain \\ false) do
    unless plain do
      GenServer.call pid, {:send, message}
    else
      GenServer.call pid, {:send_plain, message}
    end
  end
end
