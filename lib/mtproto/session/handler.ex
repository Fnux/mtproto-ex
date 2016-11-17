defmodule MTProto.Session.Handler do
  use GenServer
  require Logger
  alias MTProto.TCP
  alias MTProto.TL.Parse
  alias MTProto.Crypto
  alias MTProto.Registry

  def start(socket, crypto) do
     GenServer.start(__MODULE__, {socket, crypto}, [])
  end

  def init({socket, crypto}) do
    MTProto.Session.Listener.start_link(socket, self)
    session_id = Crypto.rand_bytes(8)
    {:ok, %{socket: socket, sequence: 0, session_id: session_id, crypto: crypto}}
  end

  def handle_info({:recv, msg}, state) do
     session_id = Map.get state, :session_id

     # In the event of an error, the server may send a packet whose payload consists of 4 bytes
     # as the error code.
     unless byte_size(msg) == 4 do
       auth_key_id = :binary.part msg, 0, 8

       # Check if the message is encrypted or not
       if auth_key_id == <<0::8*8>> do
         Logger.info "Receiving unencrypted message on session #{session_id}."
         IO.inspect msg |> Parse.payload
       else
         Logger.info "Receiving encrypted message on session #{session_id}."

         crypto = Map.get(state, :crypto) |> Registry.get
         auth_key = Map.get crypto, :auth_key

         IO.inspect msg |> Crypto.decrypt_message(auth_key) |> Parse.payload
       end

     else
       <<error::signed-little-size(4)-unit(8)>> = msg
       Logger.info "Received error #{error} on session #{session_id}."
     end

    {:noreply, state}
  end

  def handle_info({:send_plain, msg}, state) do
    seq = Map.get state, :sequence
    sock = Map.get state, :socket

    # Send message
    msg |> TCP.wrap(seq) |> TCP.send(sock)

    # Update handler state
    state = Map.put state, :sequence, seq + 1
    {:noreply, state}
  end

  def handle_info({:send, payload}, state) do
    seq = Map.get state, :sequence
    sock = Map.get state, :socket
    session_id = Map.get state, :session_id
    crypto = Map.get(state, :crypto) |> Registry.get

    auth_key = Map.get crypto, :auth_key
    server_salt = Map.get crypto, :server_salt

    # Encrypt and send message
    encrypted_msg = Crypto.encrypt_message(auth_key, server_salt, session_id, payload)
    encrypted_msg |> TCP.wrap(seq) |> TCP.send(sock)

    # Update handler state
    state = Map.put state, :sequence, seq + 1
    {:noreply, state}
  end

  def stop(pid) do
    GenServer.stop(pid)
  end
end
