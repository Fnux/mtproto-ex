defmodule MTProto.Math do
  def generate_nonce(length) do
    :math.pow(10, length) - 1 |> round |> :rand.uniform
  end

  # GCD
  def gcd(a,0), do: abs(a)
  def gcd(a,b), do: gcd(b, rem(a,b))

  # Pollard's rho algorithm
  def decompose_pq(n) do
    x = :rand.uniform(n-1)
    y = x
    c = :rand.uniform(n-1)
    g = 1

    pollardRho_loop(x,y,g,c,n)
  end

  defp pollardRho_loop(x,y,g,c,n) when g == 1 do
    f = fn(e) -> (rem(e*e,n) + c) |> rem(n) end

    x = f.(x)
    y = f.(f.(y))
    g = abs(x-y) |> gcd(n)
    pollardRho_loop(x,y,g,c,n)
  end

  defp pollardRho_loop(_,_,g,_,_), do: g
end
