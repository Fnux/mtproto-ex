defmodule MTProto.TL.Parse do
  alias MTProto.TL

  def decode(pack) do
    unwrapped = pack |> unwrap
    constructor = Map.get unwrapped, :constructor
    values = Map.get unwrapped, :values

    schema = TL.schema :constructors
    description = Enum.filter schema, fn
           x -> Map.get(x, "id") |> String.to_integer == constructor
      end

    expected_params = description |> List.first |> Map.get("params")
    mapped = deserialize(expected_params, values, %{})
  end

  def deserialize([arg | tail], values, mapped) do
     name = Map.get(arg, "name") |> String.to_atom
     type = Map.get(arg, "type") |> String.to_atom
     value = values |> deserialize(type)
     nmap = mapped |> Map.put name, value
     IO.inspect len(type, values)

     if type == :string || type == :bytes do
       {_,_,len} = len type, values
     else
       len = len type
     end
     IO.puts len
     nvalues = :binary.part values, len, byte_size(values) - len

     deserialize tail, nvalues, nmap
  end

  def deserialize([], _, mapped), do: mapped

  def deserialize(data, type)  do
      len = len(type, data)
      case type do
        :meta4 ->
          <<d::little-unsigned-size(4)-unit(8)>> = part data, len
          d
        :meta8 ->
          <<d::little-signed-size(8)-unit(8)>> = part data, len
          d
        :int128 ->
          <<d::signed-little-size(4)-unit(32)>> = part data, len
          d
        :int256 ->
          <<d::signed-little-size(8)-unit(32)>> = part data, len
          d
        :long ->
          <<d::signed-little-size(2)-unit(64)>> = part data, len
          d
        :double ->
          <<d::signed-little-size(2)-unit(64)>> = part data, len
          d
        :string ->
          {prefix_len, str_len, total_len} = len(:string, data)
          str = part data, prefix_len, str_len
          str
        :bytes -> deserialize(data, :string)
        :'vector<long>' -> # length 1 only
          type = :long
          :binary.part(data, 4+4, len(type)) |> deserialize(type)
         _ -> data
      end
  end

  def len(t, value \\ <<>>) do
    case t do
      :meta4 -> 4
      :meta8 -> 8
      :int -> 4
      :int128 -> 16
      :int256 -> 32
      :long -> 32
      :double -> 32
      :string ->
        <<len::integer-little-size(1)-unit(8)>> = part(value, 1)
        if len < 254 do
          div = (1 + len) / 4
          padding = 1 - (div - Float.floor div) * 4 |> round
          {1, len, 1+len+padding}
        else
          :not_implemented_yet
        end
      :bytes -> len(:string, value)
      _ -> 1
    end
  end

  defp part(data, start \\ 0, len), do: :binary.part(data, start , len)

  def unwrap(pack) do
    auth_key_id = :binary.part(pack, 0, 8) |> deserialize(:meta8)
    msg_id = :binary.part(pack, 8, 8) |> deserialize(:meta8)
    msg_len = :binary.part(pack, 16, 4) |> deserialize(:meta4)
    msg = :binary.part(pack, 20, msg_len)

    constructor = :binary.part(msg, 0, 4) |> deserialize(:meta4)
    values = :binary.part(msg, 4, msg_len - 4)

    %{
      auth_key_id: auth_key_id,
      msg_id: msg_id,
      msg_len: msg_len,
      constructor: constructor,
      values: values
     }
  end
end
