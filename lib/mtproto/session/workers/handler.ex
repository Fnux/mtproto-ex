defmodule MTProto.Session.Workers.Handler do
  alias MTProto.{TCP, Crypto, Session, Payload}
  alias MTProto.Session.Workers.{History, Handler}
  require Logger
  require Integer

  @moduledoc false

  def start_link(session_id) do
    GenServer.start_link(__MODULE__, session_id, [])
  end

  # Initialize the handler
  def init(session_id) do
    Logger.debug "[Handler] #{session_id} : starting handler."

    Session.update session_id, %{handler: self()}

    {:ok, session_id}
  end

  ###
  # Sending

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

  ###

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

    if session.auth_key != <<0::8*256>> do
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

  ###
  # Receiving

  def handle_info({:recv, payload}, session_id) do
    session = Session.get(session_id)
    cond do
      # MTProto error message (4 bytes). Do no confuse with RPC errors !
      byte_size(payload) == 4 ->
        error = :binary.part(payload, 0, 4) |> TL.deserialize(:int)
        process(:plain, %{name: "error", code: error}, session_id)
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
        process(scheme, map, session_id)
      true ->
        Logger.debug "[Handler] #{session_id} : received unknow message."
    end

    {:noreply, session_id}
  end

  ###

  def process(:plain, msg, session_id) do
    name = Map.get(msg, :name)
    session = Session.get(session_id)
    auth_client = session.auth_client

    case name do
      "resPQ" -> send auth_client, {:recv_resPQ, msg}
      "server_DH_params_ok" -> send auth_client, {:recv_server_DH_params_ok, msg}
      "server_DH_params_fail" -> send auth_client, {:recv_server_DH_params_ok, msg}
      "dh_gen_ok" -> send auth_client, {:recv_dh_gen_ok, msg}
      "dh_gen_fail" -> send auth_client, {:recv_dh_gen_fail, msg}
      "dh_gen_retry" -> send auth_client, {:recv_dh_gen_retry, msg}
      "error" ->
        error_code = Map.get(msg, :code)
        Logger.warn "Received plain error : #{error_code}"
      _ -> Logger.warn "Received (plain) unhandled structure : #{name}"
    end
  end

  def process(:encrypted, msg, session_id) do
    session = Session.get(session_id)
    name = Map.get(msg, :name)

    # Process RPC
    case name do
      "rpc_result" ->
        req_msg_id = Map.get(msg, :req_msg_id)
        result = Map.get msg, :result
        name = result |> Map.get(:name)

        case name do
          "auth.sentCode" ->
            hash = Map.get result, :phone_code_hash
            Session.update(session_id, phone_code_hash: hash)
          "auth.authorization" ->
            Logger.debug "Session #{session_id} is now logged in !"
            user_id = Map.get(result, :user) |> Map.get(:id)
            Session.update(session_id, user_id: user_id)
          "rpc_error" -> handle_rpc_error(session_id, result)
          _ -> :noop
        end

        # Remove req_msg_id from 'sent' queue
        History.drop session_id, req_msg_id

        # ACK
        msg_ids = [Map.get(msg, :msg_id)]
        ack = MTProto.Method.msgs_ack(msg_ids)
        Handler.send_encrypted(ack, session_id)
      "bad_msg_notification" ->
        bad_msg_id = Map.get(msg, :bad_msg_id)
        error_code = Map.get(msg, :error_code)

        case error_code do
          32 -> Logger.warn "msg_seqno too low : #{msg.bad_msg_id}"
          33 -> Logger.warn "msg_seqno too high : #{msg.bad_msg_id}"
          _ -> :noop
        end

        retry(session_id, bad_msg_id)
      "bad_server_salt" ->
        new_server_salt = Map.get(msg, :new_server_salt)
        bad_msg_id = Map.get(msg, :bad_msg_id)

        # Note : store server_salt in serialized 'long' (little endian) in order
        # to avoid endianess hell
        Session.update session_id, server_salt: TL.serialize(new_server_salt, :long)

        retry(session_id, bad_msg_id)
      _ -> :noop
    end

    # Notify the client
    if session.client != nil do
      send session.client, {:tg, session_id, msg}
    else
      IO.puts "No client for #{session_id}, printing to console."
      IO.inspect {session_id, msg}, limit: :infinity
    end
  end

  # Handle errors for encrypted messages
  defp handle_rpc_error(_session_id, rpc_result) do
    error_code = Map.get(rpc_result, :error_code)
    error_message = Map.get(rpc_result, :error_message)

    Logger.warn "[MT][Brain] RPC error : #{error_code} | #{error_message}"
    case error_code do
      _ -> :noop
    end
  end

  def retry(session_id, bad_msg_id) do
    # Get 'bad' message content
    result = History.get(session_id, bad_msg_id)
    unless result do
      Logger.warn("Error for message #{bad_msg_id} but not found in session history !")
    else
      {retry_count, content} = result

      History.drop session_id, bad_msg_id # Remove existing message from history
      if retry_count > 0 do
        # Resend
        {:ok, new_msg_id} = Handler.send_encrypted(content, session_id)
        History.put session_id, new_msg_id, {retry_count - 1, content}
      end
    end
  end

  ###
  # Terminate

  def terminate(_reason, state) do
    Logger.debug "[Handler] #{state} : terminating handler."
    {:error, state}
  end
end
