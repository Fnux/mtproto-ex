defmodule MTProto.Session do
  alias MTProto.{Crypto, Registry}

  defstruct handler: nil,
    listener: nil,
    dc: nil,
    initialized?: false,
    client: nil,
    phone_code_hash: nil,
    seqno: 0,
    msg_seqno: 0,
    socket: 0

  def open(dc_id, notifier \\ nil) do
    session_id = Crypto.rand_bytes(8)
    {:ok, _} = MTProto.Session.HandlerSupervisor.pop(session_id, dc_id)
    {:ok, _} = MTProto.Session.ListenerSupervisor.pop(session_id)
    session_id
  end

  def close(session_id) do
    :ok = MTProto.Session.ListenerSupervisor.drop(session_id)
    :ok = MTProto.Session.HandlerSupervisor.drop(session_id)
    Registry.drop :session, session_id
  end

  def send(session_id, message, plain \\ false) do
    session = Registry.get :session, session_id
    type = if plain, do: :send_plain, else: :send
    GenServer.call session.handler, {type, message}
  end

  def set_client(session_id, client) do
    Registry.set(:session, session_id, :client, client)
  end
end
