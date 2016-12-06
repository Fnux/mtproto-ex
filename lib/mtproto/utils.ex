defmodule MTProto.Utils do
  @tl_schema "priv/mtproto.json"
  @api_layer "priv/api_layer_23.json"

  # Parse the MTProto TL-schema and output a map.
  def schema(type \\ :methods) do
    type = Atom.to_string type
    {:ok, tl_schema_json} = File.read @tl_schema
    {:ok, api_layer_json} = File.read @api_layer
    {:ok, tl_schema} = JSON.decode tl_schema_json
    {:ok, api_layer} = JSON.decode api_layer_json
    tl_schema[type] ++ api_layer[type]
  end

  # Search in the MTProto TL-schema.
  def search(type, name) do
    schema = schema(type)
    field =
      case type do
        :methods -> "method"
        :constructors -> "predicate"
      end

    description = Enum.filter schema, fn
          x -> Map.get(x, field) == name
    end

    description
  end
end
