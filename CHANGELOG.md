# Changelog

## v0.7.1

* Enhancements
  * Added device deletion support
  * Improved formatting when listing devices
  * Tag entry is always comma-separated now (it previously was space
    delimited, but that was inconsistent with the GUI)

## v0.7.0

* Enhancements
  * Change dependency `nerves_hub_core` to `nerves_hub_user_api`
  * Updated prompts for deployment and device tags

## v0.6.0

This release makes a backwards incompatible API change that affects
how fwup public keys are shared with other projects. This should
only affect the `nerves_hub` library and should be handled by mix dependency
constraints.

* Backwards incompatible changes
  * The API to share fwup public keys has changed. This should only affect the
    `nerves_hub` library and should be handled by mix dependency constraints.
  * `mix nerves_hub.ca_certificate create` is now `register`. (It never created
    a certificate.

* Enhancements
  * Show API endpoint when running commands - this makes it more obvious when
    you're running against api.nerves-hub.org vs. your own instance

## v0.5.1

* Enhancements
  * Added mix task `mix nerves_hub.device list` - List all devices for an org.
  * Document `--ttl` option in `mix nerves_hub.firmware publish`.
  * Expect `:nerves_hub` in application config instead of mix project config.
  * Bump `nerves_hub_core` dep to `0.2.0`.

* Bug Fixes
  * Failed mix tasks exit with non-zero status code to facilitate CI.
  * Rework how a password is obtained when calling `mix nerves_hub.user auth`.

## v0.5.0

* Enhancements
  * Added mix tasks
    * `mix nerves_hub.ca_certificate list` - List all CA certificates for an org.
    * `mix nerves_hub.ca_certificate create CERT_PATH` - Add a CA certificate.
    * `mix nerves_hub.ca_certificate delete CERT_SERIAL`- Delete a CA certificate.
  * The API modules have been moved to `nerves_hub_core` for runtime reusability.

* Bug Fixes
  * Improved error handling when uploading unsigned firmware.

## v0.4.0

* Enhancements
  * Updated mix tasks
    * `mix nerves_hub.product create` - Will take the product name from the
      Mix project config by default.
    * `mix nerves_hub.device burn` - Will now call `mix burn` instead of
      `mix firmware.burn`.
  * Certificate functions are performed in Erlang and no longer call out to
    openssl.
  * Updated Docs and CLI prompts.

## v0.3.0

* Enhancements
  * Added mix tasks
    * `mix nerves_hub.key export KEY_NAME` - Export a firmware signing key
    * `mix nerves_hub.user cert export` - Export the current user certificate
  * Updated mix tasks
    * `mix nerves_hub.firmware publish` - Added ability to set firmware TTL by
      passing `--ttl seconds`.
  * Added environment variable `NERVES_HUB_NON_INTERACTIVE` for use with running
    `nerves_hub_cli` from non-interactive terminals such as CI. This answers `y`
    to all `y/n` prompts.
  * Allow passing binary public keys to `config :nerves_hub, public_keys: []`.

## v0.2.0

* Enhancements
  * Update account name to username.
  * Added mix task for importing existing fwup keys.
    `mix nerves_hub.key import KEY_NAME PUBLIC_KEY_FILE PRIVATE_KEY_FILE`
  * Updated documentation to list environment variables needed to running CI.
  * Added support for setting firmware signing keys in the environment.

## v0.1.0

Initial release
