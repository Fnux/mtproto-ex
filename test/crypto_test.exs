defmodule CryptoTest do
  use ExUnit.Case
  doctest MTProto

  @data "test/makeauthkey_test.json"

  setup_all do
    {:ok, json} = File.read @data
    {:ok, data} = JSON.decode json
    data
  end

  test "build_tmp_aes", data do
    # Given
    server_nonce = data["server_nonce"] |> hexStr2Int
    new_nonce = data["new_nonce"] |> hexStr2Int

    # Expected
    expected_tmp_aes_key = data["crypto"]["tmp_aes_key"] |> hexStr2Bytes
    expected_tmp_aes_iv =  data["crypto"]["tmp_aes_iv"] |> hexStr2Bytes

    # Compute
    {tmp_aes_key, tmp_aes_iv} = MTProto.Crypto.build_tmp_aes(server_nonce, new_nonce)

    # Assert
    assert tmp_aes_key  == expected_tmp_aes_key
    assert tmp_aes_iv == expected_tmp_aes_iv
  end

  ###########
  # Helpers #
  ###########

  def hexStr2Bytes(hexStr) do
    Base.decode16!(hexStr, case: :mixed)
  end

  def hexStr2Int(hexStr) do
    hexStr |> hexStr2Bytes |> TL.Binary.decode_signed
  end
end
