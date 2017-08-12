# Telegram MT(Proto)

[MTProto](https://core.telegram.org/mtproto) implementation in elixir.
The project is still in *alpha* : **Expect things to break**.
Note that it's my fisrt real elixir project, so it's probably awful.

This library is on [hex.pm](https://hex.pm/packages/telegram_mt) and
the documentation is available [here](https://hexdocs.pm/telegram_mt/MTProto.html).

## Useful links

  * [Github repository](https://github.com/Fnux/telegram-mt-elixir)
  * [Demo app](https://github.com/Fnux/telegram-client-elixir-demo)
  * [Telegram API](https://core.telegram.org/api#telegram-api)
  * [MTProto's documentation](https://core.telegram.org/mtproto)

## Status & Roadmap

Version `v0.1.0-alpha` has been released ([changelog](changelog.md)).

**Status :** you currently can signin, receive and send message, fetch
contacts and chats, save and restore sessions.

## Overview

This library allows you to handle mutiple users, which is fondamental since
it was originally designed to build bridges between Telegram
and other messaging services. Each session is equivalent to an user and has
its own connection to Telegram's servers. Note that you have to set
(see `MTProto.Session.set_client/2`) a process to be notified of incoming
messages for every session.

* `MTProto` (this module) - provides a "friendly" way to interact with
'low-level' methods. It allow you to connect/login/logout/send messages.
* `MTProto.API` (and submodules) - implementation of the Telegram API, as explained
[here](https://core.telegram.org/api#telegram-api) and
[here](https://core.telegram.org/schema).
* `MTProto.Session` : Provides manual control over sessions.
* `MTProto.DC` : Provides manual control over DCs.
* Many modules **[1]** are not designed to be used by
the "standard" user hence not documented here.

**[1]** : `MTProto.Session.Brain`, `MTProto.Session.Handler`,
  `MTProto.Session.HandlerSupervisor`, `MTProto.Session.Listener`,
  `MTProto.Session.ListenerSupervisor`, `MTProto.Auth`, `MTProto.Crypto`,
  `MTProto.Method`, `MTProto.Payload`, `MTProto.Registry`,
  `MTProto.Supervisor` and `MTProto.TCP`.

Each session has one listener and one handler (they are registered in the
`SessionRegistry` registry). The `DCRegistry` registry saves the data related to each specific DC
(Telegram uses 5 DCs) such as the address or the authorization key.

## Example

```
» iex -S mix

Interactive Elixir (1.4.0) - press Ctrl+C to exit (type h() ENTER for help)
iex(1)> MTProto.start()

09:41:19.160 [info]  Starting Telegram MT.
{:ok, #PID<0.164.0>}

iex> {:ok, session_id} = MTProto.connect(4) # Connect to DC 4

09:42:02.934 [debug] [Handler] 5144610857678255187 : starting handler.
09:42:02.935 [debug] [Listener] 5144610857678255187 : starting listener.
{:ok, 5144610857678255187}

iex> MTProto.request_authkey(session_id)

09:43:21.153 [debug] Requesting authorization key for session 5144610857678255187...
09:43:21.993 [debug] The authorization key was successfully generated.

iex> MTProto.send_code(session_id, "0041123456789")

No client for 5144610857678255187, printing to console.
{5144610857678255187,
 %{msg_id: 6444013746561167361, name: "rpc_result",
   req_msg_id: 6444013745160060928,
   result: %{is_password: %{name: "boolFalse"}, name: "auth.sentCode",
     phone_code_hash: "qwertzuiopasdfg123",
     phone_registered: %{name: "boolTrue"}, send_call_timeout: 120}}}

iex> MTProto.sign_in(session_id, "0041123456789", "01234")

No client for 5144610857678255187, printing to console.
{5144610857678255187,
 %{msg_id: 6444014010308812801, name: "rpc_result",
   req_msg_id: 6444014007153065984,
   result: %{expires: 2147483647, name: "auth.authorization",
     user: %{first_name: "Fnux", id: 122205918, inactive: %{name: "boolFalse"},
       last_name: "", name: "userSelf", phone: "41123456789",
       photo: %{name: "userProfilePhoto",
         photo_big: %{dc_id: 4, local_id: 52832, name: "fileLocation",
           secret: 01234567890123456789, volume_id: 430507451},
         photo_id: 524870421643897743,
         photo_small: %{dc_id: 4, local_id: 52830, name: "fileLocation",
           secret: 123456789012345678, volume_id: 430507451}},
       status: %{name: "userStatusOffline", was_online: 1500363697},
       username: "fnux_ch"}}}}
```
