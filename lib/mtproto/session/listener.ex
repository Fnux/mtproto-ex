defmodule MTProto.Session.Listener do
  use GenServer
  require Logger
  alias MTProto.Registry
  alias MTProto.TCP

  @moduledoc false

  def start_link(session_id, opts \\ []) do
     GenServer.start_link(__MODULE__, {:start, session_id} , [opts])
  end

  # Initialize the listener
  def init({:start, session_id}) do
    Logger.debug "[Listener] #{session_id} : starting listener."
    session = Registry.get :session, session_id
    dc = Registry.get :dc, session.dc

    Registry.set :session, session_id, :seqno, 0
    Registry.set :session, session_id, :msg_seqno, 0

    # Connect to Telegram's servers
    {:ok, socket} = TCP.connect dc.address, dc.port

    # Register listener and socket
    Registry.set :session, session_id, :listener, self()
    Registry.set :session, session_id, :socket, socket

    # Start the listening loop
    send self(), :listen

    {:ok, session_id}
  end

  # Listening loop
  def handle_info(:listen, session_id) do
    # Get session
    session = Registry.get :session, session_id

    # Wait for incoming data
    payload = TCP.recv(session.socket)

    # Dispatch to the related handler
    send session.handler, {:recv, payload}

    # Loop
    send self(), :listen

    {:noreply, session_id}
  end

  def terminate(reason, session_id) do
    Logger.debug "[Listener] #{session_id} : terminating listener."

    # Get session
    session = Registry.get :session, session_id

    # Close the connection
    TCP.close(session.socket)

    case reason do
      :shutdown -> {:shutdown, reason}
      :normal -> {:normal, reason}
      _ -> {:error, reason}
    end
  end
end
