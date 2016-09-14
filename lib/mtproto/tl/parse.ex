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
    mapped = deserialize_pack(expected_params, values, %{})
  end

  def deserialize_pack([arg | tail], values, mapped) do
     name = Map.get(arg, "name") |> String.to_atom
     type = Map.get(arg, "type") |> String.to_atom
     {value, len}  = values |> deserialize(type, :len)
     nmap = mapped |> Map.put name, value
     nvalues = :binary.part values, len, byte_size(values) - len

     deserialize_pack tail, nvalues, nmap
  end

  def deserialize_pack([], _, mapped), do: mapped

  def deserialize(data, type, :len)  do
      case type do
        :meta4 ->
          {<<d::little-unsigned-size(4)-unit(8)>>, len} = part data, 4
          {d, len}
        :meta8 ->
          {<<d::little-signed-size(8)-unit(8)>>, len} = part data, 8
          {d, len}
        :int128 ->
          {<<d::signed-little-size(4)-unit(32)>>, len} = part data, 16
          {d, len}
        :int256 ->
          {<<d::signed-little-size(8)-unit(32)>>, len} = part data, 32
          {d, len}
        :long ->
          {<<d::signed-little-size(2)-unit(64)>>, len} = part data, 32
          {d, len}
        :double ->
          {<<d::signed-little-size(2)-unit(64)>>, len} = part data, 32
          {d, len}
        :string -> {data, byte_size(data)} # @TODO
          {data, 0}
        :bytes -> {data, byte_size(data)}
          {data, 0}
         _ -> {data, 0}
      end
  end
  def deserialize(data, type) do
    {value, _} = deserialize data, type, :len
    value
  end

  defp part(data, start \\ 0, len), do: {:binary.part(data, 0 , len), len}

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
