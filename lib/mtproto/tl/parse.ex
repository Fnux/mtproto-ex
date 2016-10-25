defmodule MTProto.TL.Parse do
  alias MTProto.TL

  # Parse and deserialize a payload given the constructor
  def decode(data, wrapped \\ :wrapped, struct \\ :constructors) do
    if wrapped == :wrapped, do: data = data |> unwrap

    # Extract constructor and values
    constructor = Map.get data, :constructor
    values = Map.get data, :values

    # Get the structure of the payload
    schema = TL.schema struct
    description = Enum.filter schema, fn
           x -> Map.get(x, "id") |> String.to_integer == constructor
      end

    expected_params = description |> List.first |> Map.get("params")

    # Map & deserialize given the structure
    map = deserialize(expected_params, values, %{})

    # Add the predicate's name to the output, kinda useful
    map |> Map.put :predicate, description |> List.first |> Map.get "predicate"
  end

  # Map and deserialize the values given the structure
  def deserialize([struct | tail], values, map) do
     # Get the name and the type of the value from the structure
     name = Map.get(struct, "name") |> String.to_atom
     type = Map.get(struct, "type") |> String.to_atom

     # Deserialize and map
     {value, reduced_values} = values |> deserialize_from_stream(type)
     extended_map = map |> Map.put name, value

     # Iterate on the next elements
     deserialize tail, reduced_values, extended_map
  end

  # Returns the map once everything was processed
  def deserialize([], _, map), do: map


  # Deserialize given the type and the value
  def deserialize(value, type) do
    {value, _} = deserialize_from_stream value, type
    value
  end

  # Deserialize given the type and a list of values (~)
  def deserialize_from_stream(values, type)  do
      case type do
        :meta4 ->
          {head, tail} = split values, 4
          <<value::little-signed-size(4)-unit(8)>> = head
          {value, tail}
        :meta8 ->
          {head, tail} = split values, 8
          <<value::little-signed-size(8)-unit(8)>> = head
          {value, tail}
        :int ->
          {head, tail} = split values, 4
          <<value::signed-size(4)-little-unit(8)>> = head
          {value, tail}
        :int128 ->
          {head, tail} = split values, 16
          <<value::signed-big-size(16)-unit(8)>> = head
          {value, tail}
        :int256 ->
          {head, tail} = split values, 32
          <<value::signed-big-size(16)-unit(8)>> = head
          {value, tail}
        :long ->
          {head, tail} = split values, 8
          <<value::signed-little-size(8)-unit(8)>> = head
          {value, tail}
        :double ->
          {head, tail} = split values, 8
          <<value::signed-little-size(2)-unit(32)>> = head
          {value, tail}
        :string ->
          {prefix_length, str_length, total_length} = string_length(values)
          serialized_string = :binary.part values, prefix_length, str_length
          tail = :binary.part values, total_length, byte_size(values) - total_length

          string = serialized_string

          {string, tail}
        :bytes -> deserialize_from_stream(values, :string)
        :'Vector<long>' -> # length 1 only, some ugly hotfix
          :binary.part(values, 4 + 4, 8) |> deserialize_from_stream(:long)
        _ -> {values, ""}
      end
  end

  # Unwrap
  def unwrap(data) do
    auth_key_id = :binary.part(data, 0, 8) |> deserialize(:meta8)
    msg_id = :binary.part(data, 8, 8) |> deserialize(:meta8)
    msg_len = :binary.part(data, 16, 4) |> deserialize(:meta4)
    msg = :binary.part(data, 20, msg_len)

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

  # Compute the prefix, content and total (including prefix and padding) length
  # of a serialized string
  # See : https://core.telegram.org/mtproto/serialize#base-types
  def string_length(data) do
    p = fn x ->
      y = (x - Float.floor x)
      case y do
        0.0 -> 0
        _ -> (1-y) * 4 |> round
      end
    end

    <<len::size(1)-unit(8)>> = :binary.part data,0, 1
    if len < 254 do
      div = (1 + len) / 4
      padding = p.(div)
      {1, len, 1+len+padding}
    else
      <<str_len::little-size(3)-unit(8)>> = :binary.part data ,1 ,3
      div = (4 + str_len) / 4
      padding = p.(div)
      {4, str_len, 4 + str_len + padding }
    end
  end

  # Split a binary at p bytes
  def split(value, p) do
    left = :binary.part value, 0, p
    right = :binary.part value, p, byte_size(value) - p
    {left, right}
  end

  # Decode a signed integer
  def decode_signed(bin) do
    len = byte_size bin
    <<int::signed-size(len)-unit(8)>> = bin
    int
  end

  # Change the endianness of a block
  def changeBlockEndianness(blocks, unit), do: blocks |> :binary.bin_to_list
                                                      |> Enum.chunk(unit)
                                                      |> Enum.reverse
                                                      |> :binary.list_to_bin
end
