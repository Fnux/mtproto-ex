defmodule MTProto.Session.Listener do
  alias MTProto.{TCP, Session, DC}
  require Logger
  use GenServer

  @moduledoc false

  def start_link(session_id, opts \\ []) do
     GenServer.start_link(__MODULE__, {:start, session_id} , [opts])
  end

  # Initialize the listener
  def init({:start, session_id}) do
    Logger.debug "[Listener] #{session_id} : starting listener."
    session = Session.get(session_id)
    dc = DC.get(session.dc)

    # Connect to Telegram's servers
    {:ok, socket} = TCP.connect dc.address, dc.port

    # Register listener and socket
    map = %{seqno: 0, msg_seqno: 0, listener: self(), socket: socket}
    Session.set session_id, struct(session, map)

    # Start the listening loop
    send self(), :listen

    {:ok, session_id}
  end

  # Listening loop
  def handle_info(:listen, session_id) do
    # Get session
    session = Session.get(session_id)

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
    session = Session.get(session_id)

    # Close the connection
    TCP.close(session.socket)

    case reason do
      :shutdown -> {:shutdown, reason}
      :normal -> {:normal, reason}
      _ -> {:error, reason}
    end
  end
end
