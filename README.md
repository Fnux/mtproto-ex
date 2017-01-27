# MTProto-ex

The aim of this project is to implement [MTProto](https://core.telegram.org/mtproto) (Telegram) in elixir.

Well, it's still far from completed.

## Actual state

* Able to compute an Authorization key
* Able to send/encrypt && receive/decrypt payloads
* Won't have a lot of time during this semester (Fall 2016).

## Example

```
» iex -S mix

Interactive Elixir (1.4.0) - press Ctrl+C to exit (type h() ENTER for help)
iex> session_id = MTProto.Session.open()
{:ok, #PID<0.196.0>}
-791979488906011779

iex> MTProto.Session.send session_id, MTProto.Method.req_pq, :plain
19:34:04.905 [debug] 8095676014272936173 : sending plain message.
19:34:04.939 [debug] 8095676014272936173 : incoming message.
19:34:04.940 [debug] 8095676014272936173 : received plain message.
19:34:05.070 [debug] 8095676014272936173 : sending plain message.
19:34:05.164 [debug] 8095676014272936173 : incoming message.
19:34:05.164 [debug] 8095676014272936173 : received plain message.
19:34:05.170 [debug] 8095676014272936173 : sending plain message.
19:34:05.411 [debug] 8095676014272936173 : incoming message.
19:34:05.412 [debug] 8095676014272936173 : received plain message.
19:34:05.416 [info]  The authorization key was successfully generated.

iex>
```
