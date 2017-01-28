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

iex> send_code = MTProto.API.Auth.send_code "0041000000000"
<<...>>

iex> init_connection = MTProto.API.init_connection("unknow device", "unknow os", "unknow app", "en", send_code)
<<...>>

iex> invoke_with_layer = MTProto.API.invoke_with_layer(23, init_connection) |> MTProto.Payload.wrap(:encrypted)
<<...>>

iex> MTProto.Session.send session_id, invoke_with_layer
# msg ack
{...,
 %{name: "rpc_result", req_msg_id: ...,
    result: %{is_password: false, name: "auth.sentCode",
         phone_code_hash: "hashashashashashas", phone_registered: true,
            send_call_timeout: 120}}}
iex> sign_in = MTProto.API.Auth.sign_in("0041000000000", "hashashashashashas", "00000") |> MTProto.Payload.wrap(:encrypted)
<<...>>

iex> MTProto.send session_id, sign_in
```
