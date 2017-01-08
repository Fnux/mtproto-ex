defmodule MTProto.Payload do
  def build(method, args, type \\ :encrypted) do
    TL.build(method, args) |> wrap(type)
  end

  def parse(msg, type \\ :encrypted) do
    auth_key_id = :binary.part(msg, 0, 8)

    # Unwrap the message, given if it was encrypted or not
    map =
      if auth_key_id == <<0::8*8>> do
        msg |> unwrap(:plain)
      else
        msg |> unwrap(:encrypted)
      end

    container = Map.get map, :constructor
    content = Map.get map, :message_content

    TL.parse(container, content)
  end

  defp wrap(msg, :plain) do
    auth_id_key = 0
    msg_id = generate_id()
    msg_len = byte_size(msg)
    TL.serialize(auth_id_key, :meta64) <> TL.serialize(msg_id, :meta64)
                                       <> TL.serialize(msg_len, :meta32)
                                       <> msg
  end

  defp wrap(msg, :encrypted) do
    msg_id = generate_id()
    seq_no = 0 # See the handler
    msg_len = byte_size(msg)

    TL.serialize(msg_id, :meta64) <> TL.serialize(seq_no, :meta32)
                                  <> TL.serialize(msg_len, :meta32)
                                  <> msg
  end

  def unwrap(msg, :plain) do
    auth_key_id = :binary.part(msg, 0, 8) |> TL.deserialize(:long)
    messsage_id = :binary.part(msg, 8, 8) |> TL.deserialize(:long)
    message_data_length = :binary.part(msg, 16, 4) |> TL.deserialize(:meta32)
    message_data = :binary.part(msg, 20, message_data_length)

    constructor = :binary.part(message_data, 0, 4) |> TL.deserialize(:meta32)
    message_content = :binary.part(message_data, 4, message_data_length - 4)

    %{
      auth_key_id: auth_key_id,
      message_id: messsage_id,
      message_data_length: message_data_length,
      constructor: constructor,
      message_content: message_content
    }
  end

  def unwrap(msg, :encrypted) do
    salt = :binary.part(msg, 0, 8) |> TL.deserialize(:long)
    session_id = :binary.part(msg, 8, 8) |> TL.deserialize(:long)
    message_id = :binary.part(msg, 16, 8) |> TL.deserialize(:long)
    seq_no =:binary.part(msg, 24, 4) |> TL.deserialize(:meta32)
    message_data_length =  :binary.part(msg, 28, 4) |> TL.deserialize(:meta32)
    message_data = :binary.part(msg, 32, message_data_length)

    constructor = :binary.part(message_data, 0, 4) |> TL.deserialize(:meta32)
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

  # Generate id for messages,  Unix time * 2^32
  defp generate_id do
    :os.system_time(:seconds) * :math.pow(2,32) |> round
  end
end
