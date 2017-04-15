defmodule MTProto.Session do
  alias MTProto.{Crypto, Registry}

  @moduledoc """
  Provide advanced control over sessions.

  ## Session

  ```
  %MTProto.Session{client: nil, dc: nil, handler: nil, initialized?: false,
  listener: nil, msg_seqno: 0, phone_code_hash: nil, seqno: 0, socket: 0}

  ```

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

  defstruct handler: nil,
    listener: nil,
    dc: nil,
    initialized?: false,
    client: nil,
    phone_code_hash: nil,
    last_msg_id: 0,
    seqno: 0,
    msg_seqno: 0,
    socket: 0

  @doc """
  Open a new session. `dc_id` is used to select which datacenter to connect,
  `client` is the PID of the process to be notified when receiving new messages.

  Returns `session_id`.
  """
  def open(dc_id, client \\ nil) do
    session_id = Crypto.rand_bytes(8)
    {:ok, _} = MTProto.Session.HandlerSupervisor.pop(session_id, dc_id)
    set_client(session_id, client)
    {:ok, _} = MTProto.Session.ListenerSupervisor.pop(session_id)
    session_id
  end

  @doc """
  Close a session given its id. Stop both listener and handler, remove the
  session from the registry.
  """
  def close(session_id) do
    :ok = MTProto.Session.ListenerSupervisor.drop(session_id)
    :ok = MTProto.Session.HandlerSupervisor.drop(session_id)
    Registry.drop :session, session_id
  end

  @doc """
  Send a message to telegram's servers on session `session_id`. Default
  behavior is to send an encrypted message : you can send a plaintext message
  by specifying :plain as third argument.
  """
  def send(session_id, message, type \\ :encrypted) do
    session = Registry.get :session, session_id
    call = if type == :plain, do: :send_plain, else: :send
    GenServer.call session.handler, {call, message}
  end

  @doc """
  Set the PID (`client`) of the process to be notified when receiving new 
  messages on session `session_id`.
  """
  def set_client(session_id, client) do
    Registry.set(:session, session_id, :client, client)
  end
end
