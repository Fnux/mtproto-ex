# MTProto-ex

The aim of this project is to implement [MTProto](https://core.telegram.org/mtproto) (Telegram) in elixir.

Well, it's still far from completed.

## Actual state

* Able to compute an Authorization key
* Able to send/encrypt && receive/decrypt payloads
* Still working on authentification.

## Example

```
» iex -S mix

Interactive Elixir (1.4.0) - press Ctrl+C to exit (type h() ENTER for help)
iex> session_id = MTProto.Session.open()
{:ok, #PID<0.196.0>}
-791979488906011779

iex> {:ok, session_id} = MTProto.connect(4) # Connect to DC 4

iex> MTProto.send_code(session_id, "0041000000000")
```
