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
    session = Registry.get :session, session_id
    dc = Registry.get :dc, session.dc

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
    {status, data} = TCP.recv(session.socket)

    if status == :error do
      Process.exit(self(), :error)
    end

    Logger.debug "[Listener] #{session_id} : incoming message."

    # Unwrap
    payload = data |> :binary.list_to_bin
                   |> TCP.unwrap

    # Dispatch to the related handler
    send session.handler, {:recv, payload}

    # Update the sequence number
    Registry.set :session, session_id, :seqno, session.seqno + 1

    # Loop
    send self(), :listen

    {:noreply, session_id}
  end

  def terminate(reason, session_id) do
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
