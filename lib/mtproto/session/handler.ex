defmodule MTProto.Session.Handler do
  require Logger
  alias MTProto.TCP
  alias MTProto.Registry
  alias MTProto.Crypto

  def start_link() do
    GenServer.start(__MODULE__, :ok, [])
  end

  def init(:ok) do
    session_id = Crypto.rand_bytes(8)
    key = ("session_" <> Integer.to_string(session_id)) |> String.to_atom
    Registry.set key, self

    {:ok, session_id}
  end

  def handle_info({:send, payload}, state) do
    seqno = Registry.get :seqno
    socket = Registry.get :socket
    session_id = state

    auth_key = Registry.get :auth_key
    server_salt = Registry.get :server_salt

    # Encrypt and send message
    encrypted_msg = Crypto.encrypt_message(auth_key, server_salt, session_id, payload)
    encrypted_msg |> TCP.wrap(seqno) |> TCP.send(socket)

    {:noreply, state}
  end

  def handle_info({:recv, msg}, state) do
    IO.inspect msg
    {:noreply, state}
  end

  def handle_call(:get_id, _from, state) do
    {:reply, state, state}
  end

  def terminate(reason, state) do
    Logger.error "Session #{Integer.to_string state} is terminating!"
    IO.inspect reason
  end
end
