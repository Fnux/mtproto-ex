defmodule MTProto.Payload do
  alias MTProto.Payload

  @moduledoc false
  @pow_2_32 :math.pow(2,32)

  #  Methods to encode/decode and wrap/unwrap payloads.
  #
  #  Note that a payload has a different structure if it is designed to be send
  #  encrypted or not. See [the detailed description of MTProto](https://core.telegram.org/mtproto/description)
  #  for more detailed informations.

  defstruct constructor: nil,
    content: nil,
    session_id: nil,
    type: nil,
    msg_id: nil,
    msg_seqno: nil,
    salt: nil

  # TO BE REMOVED
  def build(method, args) do
    TL.build(method, args)
  end

  # Unwrap ('type' is either `:plain` or `:encrypted`) and parse a message.
  # Returns `{map, tail}`.
  def parse(msg, type \\ :encrypted) do
    payload = unwrap msg, type

    #IO.inspect {payload.msg_id, payload.content}, limit: :infinity

    {map, tail} = TL.parse(payload.constructor, payload.content)

    map = map |> Map.put(:msg_id, payload.msg_id)
              |> Map.put(:msg_seqno, payload.msg_seqno)

    {map, tail}
  end

  #  Wrap a message as a 'plain' payload.
  def wrap(msg, msg_id) do
    msg_len = byte_size(msg)
    TL.serialize(msg_id, :long) <> TL.serialize(msg_len, :int)
                                <> msg
  end

  #  Wrap a message as an 'encrypted' payload.
  def wrap(msg, msg_id, msg_seqno) do
    msg_len = byte_size(msg)
    TL.serialize(msg_id, :long) <> TL.serialize(msg_seqno, :int)
                                <> TL.serialize(msg_len, :int)
                                <> msg
  end

  #  Unwrap a 'plain' payload.
  def unwrap(msg, :plain) do
    # auth_key_id = :binary.part(msg, 0, 8) |> TL.deserialize(:long)

    message_data_length = :binary.part(msg, 16, 4) |> TL.deserialize(:int)
    message_data = :binary.part(msg, 20, message_data_length)

    %Payload{
      type: :plain,
      msg_id: :binary.part(msg, 8, 8) |> TL.deserialize(:long),
      constructor: :binary.part(message_data, 0, 4) |> TL.deserialize(:int),
      content: :binary.part(message_data, 4, message_data_length - 4)
    }
  end

  # Unwrap an 'encrypted' payload.
  def unwrap(msg, :encrypted) do
    message_data_length =  :binary.part(msg, 28, 4) |> TL.deserialize(:int)
    message_data = :binary.part(msg, 32, message_data_length)

    constructor = :binary.part(message_data, 0, 4) |> TL.deserialize(:int)
    message_content = :binary.part(message_data, 4, message_data_length - 4)

    %Payload{
      type: :encrypted,
      salt: :binary.part(msg, 0, 8) |> TL.deserialize(:long),
      session_id: :binary.part(msg, 8, 8) |> TL.deserialize(:long),
      msg_id: :binary.part(msg, 16, 8) |> TL.deserialize(:long),
      # Message sequence number != Session sequence number
      msg_seqno: :binary.part(msg, 24, 4) |> TL.deserialize(:int),
      constructor: constructor,
      content: message_content
    }
  end

  # Generate id for messages, ~ Unix time * 2^32, must be a multiple of 4
  def generate_id() do
    timestamp = (:os.system_time(:seconds) * @pow_2_32) |> round
    rem = rem(timestamp, 4)
    offset = if rem != 0, do: 4 - rem, else: rem

    timestamp + offset
  end

  def fix_id(id) do
    rem = rem(id, 4)
    offset = if rem != 0, do: 4 - rem, else: rem

    id + offset
  end
end
