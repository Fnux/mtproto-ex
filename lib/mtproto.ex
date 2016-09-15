defmodule MTProto do
  alias MTProto.TL
  alias MTProto.TCP
  alias MTProto.TL.Parse

  @server "149.154.167.40"
  @port 443

  def init do
    {_, socket} = TCP.connect @server, @port
    TL.req_pq |> TCP.wrap |> TCP.send(socket)
    {_, packet} = TCP.recv(socket)
    resPQ = packet |> :binary.list_to_bin
                   |> TCP.unwrap
                   |> TL.Parse.decode

    TL.req_DH_params(resPQ) |> TCP.wrap(1) |> TCP.send(socket)
    {_, packet} = TCP.recv(socket)

    #server_DH_params = packet |> :binary.list_to_bin
    #                          |> TCP.unwrap
    #                          |> TL.Parse.decode

  end
end
