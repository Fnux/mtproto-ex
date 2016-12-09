defmodule MTProto.Session.Listener do
  use GenServer
  require Logger
  alias MTProto.Registry
  alias MTProto.TCP

  @port 443

  def start_link(session_id, opts \\ []) do
     GenServer.start_link(__MODULE__, {:start, session_id} , [opts])
  end

  def init({:start, session_id}) do
    # Get the remote address (depends on the DC)
    dc = Registry.get :session, session_id, :dc
    address = Registry.get :main, dc, :address

    # Connect to Telegram's servers
    {:ok, socket} = TCP.connect address, @port

    # Initial TCP sequence number is 0
    seqno = 0

    # Register this listener for the session
    Registry.set :session, session_id, :listener, self

    # Register the socket and the initial seqno in the registry
    Registry.set :session, session_id, :socket, socket
    Registry.set :session, session_id, :seqno, seqno

    # Start the listening loop
    send self, :listen

    {:ok, session_id}
  end

  def handle_info(:listen, session_id) do
    # Get the socket given the session
    socket = Registry.get :session, session_id, :socket

    # Wait for incoming data
    {:ok, data} = TCP.recv(socket)
    Logger.debug "#{session_id} : incoming message."

    # Unwrap
    payload = data |> :binary.list_to_bin
                   |> TCP.unwrap

    # Dispatch to the related handler
    handler = Registry.get :session, session_id, :handler
    send handler, {:recv, payload}

    # Update the sequence number
    seqno = Registry.get(:session, session_id, :seqno)
    Registry.set :session, session_id, :seqno, seqno + 1

    # Loop
    send self, :listen

    {:noreply, session_id}
  end

  def terminate(reason, session) do
    # Close the connection
    TCP.close(Registry.get :session, session, :socket)

    Logger.debug "Terminate listener on session #{session}."
    {:shutdown, reason}
  end
end
