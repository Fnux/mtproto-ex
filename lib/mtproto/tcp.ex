defmodule MTProto.TCP do
  def connect(address, port) do
    :gen_tcp.connect(String.to_char_list(address), port, [{:packet, :raw}, {:active, false}])
  end

  def send(data, socket) do
    :gen_tcp.send socket, data
  end

  def recv(socket) do
    :gen_tcp.recv(socket, 0)
  end

  def wrap_serialize(data) do
    <<data::little-size(4)-unit(8)>>
  end

  def wrap(payload, seq \\ 0) do
    len = 4*3 + byte_size(payload) |> wrap_serialize
    tmp = len <> wrap_serialize(seq) <> payload
    crc32 = :erlang.crc32(tmp) |> wrap_serialize
    tmp <> crc32
  end

  def unwrap(packet) do
     << len :: little-size(4)-unit(8) >> = :binary.part(packet, 0, 4)
     << seq :: little-size(4)-unit(8) >> = :binary.part(packet, 4, 4)
     << crc32 :: little-size(4)-unit(8) 
      >> = :binary.part(packet, byte_size(packet), -4)

     data = :binary.part(packet, 2*4, len - 4*3)

     #{len, seq, data, crc32}
     data
  end
end
