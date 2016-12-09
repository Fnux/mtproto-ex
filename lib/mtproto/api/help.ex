defmodule MTProto.API.Help do
  alias MTProto.TL.Build

  @doc """
    Returns info on data centre nearest to the user.
  """
  def get_config do
    Build.payload("help.getConfig", %{})
  end

  @doc """
    Returns current configuration, icluding data center configuration.
  """
  def get_nearest_dc do
    Build.payload("help.getNearestDc",%{})
  end
end
