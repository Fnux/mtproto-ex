defmodule MTProto.Session.Brain do
  alias MTProto.{Session}
  alias MTProto.Session.{Handler, History}
  require Logger

  @moduledoc false

  # Process plain messages
  def process(msg, session_id, :plain) do
    name = Map.get(msg, :name)
    session = Session.get(session_id)
    auth_client = session.auth_client

    if auth_client do
      case name do
        "resPQ" -> send auth_client, {:recv_resPQ, msg}
        "server_DH_params_ok" -> send auth_client, {:recv_server_DH_params_ok, msg}
        "server_DH_params_fail" -> send auth_client, {:recv_server_DH_params_ok, msg}
        "dh_gen_ok" -> send auth_client, {:recv_dh_gen_ok, msg}
        "dh_gen_fail" -> send auth_client, {:recv_dh_gen_fail, msg}
        "dh_gen_retry" -> send auth_client, {:recv_dh_gen_retry, msg}
        _ -> IO.inspect name
      end
    end

    if name == "error" do
      IO.inspect msg
      error_code = Map.get(msg, :code)
      Logger.warn "Received plain error : #{error_code}"
    end
  end

  # Process encrypted messages
  def process(msg, session_id, :encrypted) do
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

  ## Error Handling
  ## See https://core.telegram.org/api/errors

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
end
