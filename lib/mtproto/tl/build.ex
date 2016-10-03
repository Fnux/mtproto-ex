defmodule MTProto.TL.Build do
  alias MTProto.TL

  # Build a payload given a constructor and argumentd
  def payload(method, args), do: encode(method, args) |> wrap(encrypted: false)

  # Encode & Serialize
  def encode(method, params, schema \\ :methods) do
     # Get the payload structure
     description = TL.search schema, method
     expected_params = description |> List.first |> Map.get("params")

     # Map values to their types
     map = Enum.map expected_params,fn x ->
          {
            Map.get(x, "type") |> String.to_atom,
            Map.get(params, String.to_atom Map.get(x, "name"))
          }
        end

     # Serialized values
     serialized_values = map |> Enum.map fn {type, value} -> serialize(value, type) end
     # Seralize the constructor
     serialized_method = description |> List.first
                                     |> Map.get("id")
                                     |> String.to_integer
                                     |> serialize(:head4)

     # Build the final payload
     serialized_method <> :binary.list_to_bin serialized_values
  end

  # Serialize a value given its type
  def serialize(data, type) do
    case type do
      :int -> <<data::signed-size(1)-unit(32)>>
      :int128 -> <<data::signed-big-size(4)-unit(32)>>
      :int256 -> <<data::signed-big-size(8)-unit(32)>>
      :long -> <<data::signed-little-size(2)-unit(32)>>
      :double -> <<data::signed-little-size(2)-unit(32)>>
      :string -> serialize_string(data)
      :head4 -> <<data::little-signed-size(4)-unit(8)>>
      :head8 -> <<data::little-signed-size(8)-unit(8)>>
      :bytes ->
        if (is_binary data) do
          bin = data
        else
          bin = encode_signed data
        end
        serialize_string(bin)
    end
  end

  defp serialize_string(string) do
    len = byte_size string

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
      <<len>> <> string <> <<0::size(padding)-unit(8)>>
    else
      div = (len + 4) / 4
      padding = p.(div)
      <<254>> <> <<len::little-size(3)-unit(8)>> <> string <> <<0::size(padding)-unit(8)>>
    end
  end

  # Wrap the data as an unencrypted MTProto message
  defp wrap(data, encrypted: e) when e == false  do
    auth_id_key = 0
    msg_id = generate_id
    msg_len = byte_size(data)
    serialize(auth_id_key, :head8) <> serialize(msg_id, :head8)
                                   <> serialize(msg_len, :head4)
                                   <> data
  end

  # Wrap the data as an encrypted MTProto message
  defp wrap(data, encrypted: e) when e == true do
    :not_yet_implemented
  end

  # Generate id for messages,  Unix time * 2^32
  defp generate_id do
    :os.system_time(:seconds) * :math.pow(2,32) |> round
  end

  # From int to bin
  def encode_signed(int) do
    size = (:math.log2(abs(int)) + 1) / 8.0 |> Float.ceil |> round
    <<int::signed-size(size)-unit(8)>>
  end
end
