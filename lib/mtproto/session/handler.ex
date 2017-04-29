defmodule MTProto.Session.Handler do
  require Logger
  alias MTProto.{TCP, Registry, Crypto, Session, Payload}
  alias MTProto.Session.Brain

  @moduledoc false

  def start_link(session_id, dc_id) do
    GenServer.start_link(__MODULE__, {session_id, dc_id}, [])
  end

  # Initialize the handler
  def init({session_id, dc_id}) do
    Logger.debug "[Handler] #{session_id} : starting handler."

    Registry.set :session, session_id, %Session{handler: self(), dc: dc_id}

    {:ok, session_id}
  end

  # Send a plain message
  def handle_call({:send_plain, payload}, _from, session_id) do
    reply = send_plain(payload, session_id)
    {:reply, reply, session_id}
  end

  # Send an encrypted_message
  def handle_call({:send, payload}, _from, session_id) do
    reply = send_encrypted(payload, session_id)
    {:reply, reply, session_id}
  end

  def send_plain(payload, session_id) do
    session = Registry.get :session, session_id

    msg_id = Payload.generate_id
    auth_key = 0

    packet = TL.serialize(auth_key, :long) <> Payload.wrap(payload, msg_id)
    packet |> TCP.wrap(session.seqno) |> TCP.send(session.socket)

    # Update the sequence number
    Registry.set :session, session_id, :seqno, session.seqno + 1
  end

  def send_encrypted(payload, session_id) do
    session = Registry.get :session, session_id
    dc = Registry.get :dc, session.dc

    msg_id = Payload.generate_id()
    msg_id = if msg_id <= session.last_msg_id do # workaround for issue #2
      Logger.warn "Message ID overlap ! Generating with offset..."
      Payload.generate_id(1)
    else 
      msg_id
    end

    # Wrap as encrypted message
    msg_seqno = (session.msg_seqno * 2 + 1)
    payload = Payload.wrap(payload, msg_id, msg_seqno)

    if dc.auth_key != <<0::8*8>> && dc.auth_key != nil do
      encrypted_msg = Crypto.encrypt_message(dc.auth_key, dc.server_salt, session_id, payload)
      encrypted_msg |> TCP.wrap(session.seqno) |> TCP.send(session.socket)

      # Update the sequence numbers
      Registry.set(:session, session_id, :msg_seqno, session.msg_seqno + 1)
      Registry.set :session, session_id, :seqno, session.seqno + 1
    else
      {:error, "Auth key does not exist"}
    end
  end

  # Receive a message, parse and dispatch.
  def handle_info({:recv, payload}, session_id) do
    session = Registry.get :session, session_id
    cond do
      # Error message (4 bytes)
      byte_size(payload) == 4 ->
        error = :binary.part(payload, 0, 4) |> TL.deserialize(:int)
        Logger.warn "[Handler] #{session_id} : received error #{error}."
        Brain.process(%{name: "error", code: error}, session_id, :plain)
      byte_size(payload) >= 8 ->
        auth_key = :binary.part(payload, 0, 8)

        # authorization key composed of 8 <<0>> : plain message.
        if auth_key == <<0::8*8>> do
          {map, _} = payload |> Payload.parse(:plain)

          msg_id = Map.get map, :msg_id
          Registry.set :session, session_id, :last_msg_id, msg_id

          Brain.process(map, session_id, :plain)
        else
          # Encrypted message
          dc = Registry.get :dc, session.dc

          decrypted = payload |> Crypto.decrypt_message(dc.auth_key)
          msg_seqno = :binary.part(decrypted, 24, 4) |> TL.deserialize(:int)

          {map, _} = decrypted |> Payload.parse(:encrypted)
          msg_id = Map.get map, :msg_id
          Registry.set :session, session_id, :last_msg_id, msg_id

          Brain.process(map, session_id, :encrypted)
        end
      true ->
        Logger.debug "[Handler] #{session_id} : received unknow message."
    end

    {:noreply, session_id}
  end

  def terminate(_reason, state) do
    Logger.debug "[Handler] #{state} : terminating handler."
    {:error, state}
  end
end
