defmodule MTProto.Session.Listener do
  use GenServer
  alias MTProto.TCP

  def start(socket, handler) do
     GenServer.start(__MODULE__, {socket, handler}, [])
  end

  def init({socket, handler}) do
    send self, :listen
    {:ok, {socket, handler}}
  end

  def listen(socket, handler) do
    {:ok, data} = TCP.recv(socket)

    msg = data |> :binary.list_to_bin
               |> TCP.unwrap

    send handler, {:recv, msg}
    listen(socket, handler)
  end

  def handle_info(:listen, {socket, handler}) do
    listen(socket, handler)
    {:noreply, {socket, handler}}
  end

  def stop do
    GenServer.stop(self)
  end
end
