defmodule MTProto.Payload do
  @moduledoc false

  #  Methods to encode/decode and wrap/unwrap payloads.
  #
  #  Note that a payload has a different structure if it is designed to be send
  #  encrypted or not. See [the detailed description of MTProto](https://core.telegram.org/mtproto/description)
  #  for more detailed informations.


  # TO BE REMOVED
  def build(method, args) do
    TL.build(method, args)
  end

  # Unwrap ('type' is either `:plain` or `:encrypted`) and parse a message.
  # Returns `{map, tail}`.
  def parse(msg, type \\ :encrypted) do
    #auth_key_id = :binary.part(msg, 0, 8)
    map = msg |> unwrap(type)
    container = Map.get map, :constructor
    content = Map.get map, :message_content
    message_id = Map.get map, :message_id
    {map, tail} = TL.parse(container, content)
    {Map.put(map, :msg_id, message_id), tail}
  end

  #  Wrap a message as a 'plain' payload.
  def wrap(msg) do
    auth_id_key = 0
    msg_id =  generate_id()
    msg_len = byte_size(msg)
    TL.serialize(auth_id_key, :int64) <> TL.serialize(msg_id, :int64)
                                      <> TL.serialize(msg_len, :int)
                                      <> msg
  end

  #  Wrap a message as an 'encrypted' payload.
  def wrap(msg, msg_id, msg_seqno) do
    msg_len = byte_size(msg)
    TL.serialize(msg_id, :int64) <> TL.serialize(msg_seqno, :int)
                                 <> TL.serialize(msg_len, :int)
                                 <> msg
  end

  #  Unwrap a 'plain' payload.
  def unwrap(msg, :plain) do
    auth_key_id = :binary.part(msg, 0, 8) |> TL.deserialize(:long)
    messsage_id = :binary.part(msg, 8, 8) |> TL.deserialize(:long)
    message_data_length = :binary.part(msg, 16, 4) |> TL.deserialize(:int)
    message_data = :binary.part(msg, 20, message_data_length)

    constructor = :binary.part(message_data, 0, 4) |> TL.deserialize(:int)
    message_content = :binary.part(message_data, 4, message_data_length - 4)

    %{
      auth_key_id: auth_key_id,
      message_id: messsage_id,
      message_data_length: message_data_length,
      constructor: constructor,
      message_content: message_content
    }
  end

  # Unwrap an 'encrypted' payload.
  def unwrap(msg, :encrypted) do
    salt = :binary.part(msg, 0, 8) |> TL.deserialize(:long)
    session_id = :binary.part(msg, 8, 8) |> TL.deserialize(:long)
    message_id = :binary.part(msg, 16, 8) |> TL.deserialize(:long)
    seq_no =:binary.part(msg, 24, 4) |> TL.deserialize(:int)
    message_data_length =  :binary.part(msg, 28, 4) |> TL.deserialize(:int)
    message_data = :binary.part(msg, 32, message_data_length)

    constructor = :binary.part(message_data, 0, 4) |> TL.deserialize(:int)
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
