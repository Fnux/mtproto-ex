defmodule MTProtoTest do
  alias MTProto.TCP
  use ExUnit.Case
  doctest MTProto

  test "the truth" do
    assert 1 + 1 == 2
  end

  test "the internet" do
    # Check connectivity
    {status, sock} = TCP.connect("149.154.167.40", 443)
    assert status == :ok
  end

  test "Req_pq response" do
    {:ok, socket} = TCP.connect "149.154.167.40", 443
    MTProto.TL.req_pq |> TCP.wrap(0) |> TCP.send(socket)
    {status, output} = MTProto.TCP.recv(socket, 1000)
    assert status == :ok
  end
end
