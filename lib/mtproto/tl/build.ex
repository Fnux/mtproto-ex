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
     #serialized_values |> Enum.map fn x -> IO.puts byte_size x end
     serialized_data = serialized_method <> :binary.list_to_bin serialized_values

  end

  def payload(method, args), do: encode(method, args) |> wrap(encrypted: false)

  def serialize(type, data) do
    case type do
      :int -> <<data::signed-size(1)-unit(32)>>
      :int128 -> <<data::signed-big-size(4)-unit(32)>>
      :int256 -> <<data::signed-big-size(8)-unit(32)>>
      :long -> <<data::signed-little-size(2)-unit(32)>>
      :double -> <<data::signed-little-size(2)-unit(32)>>
      :string ->
        len = String.length data
        pack(data, len)
      :meta4 -> <<data::little-signed-size(4)-unit(8)>>
      :meta8 -> <<data::little-signed-size(8)-unit(8)>>
      :bytes ->
        if (is_binary data) do
          bin = data
        else
          bin = :binary.encode_unsigned data
        end
        len = byte_size bin
        pack(bin, len)
    end
  end

  defp pack(data, len) do
    p = fn x ->
      y = (x - Float.floor x)
      case y do
        0.0 -> 0
        _ -> (1-y) * 4 |> round
      end
    end

    if len <= 253 do
      div = (len + 1) / 4
      padding = p.(div)
      <<len>> <> data <> <<0::size(padding)-unit(8)>>
    else
      div = (len + 4) / 4
      padding = p.(div)
      <<254>> <> <<len::size(3)-unit(8)>> <> data <> <<0::size(padding)-unit(8)>>
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

  # From int to bin
  def encode_signed(int) do
    size = (:math.log2(abs(int)) + 1) / 8.0 |> Float.ceil |> round
    <<int::signed-size(size)-unit(8)>>
  end
end
