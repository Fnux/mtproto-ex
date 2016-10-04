defmodule MTProto.Crypto do
  alias MTProto.TL.Build

  @key "priv/public.key"

  # Get the components of the server's public key
  def get_key do
    {_, key} = File.read @key
    [raw] = :public_key.pem_decode key
    {_,n,e} = :public_key.pem_entry_decode raw
    {e ,n}
  end

  # Build kyes for decrypting/encrypting AES256 IGE (makeAuthKey)
  def build_tmp_aes(server_nonce, new_nonce) do
    # From int to bits
    server_nonce = server_nonce |> Build.encode_signed
    new_nonce = new_nonce |> Build.encode_signed

    # tmp_aes_key := SHA1(new_nonce + server_nonce) 
    # + substr (SHA1(server_nonce + new_nonce), 0, 12);
    tmp_aes_key = :crypto.hash(:sha, new_nonce <> server_nonce)
                  <> :binary.part :crypto.hash(:sha, server_nonce <> new_nonce), 0, 12

    # tmp_aes_iv := substr (SHA1(server_nonce + new_nonce), 12, 8)
    # + SHA1(new_nonce + new_nonce) + substr (new_nonce, 0, 4);
    tmp_aes_iv = :binary.part(:crypto.hash(:sha, server_nonce <> new_nonce), 12, 8)
                 <> :crypto.hash(:sha, new_nonce <> new_nonce)
                 <> :binary.part(new_nonce, 0, 4)

    {tmp_aes_key, tmp_aes_iv}
  end

  # Generate a random number of lenth n
  def generate_rand(n) do
    :math.pow(10, n) - 1 |> round |> :rand.uniform
  end

  # Compute GCD
  def gcd(a,0), do: abs(a)
  def gcd(a,b), do: gcd(b, rem(a,b))

  # Decompose PQ (Pollard's rho algorithm)
  def decompose_pq(n) do
    x = :rand.uniform(n-1)
    y = x
    c = :rand.uniform(n-1)
    g = 1

    decompose_pq(x,y,g,c,n)
  end

  defp decompose_pq(x,y,g,c,n) when g == 1 do
    f = fn(e) -> (rem(e*e,n) + c) |> rem(n) end

    x = f.(x)
    y = f.(f.(y))
    g = abs(x-y) |> gcd(n)

    decompose_pq(x,y,g,c,n)
  end

  defp decompose_pq(_,_,g,_,_), do: g
end
