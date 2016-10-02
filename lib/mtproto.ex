defmodule MTProto do
  alias MTProto.TL
  alias MTProto.TCP
  alias MTProto.TL.Parse

  @server "149.154.167.40"
  @port 443

  def makeAuthKey do
    {_, socket} = TCP.connect @server, @port
    TL.req_pq |> TCP.wrap |> TCP.send(socket)
    {_, packet} = TCP.recv(socket)
    resPQ = packet |> :binary.list_to_bin
                   |> TCP.unwrap
                   |> TL.Parse.decode

    {req_DH_payload, new_nonce} = TL.req_DH_params(resPQ)
    req_DH_payload |> TCP.wrap(1) |> TCP.send(socket)
    {_, packet} = TCP.recv(socket)

    %{predicate: req_DH,
      encrypted_answer: encrypted_answer,
      server_nonce: server_nonce} =
                       packet |> :binary.list_to_bin
                              |> TCP.unwrap
                              |> TL.Parse.decode

    if req_DH == "server_DH_params_fail" do
      raise :server_DH_params_fail
    end

    TL.server_DH_params_ok encrypted_answer, server_nonce, new_nonce
  end
end
