defmodule MTProto do
  alias MTProto.TL
  alias MTProto.TCP
  alias MTProto.TL.Parse
  alias MTProto.Crypto

  @server "149.154.167.40"
  @port 443

  @moduledoc """
    EXPERIMENTAL!
  """

  @doc """
    Create a socket to Telegram's servers.
  """
  def makeSocket(server \\ @server, port \\ @port) do
    TCP.connect server, port
  end

  @doc """
    Initialize a connection for standard usage.
  """
  def initConnection do
    {_, socket} = makeSocket
    makeAuthKey socket
  end

  @doc """
    Create an Authorization Key.
    See https://core.telegram.org/mtproto/auth_key
  """
  def makeAuthKey(socket) do
    # req_pq
    TL.req_pq |> TCP.wrap |> TCP.send(socket)

    # res_pq
    {_, wrappedResPQ} = TCP.recv(socket)

    resPQ = wrappedResPQ |> :binary.list_to_bin
                         |> TCP.unwrap
                         |> TL.Parse.decode

    %{nonce: nonce,
      server_nonce: server_nonce,
      pq: pq,
      server_public_key_fingerprints: key_fingerprint
    } = resPQ

    # req_DH_params
    new_nonce = MTProto.Crypto.generate_rand 32
    req_DH_params = TL.req_DH_params(nonce, server_nonce, new_nonce, pq, key_fingerprint)
    req_DH_params |> TCP.wrap(1) |> TCP.send(socket)

    # server_DH_params_ok/fail
    {_, wrapped_server_DH_params} = TCP.recv(socket)

    server_DH_params = wrapped_server_DH_params |> :binary.list_to_bin
                                                |> TCP.unwrap
                                                |> TL.Parse.decode
    %{predicate: req_DH,
      encrypted_answer: encrypted_answer,
      server_nonce: server_nonce} = server_DH_params

    if req_DH == "server_DH_params_fail", do: raise "server_DH_params_fail"

    ## Build keys for decrypting/encrypting AES256 IGE
    {tmp_aes_key, tmp_aes_iv} = Crypto.build_tmp_aes(server_nonce, new_nonce)

    ## Decrypt & parse server_DH_params_ok
    server_DH_params_ok = TL.server_DH_inner_data encrypted_answer, tmp_aes_key, tmp_aes_iv

    %{dh_prime: dh_prime,
      g: g, # g is always equal to 2, 3, 4, 5, 6 or 7
      g_a: g_a,
      nonce: nonce,
      server_nonce: server_nonce2,
      server_time: server_time,
    } = server_DH_params_ok

    # set_client_DH_params
    TL.set_client_DH_params(nonce, server_nonce, g, dh_prime, tmp_aes_key, tmp_aes_iv) |> TCP.wrap(2) |> TCP.send(socket)

    # dh_gen_ok/retry/fail
    {_, wrapped_dh_gen} = TCP.recv(socket)

    dh_gen = wrapped_dh_gen |> :binary.list_to_bin
                            #|> TCP.unwrap
  end
end
