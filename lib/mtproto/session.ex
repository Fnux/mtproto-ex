defmodule MTProto.Session do
  require Logger
  alias MTProto.{Crypto, Registry, Session}
  alias MTProto.Session.{HandlerSupervisor, ListenerSupervisor}

  @table SessionRegistry
  @moduledoc """
  Provide advanced control over sessions.

  ## Session

  ```
  %MTProto.Session{auth_key: <<0, 0, 0, 0, 0, 0, 0, 0>>, b: nil, client: nil,
  dc: nil, dh_prime: nil, g_a: nil, handler: nil, initialized?: false,
  last_msg_id: 0, listener: nil, msg_seqno: 0, new_nonce: nil,
  phone_code_hash: nil, seqno: 0, server_nonce: nil, server_salt: 0, socket: 0,
  user_id: nil}

  ```
  * `:user_id` - Telegram ID of the user
  * `:auth_key` - authorization key, default to `<<0::8*8>>`
  * `server_salt` - default to `0`
  * `:handler` - PID of the process handling messages (parse, dispatch, send);
  * `:listener` - PID of the process listening for incoming messages
  * `:dc` - id of the datacenter used by the session (1,2,3,4,5). See
  `MTProto.DC`
  * `:initialized` - was the session initialized ? (See
  `MTProto.API.init_connection/5`)
  * `:phone_code_hash` - `phone_code_hash` returned when sending code (SMS, call,
  open client)
  * `:seqno` - sequence number
  * `:msg_seqno` - message sequence number
  * `:socket` - socket used to receive and send message (to Telegram's servers)
  """

  defstruct auth_key: <<0::8*8>>,
    server_salt: 0,
    user_id: nil,
    handler: nil,
    listener: nil,
    dc: nil,
    initialized?: false,
    client: nil,
    phone_code_hash: nil,
    last_msg_id: 0,
    seqno: 0,
    msg_seqno: 0,
    socket: 0,
    new_nonce: nil, # auth key computation
    server_nonce: nil, # auth key computation
    g_a: nil, # auth key computation
    b: nil, # auth key computation
    dh_prime: nil #auth key computation

  ####
  # Registry access

  def get(id), do: Registry.get @table, id

  def get_all(), do: Registry.dump @table

  def set(id, value), do: Registry.set @table, id, value

  def update(id, value) do
    session = Session.get id
    Session.set id, struct(session, value)
  end

  def drop(id), do: Registry.drop @table, id

  ###

  @doc """
  Open a new session. `dc_id` is used to select which datacenter to connect,
  `client` is the PID of the process to be notified when receiving new messages.

  Returns the `session_id`.
  """
  def open(dc_id, client \\ nil) do
    session_id = Crypto.rand_bytes(8)
    Session.set session_id, struct(Session, dc: dc_id, client: client)

    {:ok, _} = HandlerSupervisor.pop(session_id, dc_id)
    {:ok, _} = ListenerSupervisor.pop(session_id)
    session_id
  end

  @doc """
  Close the current connection to Telegram's server and open a new one to
  the given DC.

  * `dc_id` - ID of the DC to connect.
  """
  def reconnect(session_id, dc_id) do
    # Update session's DC
    Session.update(session_id, dc: dc_id)

    # Close old socket and open a new one
    :ok = ListenerSupervisor.drop(session_id)
    {:ok, _} = ListenerSupervisor.pop(session_id)

    # Generate a new authorization key if necessary
    if Session.get(session_id).auth_key == <<0::8*8>> do
      Logger.debug "No authorization key found for session #{session_id}.
      Requesting..."
      MTProto.Auth.generate(session_id)
    end
  end

  @doc """
  Close a session given its id. Stop both listener and handler, remove the
  session from the registry.
  """
  def close(session_id) do
    :ok = ListenerSupervisor.drop(session_id)
    :ok = HandlerSupervisor.drop(session_id)
    Session.drop(session_id)
  end

  @doc """
  Send a message to telegram's servers on session `session_id`. Default
  behavior is to send an encrypted message : you can send a plaintext message
  by specifying :plain as third argument.
  """
  def send(session_id, message, type \\ :encrypted) do
    session = Session.get(session_id)
    call = if type == :plain, do: :send_plain, else: :send
    GenServer.call session.handler, {call, message}
  end

  @doc """
  Set the PID (`client`) of the process to be notified when receiving new 
  messages on session `session_id`.
  """
  def set_client(session_id, client) do
    Session.update(session_id, client: client)
  end

  @doc """
  Export `{user_id, auth_key, server_salt}` from a session.
  """
  def export(session_id) do
    session = Session.get(session_id)
    {session.user_id, session.auth_key, session.server_salt}
  end

  @doc """
  Import `user_id`, `auth_key` and `server_salt` to a session.
  """
  def import(session_id, user_id, auth_key, server_salt) do
    Session.update session_id, %{
      user_id: user_id, auth_key: auth_key, server_salt: server_salt
    }
  end
end
