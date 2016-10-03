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
end
