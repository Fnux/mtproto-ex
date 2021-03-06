defmodule MTProto.DC do
  alias MTProto.{Registry, DC}

  @table DCRegistry
  @dcs [{0, "149.154.167.40"}, # test DC
        {1, "149.154.175.50"},
        {2, "149.154.167.51"},
        {3, "149.154.175.100"},
        {4, "149.154.167.91"},
        {5, "149.154.171.5"}]
  @moduledoc """
  Define a datacenter. Note that all the possible values (indexed in the
  registry) are hardcoded in `MTProto.DC.register/0`.

  * `:id` - id  of the dc
  * `:address` - address of the dc
  * `:port` - port of the dc, default to `443`
  """

  defstruct id: nil,
            address: nil,
            port: 443

  ####
  # Registry access

  def get(id), do: Registry.get @table, id

  def get_all(), do: Registry.dump @table

  def set(id, value), do: Registry.set @table, id, value

  def update(id, value) do
    dc = DC.get id
    DC.set id, struct(dc, value)
  end

  ###

  @doc """
  Register all five DCs in the registry. Values are hardcoded.
  """
  def register do
    for dc <- @dcs do
      {id, addr} = dc
      DC.set id, struct(DC, %{dc: id, address: addr})
    end
  end
end
