defmodule MTProto.TCP do
  require Logger

  @moduledoc false
  # Basic wrapper over :gen_tcp

  # Create a TCP socket
  def connect(address, port) do
    :gen_tcp.connect(String.to_char_list(address), port, [:binary, {:active, false}])
  end

  # Close a TCP Socket
  def close(socket) do
    :gen_tcp.close(socket)
  end

  # Send data over socket
  def send(data, socket) do
    :gen_tcp.send socket, data
  end

  # Read from socket.
  # Structure of packet (see https://core.telegram.org/mtproto#tcp-transport) :
  # length (4 bytes) | TCP Seqno (4 bytes) | data | CRC32 (4 bytes)
  def recv(socket) do
    # Get the length of the packet
    {:ok, binary_length} = :gen_tcp.recv(socket, 4)
    << length :: little-size(4)-unit(8) >> = binary_length

    # Build the packet
    {:ok, binary_data} = :gen_tcp.recv(socket, length - 4)
    packet = binary_length <> binary_data

    # CRC32 check
    << received_crc32 :: little-size(4)-unit(8)>> = :binary.part(packet, length, -4)
    crc32 = :binary.part(packet, 0, length - 4) |> :erlang.crc32
    if received_crc32 != crc32, do: Logger.warn "CRC32 mismatch! Possibly corrupted packet!"

    # TCP sequence number
    #<< seqno :: little-size(4)-unit(8) >> = :binary.part(packet, 4, 4)

    # Return : omit the length, the TCP sequence number and the CRC32
    :binary.part(packet, 8, length - 12)
  end

  # Serialize MTProto's payload eaders for TCP
  def serialize(data) do
    <<data::little-size(4)-unit(8)>>
  end

  # Wrap MTProto payload for TCP
  def wrap(payload, seq \\ 0) do
    len = 4*3 + byte_size(payload) |> serialize
    tmp = len <> serialize(seq) <> payload
    crc32 = :erlang.crc32(tmp) |> serialize
    tmp <> crc32
  end
end
