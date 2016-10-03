defmodule CryptoTest do
  alias MTProto.TL.Build
  use ExUnit.Case
  doctest MTProto

  test "build_tmp_aes" do
    # Given
    server_nonce = 0xA5CF4D33F4A11EA877BA4AA573907330
    new_nonce = 0x311C85DB234AA2640AFC4A76A735CF5B1F0FD68BD17FA181E1229AD867CC024D

    # Expected
    expected_tmp_aes_key = 0xF011280887C7BB01DF0FC4E17830E0B91FBB8BE4B2267CB985AE25F33B527253 |> Build.encode_signed
    expected_tmp_aes_iv = 0x3212D579EE35452ED23E0D0C92841AA7D31B2E9BDEF2151E80D15860311C85DB |> Build.encode_signed

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
end
