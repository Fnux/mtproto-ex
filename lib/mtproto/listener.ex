defmodule MTProto.Listener do
  use GenServer
  require Logger
  alias MTProto.Crypto
  alias MTProto.TCP
  alias MTProto.Registry
  alias MTProto.TL.Parse

  @moduledoc false
  @server "149.154.167.40"
  @port 80

  def start_link(opts \\ []) do
     GenServer.start_link(__MODULE__, :ok, [opts])
  end

  def init(:ok) do
    socket = Registry.get :socket
    if Port.info(socket) == nil do
      {:ok, socket} = TCP.connect(@server, @port)
      Registry.set :socket, socket
      Registry.set :seqno, 0
    end

    send self, :listen
    {:ok, %{}}
  end

  def handle_info(:listen, state) do
    listen()
    {:noreply, state}
  end


  def listen() do
    socket = Registry.get :socket
    {:ok, data} = TCP.recv(socket)

    msg = data |> :binary.list_to_bin
               |> TCP.unwrap

    Registry.set(:seqno, Registry.get(:seqno) + 1)
    Task.async(fn -> dispatch(msg) end)
    listen()
  end

  def dispatch(msg) do
    cond do
      byte_size(msg) == 4 -> Logger.error "Received error : #{msg |> Parse.deserialize(:int)}"
      :binary.part(msg, 0, 8) != <<0::8*8>> ->
        decrypted = msg |> Crypto.decrypt_message(Registry.get(:auth_key))
        session_id = :binary.part(decrypted, 8, 8) |> Parse.deserialize(:int64)
        key = ("session_" <> Integer.to_string(session_id)) |> String.to_atom
        session_handler = Registry.get key
        send session_handler, {:recv, Parse.payload(decrypted)}
      :binary.part(msg, 0, 8) == <<0::8*8>> -> send :handler, {:recv, Parse.payload(msg) }
      true -> Logger.error "Uh?"
    end
  end

  def stop do
    GenServer.stop(self)
  end
end
