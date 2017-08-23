defmodule MTProto.Session.Handler do
  alias MTProto.{TCP, Crypto, Session, Payload}
  alias MTProto.Session.Brain
  require Logger
  require Integer

  @moduledoc false

  def start_link(session_id, dc_id) do
    GenServer.start_link(__MODULE__, {session_id, dc_id}, [])
  end

  # Initialize the handler
  def init({session_id, dc_id}) do
    Logger.debug "[Handler] #{session_id} : starting handler."

    Session.update session_id, %{handler: self(), dc: dc_id}

    {:ok, session_id}
  end

  # Receive a message, parse and dispatch.
  def handle_info({:recv, payload}, session_id) do
    session = Session.get(session_id)
    cond do
      # MTProto error message (4 bytes). Do no confuse with RPC errors !
      byte_size(payload) == 4 ->
        error = :binary.part(payload, 0, 4) |> TL.deserialize(:int)
        Brain.process(%{name: "error", code: error}, session_id, :plain)
      # Proper messages
      byte_size(payload) >= 8 ->
        auth_key = :binary.part(payload, 0, 8)

        # authorization key composed of 8 <<0>> : plain message.
        {map, scheme} = if auth_key == <<0::8*8>> do
          {map, _} = payload |> Payload.parse(:plain)
          {map, :plain}
        else
          decrypted = payload |> Crypto.decrypt_message(session.auth_key)
          #msg_seqno = :binary.part(decrypted, 24, 4) |> TL.deserialize(:int)

          {map, _} = decrypted |> Payload.parse(:encrypted)
          {map, :encrypted}
        end

        if Map.get(map, :msg_seqno) do
          Session.set session_id, struct(session, msg_seqno: map.msg_seqno)
        end

        msg_id = Map.get map, :msg_id
        Session.set session_id, struct(session, last_msg_id: msg_id)
        Brain.process(map, session_id, scheme)
      true ->
        Logger.debug "[Handler] #{session_id} : received unknow message."
    end

    {:noreply, session_id}
  end

  # Send a plain message
  def handle_call({:send_plain, payload}, _from,  session_id) do
    {status, info} = send_plain(payload, session_id)
    {:reply, {status, info}, session_id}
  end

  # Send an encrypted_message
  def handle_call({:send, payload}, _from, session_id) do
    {status, info} = send_encrypted(payload, session_id)
    {:reply, {status, info}, session_id}
  end

  def send_plain(payload, session_id) do
    session = Session.get(session_id)

    msg_id = Payload.generate_id
    auth_key = 0

    packet = TL.serialize(auth_key, :long) <> Payload.wrap(payload, msg_id)
    packet |> TCP.wrap(session.seqno) |> TCP.send(session.socket)

    # Update the sequence number
    Session.set session_id, struct(session, seqno: session.seqno + 1)

    {:ok, msg_id}
  end

  def send_encrypted(payload, session_id) do
    session = Session.get session_id

    msg_id = Payload.generate_id()
    msg_id = if msg_id <= session.last_msg_id do # workaround for issue #2
      Logger.warn "Message ID overlap ! Generating with offset..."
      (session.last_msg_id + 4 ) |> Payload.fix_id()
    else
      msg_id
    end

    # Wrap as encrypted message
    msg_seqno = if Integer.is_even(session.msg_seqno) do
      session.msg_seqno + 1
    else
      session.msg_seqno + 2
    end

    #IO.puts "Sending with MSG_ID: #{msg_id} and SEQNO #{msg_seqno}"
    payload = Payload.wrap(payload, msg_id, msg_seqno)

    if session.auth_key != <<0::8*8>> && session.auth_key != nil do
      encrypted_msg = Crypto.encrypt_message(session.auth_key, session.server_salt, session_id, payload)
      encrypted_msg |> TCP.wrap(session.seqno) |> TCP.send(session.socket)

      # Update the sequence numbers
      map = %{msg_seqno: msg_seqno, seqno: session.seqno + 1}

      Session.set session_id, struct(session, map)

      {:ok, msg_id}
    else
      {:err, "Auth key does not exist"}
    end
  end

  def terminate(_reason, state) do
    Logger.debug "[Handler] #{state} : terminating handler."
    {:error, state}
  end
end
