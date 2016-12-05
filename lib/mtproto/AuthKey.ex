defmodule MTProto.AuthKey do
  require Logger
  alias MTProto.TL
  alias MTProto.Crypto
  alias MTProto.Registry
  alias MTProto.TL.Build
  alias MTProto.TL.Parse

  @moduledoc false
  # Process inputs and answers during the generation of the authentification key.

  def resPQ(msg) do
    %{nonce: nonce,
     server_nonce: server_nonce,
     pq: pq,
     server_public_key_fingerprints: key_fingerprint } = msg

    new_nonce = Crypto.rand_bytes(32)
    req_DH_params = TL.req_DH_params(
      nonce,
      server_nonce,
      new_nonce,
      pq,
      Enum.at(key_fingerprint,0))

    Registry.set :new_nonce, new_nonce
    Registry.set :server_nonce, server_nonce
    send :handler, {:send_plain, req_DH_params}
  end

  def server_DH_params_ok(msg) do
    %{encrypted_answer: encrypted_answer,
     server_nonce: server_nonce} = msg

     new_nonce = Registry.get :new_nonce
     # Build keys for decrypting/encrypting AES256 IGE
     {tmp_aes_key, tmp_aes_iv} = Crypto.build_tmp_aes(server_nonce, new_nonce)

     ## Decrypt & parse server_DH_params_ok
     server_DH_params_ok = TL.server_DH_inner_data encrypted_answer, tmp_aes_key, tmp_aes_iv

     %{dh_prime: dh_prime,
      g: g, # g is always equal to 2, 3, 4, 5, 6 or 7
      g_a: g_a,
      nonce: nonce,
      server_nonce: server_nonce,
      server_time: server_time} = server_DH_params_ok

      b = Crypto.rand_bytes(32) # random number
      set_client_DH_params = TL.set_client_DH_params(nonce, server_nonce, g, b, dh_prime, tmp_aes_key, tmp_aes_iv)

      Registry.set :g_a, g_a
      Registry.set :b, b
      Registry.set :dh_prime, dh_prime
      send :handler, {:send_plain, set_client_DH_params}
  end

  def server_DH_params_fail(msg) do
    Logger.error "server_DH_params_fail"
  end

  def dh_gen_ok(msg) do
    server_nonce = Registry.get :server_nonce
    new_nonce = Registry.get :new_nonce
    g_a = Registry.get :g_a
    b = Registry.get :b
    dh_prime = Registry.get :dh_prime

    auth_key = :crypto.mod_pow g_a, b, dh_prime

    # substr(new_nonce, 0, 8) XOR substr(server_nonce, 0, 8)
    salt_left = new_nonce |> Build.encode_signed |> :binary.part(0, 8) |> Parse.decode_signed
    salt_right = server_nonce |> Build.encode_signed |> :binary.part(0, 8) |> Parse.decode_signed
    server_salt = :erlang.bxor salt_left, salt_right


    Registry.set :auth_key, auth_key
    Registry.set :server_salt, server_salt

    Registry.drop [:server_nonce, :new_nonce, :g_a, :b, :dh_prime]

    Logger.info "The authorization key was successfully generated."
  end

  def dh_gen_retry(msg) do
    Logger.error "dh_gen_retry"
  end

  def dh_gen_fail(msg) do
    Logger.error "dh_gen_fail"
  end
end
