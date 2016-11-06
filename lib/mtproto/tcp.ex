defmodule MTProto.TCP do
  # Create a TCP socket
  def connect(address, port) do
    :gen_tcp.connect(String.to_char_list(address), port, [{:packet, :raw}, {:active, false}])
  end

  # Close a TCP Socket
  def close(socket) do
    :gen_tcp.close(socket)
  end

  # Send data over socket
  def send(data, socket) do
    :gen_tcp.send socket, data
  end

  # Read from socket
  def recv(socket) do
    :gen_tcp.recv(socket, 0)
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

  # Unwrap MTProto payload for TCP
  def unwrap(packet) do
     << len :: little-size(4)-unit(8) >> = :binary.part(packet, 0, 4)
     << seq :: little-size(4)-unit(8) >> = :binary.part(packet, 4, 4)
     << expected_crc32 :: little-size(4)-unit(8)>> = :binary.part(packet, byte_size(packet), -4)
     real_crc32 = :binary.part(packet, 0, byte_size(packet) -4) |> :erlang.crc32

     if real_crc32 != expected_crc32, do: raise "CRC32 mismatch! Possibly corrupted packet!"
     payload = :binary.part(packet, 2*4, len - 4*3)

     payload
  end
end
