defmodule MTProto.TL.Parse do
  alias MTProto.TL
  alias MTProto.Utils

  @moduledoc """
    MTProto payload parser.
  """

  # Parse a payload
  def payload(data) do
    auth_key_id = :binary.part(data, 0, 8)

    # Unwrap the message, given if it was encrypted or not
    map =
      unless auth_key_id == <<0::8*8>> do
        data |> unwrap
      else
        data |> unwrap(:plain)
      end

    constructor = Map.get map, :constructor
    message_content = Map.get map, :message_content

    # Get message's schema
    schema = scan(constructor)

    # Buld and return a map of the content
    decode(message_content, schema)
  end

  # Unwrap a message (encryptable)
  def unwrap(data) do
    salt = :binary.part(data, 0, 8) |> deserialize(:long)
    session_id = :binary.part(data, 8, 8) |> deserialize(:long)
    message_id = :binary.part(data, 16, 8) |> deserialize(:long)
    seq_no =:binary.part(data, 24, 4) |> deserialize(:int)
    message_data_length =  :binary.part(data, 28, 4) |> deserialize(:int)
    message_data = :binary.part(data, 32, message_data_length)

    constructor = :binary.part(message_data, 0, 4) |> deserialize(:int)
    message_content = :binary.part(message_data, 4, message_data_length - 4)

    %{
      salt: salt,
      session_id: session_id,
      message_id: message_id,
      seq_no: seq_no,
      messsage_data_length: message_data_length,
      constructor: constructor,
      message_content: message_content
    }
  end

  # Unwrap a plaintext message
  def unwrap(data, :plain) do
    auth_key_id = :binary.part(data, 0, 8) |> deserialize(:long)
    messsage_id = :binary.part(data, 8, 8) |> deserialize(:long)
    message_data_length = :binary.part(data, 16, 4) |> deserialize(:int)
    message_data = :binary.part(data, 20, message_data_length)

    constructor = :binary.part(message_data, 0, 4) |> deserialize(:int)
    message_content = :binary.part(message_data, 4, message_data_length - 4)

    %{
      auth_key_id: auth_key_id,
      message_id: messsage_id,
      message_data_length: message_data_length,
      constructor: constructor,
      message_content: message_content
     }
  end

  # Extract the schema
  def scan(constructor, struct \\ :constructors) do

    # Get the structure of the payload
    schema = Utils.schema struct
    description = Enum.filter schema, fn
           x -> Map.get(x, "id") |> String.to_integer == constructor
      end

    description
  end

  # Decode given a schema
  def decode(data, schema) do
    expected_params = schema |> List.first |> Map.get("params")

    {_, map} = extract(expected_params, data)

    map |> Map.put(:predicate, schema |> List.first |> Map.get("predicate"))
  end

  # Extract
  def extract([], data_tail, map), do: {data_tail, map}
  def extract([schema_head | schema_tail], data, map \\ %{}) do
    # Get the name and the type of the value from the structure
    name = Map.get(schema_head, "name") |> String.to_atom
    type = Map.get(schema_head, "type") |> String.to_atom

    # Deserialize and map
    {value, data_tail} = deserialize(:pack, data, type)
    map = map |> Map.put(name, value)

    # Iterate on the next elements
    extract schema_tail, data_tail, map
  end

  # deserialize
  defp deserialize(:pack, data, type) do
    case type do
      # Basic types
      :int ->
        {head, tail} = binary_split(data, 4)
        <<value::signed-size(4)-little-unit(8)>> = head
        {value, tail}
      :int64 ->
        {head, tail} = binary_split(data, 8)
        <<value::signed-big-size(8)-unit(8)>> = head
        {value, tail}
      :int128 ->
        {head, tail} = binary_split(data, 16)
        <<value::signed-big-size(16)-unit(8)>> = head
        {value, tail}
      :int256 ->
        {head, tail} = binary_split(data, 32)
        <<value::signed-big-size(16)-unit(8)>> = head
        {value, tail}
      :long ->
        {head, tail} = binary_split(data, 8)
        <<value::signed-little-size(8)-unit(8)>> = head
        {value, tail}
      :double ->
        {head, tail} = binary_split(data, 8)
        <<value::signed-little-size(2)-unit(32)>> = head
        {value, tail}
      :string ->
        {prefix_length, string_length, total_length} = string_length(data)
        string = :binary.part(data, prefix_length, string_length)
        tail = :binary.part(data, total_length, byte_size(data) - total_length)
        {string, tail}

      # Bytes are handled as strings
      :bytes ->
        deserialize(:pack, data, :string)

      # Anything else. Either a vector or a boxed type
      _ ->
        if Atom.to_string(type) =~ ~r/^vector/ui do
          deserialize(:vector, data, type)
        else
          deserialize(:boxed, data, type)
        end
    end
  end

  # Deserialize a vector
  defp deserialize(:vector, data, type) do
    # Extract internal type (:Vector<type>)
    type = Atom.to_string(type) |> String.split(~r{<|>})
                                |> Enum.at(1)
                                |> String.to_atom

    # check vector id, size & offset
    vector = :binary.part(data, 0, 4) |> deserialize(:int)
    {size, offset} =
      if (vector == 0x1cb5c415) do
        {:binary.part(data, 4, 4) |> deserialize(:int), 8}
      else
        {:binary.part(data, 0, 4) |> deserialize(:int), 4}
      end

    {value, tail} = deserialize(:vector, :binary.part(data, offset, byte_size(data) - offset), size, type)
  end

  defp deserialize(:vector, tail, 0, type, values), do: {values, tail}
  defp deserialize(:vector, data, size, type, values \\ []) do
    {value, tail} = deserialize(:pack, data, type)
    values = values ++ [value]

    # loop
    size = size - 1
    deserialize(:vector, tail, size, type, values)
  end

  # Deserialize a boxed element
  defp deserialize(:boxed, data, type) do
    type = Atom.to_string(type) |> String.replace("%","")
    {schema, description, offset} =
      unless (type == "Object") do
      # Get schema
      schema = Utils.schema :constructors
      description = Enum.filter schema, fn
        x -> Map.get(x, "type") == type
      end

      {schema, description, 0}
      else
        type = :binary.part(data, 0, 4) |> deserialize(:int)
        schema = Utils.schema :constructors
        description = Enum.filter schema, fn
          x -> Map.get(x, "id") |> String.to_integer == type
        end
        {schema, description, 4}
      end

      expected_params = description |> List.first |> Map.get("params")
      {tail, map} = extract(expected_params, :binary.part(data, offset, byte_size(data) - offset))
      map = map |> Map.put(:predicate, description |> List.first |> Map.get("predicate"))

      {map, tail}
  end

  # Deserialize a single element
  def deserialize(value, type) do
    {value, _} = deserialize(:pack, value, type)
    value
  end

  # Compute the prefix, content and total (including prefix and padding) length
  # of a serialized string
  # See : https://core.telegram.org/mtproto/serialize#base-types
  defp string_length(data) do
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

  # Split a binary
  defp binary_split(binary, index) do
    left = :binary.part binary, 0, index
    right = :binary.part binary, index, byte_size(binary) - index
    {left, right}
  end

  # Decode a signed integer
  def decode_signed(binary) do
    binary_length = byte_size binary
    <<int::signed-size(binary_length)-unit(8)>> = binary
    int
  end
end
