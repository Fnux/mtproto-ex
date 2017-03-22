# MTProto-ex

The aim of this project is to implement [MTProto](https://core.telegram.org/mtproto) (Telegram) in elixir.

Well, it's still far from completed.

## Actual state

* Able to compute an Authorization key
* Able to send/encrypt && receive/decrypt payloads
* Able to authenticate.
* Able to read incoming messages.

## Relaese alpha v0.0.1 : Roadmap

* [*] Basic `mtproto` implementation
* [*] Authorization key computation
* [*] Authentification
* [] Basic usage
  * [*] Receive messages
  * [] Fetch contacts - WIP
  * [] Send messages
* [] Proper documentation - WIP

## Example

```
» iex -S mix

Interactive Elixir (1.4.0) - press Ctrl+C to exit (type h() ENTER for help)
iex> {:ok, session_id} = MTProto.connect(4) # Connect to DC 4
{:ok, 0000000000000000000}

19:10:07.231 [info]  The authorization key was successfully generated.

iex> MTProto.send_code(session_id, "0041000000000")
No client for 0000000000000000000, printing to console.
{0000000000000000000,
 %{name: "rpc_result", req_msg_id: 0000000000000000000,
   result: %{is_password: %{name: "boolFalse"}, name: "auth.sentCode",
     phone_code_hash: "000000000000000000",
     phone_registered: %{name: "boolTrue"}, send_call_timeout: 120}}}

iex> MTProto.sign_in(session_id, "0041000000000", "00000")
No client for 0000000000000000000, printing to console.
{0000000000000000000,
 %{name: "rpc_result", req_msg_id: 0000000000000000000,
   result: %{expires: 0000000000, name: "auth.authorization",
     user: %{first_name: "XXXX", id: 000000000, inactive: %{name: "boolFalse"},
       last_name: "", name: "userSelf", phone: "41000000000",
       photo: %{name: "userProfilePhoto",
         photo_big: %{dc_id: 4, local_id: 00000, name: "fileLocation",
           secret: 0000000000000000000, volume_id: 000000000},
         photo_id: 000000000000000000,
         photo_small: %{dc_id: 4, local_id: 00000, name: "fileLocation",
           secret: 0000000000000000000, volume_id: 000000000}},
       status: %{name: "userStatusOffline", was_online: 0000000000},
       username: "xxxxxxx"}}}}
```
