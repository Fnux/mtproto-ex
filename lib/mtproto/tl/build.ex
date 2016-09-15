defmodule MTProto.TL.Build do
  alias MTProto.TL

  def encode(method, params, schema \\ :methods) do
     description = TL.search schema, method
     expected_params = description |> List.first |> Map.get("params")

     mapped = Enum.map expected_params,fn x ->
          {
            Map.get(x, "type") |> String.to_atom,
            Map.get(params, String.to_atom Map.get(x, "name"))
          }
        end

     serialized_values = mapped |> Enum.map fn {t,d} -> serialize(t,d) end
     serialized_method = serialize :meta4, description |> List.first
                                                       |> Map.get("id")
                                                       |> String.to_integer
     serialized_data = serialized_method <> :binary.list_to_bin serialized_values

  end

  def payload(method, args), do: encode(method, args) |> wrap(encrypted: false)

  def serialize(type, data) do
    case type do
      :int -> <<data::signed-size(1)-unit(32)>>
      :int128 -> <<data::signed-little-size(4)-unit(32)>>
      :int256 -> <<data::signed-little-size(8)-unit(32)>>
      :long -> <<data::signed-little-size(2)-unit(64)>>
      :double -> <<data::signed-little-size(2)-unit(64)>>
      :string ->
        len = String.length data

        if String.length data <= 253 do
          div = (len + 1) / 4
          padding = 1 - (div - Float.floor div) * 4
          <<len>> <> data <> <<0::size(padding)-unit(8)>>
        else
          div = (len + 4) / 4
          padding = 1 - (div - Float.floor div) * 4
          <<254>> <> <<len::size(3)-unit(8)>>
                  <> <<data>> 
                  <> <<0::size(padding)-unit(8)>>
        end
      :meta4 -> <<data::little-unsigned-size(4)-unit(8)>>
      :meta8 -> <<data::little-signed-size(8)-unit(8)>>
      :bytes -> data
    end
  end

  defp generate_id do # Unix time * 2^32
    :os.system_time(:seconds) * :math.pow(2,32) |> round
  end

  defp wrap(data, encrypted: e) when e == false  do
    auth_id_key = 0
    msg_id = generate_id
    msg_len = byte_size(data)

    serialize(:meta8, auth_id_key) <> serialize(:meta8, msg_id)
                                   <> serialize(:meta4, msg_len)
                                   <> data
  end

  defp wrap(data, encrypted: e) when e == true do

  end
end
