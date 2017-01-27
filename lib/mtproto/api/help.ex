defmodule MTProto.API.Help do
  alias MTProto.Payload
  @moduledoc """
  @TODO
  """

  @doc """
    Returns info on data centre nearest to the user.
  """
  def get_config do
    TL.build("help.getConfig", %{})
  end

  @doc """
    Returns current configuration, icluding data center configuration.
  """
  def get_nearest_dc do
    TL.build("help.getNearestDc",%{})
  end
end
