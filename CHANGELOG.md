# Changelog

## v0.10.1

* Bug fixes
  * Ignore whitepace in base64-encoded string input

## v0.10.0

* Breaking changes
  * Decouples deprecated `:nerves_hub` config values and will fail compilation if used.
  To set your organization for the CLI, use `:nerves_hub_cli` key:
  ```elixir
  config :nerves_hub_cli, org: "my-org"
  ```

* Enhancements
  * `mix nerves_hub.device bulk_create --csv path/to/file.csv` - Support bulk upload
  from CSV definitions
  * Add ability to use your own signer CA and key locally when creating device certificate
  `mix nerves_hub.device cert create --signer-cert path/to/cert --signer-key path/to/key`

## v0.9.1

* Enhancements
  * Updated user auth to support logging in with username or email.
  * Improved error message formatting.

## v0.9.0

Backwards incompatible changes:

The NervesHubUserAPI.Device and NervesHubUserAPI.DeviceCertificate endpoints
have moved to include `product` as part of its path.

* Update dependencies
  * [nerves_hub_user_api v0.6.0](https://github.com/nerves-hub/nerves_hub_user_api/releases/tag/v0.6.0)

## v0.8.0

* Enhancements
  * Added mix tasks
    * `mix nerves_hub.org user list` - List the users and their role for the
      organization.
    * `mix nerves_hub.org user add USERNAME ROLE` - Add an existing user to an
      org with a role.
    * `mix nerves_hub.org user update USERNAME ROLE`- Update an existing user
      in your org with a new role.
    * `mix nerves_hub.org user remove USERNAME` - Remove an existing user from
      having a role in your organization.
    * `mix nerves_hub.product user list PRODUCT_NAME` - List the users and their
      role for the product.
    * `mix nerves_hub.product user add PRODUCT_NAME USERNAME ROLE` - Add an
      existing user to a product with a role.
    * `mix nerves_hub.product user update PRODUCT_NAME USERNAME ROLE`- Update an
      existing user for your product with a new role.
    * `mix nerves_hub.product user remove PRODUCT_NAME USERNAME` - Remove an
      existing user from having a role for your product.
  * Added filtering for `mix nerves_hub.device list`
    * `--identifier` - (Optional) Only show device matching an identifier
    * `--description` - (Optional) Only show devices matching a description
    * `--tag` - (Optional) Only show devices matching tags. Multiple tags can be
    supplied.
    * `--status` - (Optional) Only show devices matching status
    * `--version` - (Optional) Only show devices matching version

## v0.7.2

* Bug fixes
  * Fixed error when running `mix nerves_hub.device list` and there weren't any
    devices

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
