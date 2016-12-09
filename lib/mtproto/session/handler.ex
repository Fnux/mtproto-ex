defmodule MTProto.Session.Handler do
  require Logger
  alias MTProto.TCP
  alias MTProto.Registry
  alias MTProto.TL.Parse
  alias MTProto.TL.Build
  alias MTProto.Crypto
  alias MTProto.Session.Brain

  @moduledoc false

  def start_link(session_id) do
    GenServer.start(__MODULE__, session_id, [])
  end

  # Initialize the handler
  def init(session_id) do
    Registry.set :session, session_id, :handler, self
    Registry.set :session, session_id, :dc, :dc2
    Registry.set :session, session_id, :msg_seqno, 0

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
    socket = Registry.get :session, session_id, :socket
    seqno = Registry.get :session, session_id, :seqno

    Logger.debug "#{session_id} : sending plain message."
    payload |> TCP.wrap(seqno) |> TCP.send(socket)
  end

  def send_encrypted(payload, session_id) do
    dc = Registry.get :session, session_id, :dc
    auth_key = Registry.get :main, dc, :auth_key
    server_salt = Registry.get :main, dc, :server_salt

    if auth_key != nil && auth_key != 0 do
      socket = Registry.get :session, session_id, :socket
      seqno = Registry.get :session, session_id, :seqno

      # Set the msg_seqno
      msg_seqno = (Registry.get(:session, session_id, :msg_seqno) * 2 + 1) |> Build.serialize(:int)
      payload = :binary.part(payload, 0, 8) <> msg_seqno
                                            <> :binary.part(payload, 12, byte_size(payload) - 12)

      encrypted_msg = Crypto.encrypt_message(auth_key, server_salt, session_id, payload)
      Logger.debug "#{session_id} : sending encrypted message."
      encrypted_msg |> TCP.wrap(seqno) |> TCP.send(socket)
    else
      {:error, "Auth key does not exist"}
    end
  end

  # Receive a message, parse and dispatch.
  def handle_info({:recv, payload}, session_id) do
    cond do
      # Error message (4 bytes)
      byte_size(payload) == 4 ->
        error = :binary.part(payload, 0, 4) |> Parse.deserialize(:int)
        Logger.error "#{session_id} : received error #{error}."
        Brain.process_plain(%{predicate: "error", code: error}, session_id)
      byte_size(payload) >= 8 ->
        auth_key = :binary.part(payload, 0, 8)

        # authorization key composed of 8 <<0>> : plain message.
        if auth_key == <<0::8*8>> do
          Logger.debug("#{session_id} : received plain message.")
          payload |> Parse.payload |> Brain.process_plain(session_id)
        else
          # Encrypted message
          Logger.debug("#{session_id} : received encrypted message.")
          dc = Registry.get :session, session_id, :dc
          auth_key = Registry.get :main, dc, :auth_key

          decrypted = payload |> Crypto.decrypt_message(auth_key)
          msg_seqno = :binary.part(decrypted, 24, 4) |> Parse.deserialize(:int)
          Registry.set(:session, session_id, :msg_seqno, msg_seqno)
          decrypted |> Parse.payload
                    |> Brain.process_encrypted(session_id)
        end
      true ->
        Logger.error "#{session_id} : received unknow message."
    end

    {:noreply, session_id}
  end

  def terminate(reason, state) do
    Logger.error "Session #{Integer.to_string state} is terminating!"
    IO.inspect reason
  end
end
