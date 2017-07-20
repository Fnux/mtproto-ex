# Changelog for telegram_mt (telegram-mt-elixir)

## v0.0.4-alpha (????-??-??)

## v0.0.3-alpha (2017-07-20)

* Do not automatically start (see `MTProto.start`)
* Fix application name used in config
* Update telegram_tl dependency
* Major refactoring of the registry
* Notify the clients with `{:tg, ...}` (instead of `:recv`)
* Allow to specify external public key (useful for escript)
* Use a single authkey per session (allows multiple sessions per DC)
* Allow to export/import the session parameters (= allow to restore a session)
* Sending messages is now synchronous (`GenServer.call`)
* Minor documentation improvements
* Minor API changes

## v0.0.2-alpha (2017-05-06)

* Populate the `MTProto.API.X` modules given the
["available method list"](https://core.telegram.org/methods)
  * Populate the `MTProto.API.Auth` module
  * Populate the `MTProto.API.Contacts` module
  * Populate the `MTProto.API.Help` module
  * Populate the `MTProto.API.Messages` module
  * Populate the `MTProto.API.Users` module
* Handling different data centers
* Allow to import/export authorization keys
* Update `telegram_tl` dependency to `v0.0.9-alpha`

## v0.0.1-alpha (2017-04-30)

* Basic mtproto implementation
* Authorization key computation
* Authentification
* Basic usage
  * Get contacts and their status
  * Receive messages
  * Send messages
* Basic documentation
