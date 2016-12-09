defmodule MTProto.TL.Build do
  alias MTProto.Utils

  @moduledoc """
    MTProto payload builder.
  """

  # Build a payload given a constructor and argument
  def payload(method, args, :plain), do: encode(method, args) |> wrap(:plain)

  # Build an encryptable payload
  def payload(method, args), do: encode(method, args) |> wrap

  # Encode & Serialize
  def encode(method, params, schema \\ :methods) do
     # Get the payload structure
     description = Utils.search schema, method
     expected_params = description |> List.first |> Map.get("params")

     # Map values to their types
     map = Enum.map expected_params,fn x ->
          {
            Map.get(x, "type") |> String.to_atom,
            Map.get(params, String.to_atom Map.get(x, "name"))
          }
        end

     # Serialized values
     serialized_values = map |> Enum.map(fn {type, value} -> serialize(value, type) end)

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
      :int -> <<data::signed-little-size(1)-unit(32)>>
      :int128 -> <<data::signed-big-size(16)-unit(8)>>
      :int256 -> <<data::signed-big-size(32)-unit(8)>>
      :long -> <<data::unsigned-little-size(8)-unit(8)>>
      :double -> <<data::signed-little-size(2)-unit(32)>>
      :string -> serialize_string(data)
      :head4 -> <<data::little-signed-size(4)-unit(8)>>
      :head8 -> <<data::little-signed-size(8)-unit(8)>>
      :bytes ->
        bin = 
          if (is_binary data), do: data, else: encode_signed(data)
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
  defp wrap(data, :plain) do
    auth_id_key = 0
    msg_id = generate_id
    msg_len = byte_size(data)
    serialize(auth_id_key, :head8) <> serialize(msg_id, :head8)
                                   <> serialize(msg_len, :head4)
                                   <> data
  end

  # wrap the data as an encryptable payload
  def wrap(data) do
    msg_id = generate_id
    seq_no = 0 # <- supposed to do something about it
    msg_len = byte_size(data)

    serialize(msg_id, :head8) <> serialize(seq_no, :head4)
                              <> serialize(msg_len, :head4)
                              <> data
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
