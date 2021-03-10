# NervesHubCLI

[![CircleCI](https://circleci.com/gh/nerves-hub/nerves_hub_cli.svg?style=svg)](https://circleci.com/gh/nerves-hub/nerves_hub_cli)
[![Hex version](https://img.shields.io/hexpm/v/nerves_hub_cli.svg "Hex version")](https://hex.pm/packages/nerves_hub_cli)

`NervesHubCLI` provides a set of [Mix](https://hexdocs.pm/mix/Mix.html) tasks so
that you can work with [NervesHub](https://www.nerves-hub.org) from the
command-line. Features include:

* Uploading firmware to NervesHub
* Generating device certificates and registration
* Managing device provisioning metadata
* Creating and managing firmware signing keys
* Manage firmware deployments
* Manage user and organization accounts

The recommended way of using the CLI is to include
[`nerves_hub_link`](https://github.com/nerves-hub/nerves_hub_link) in your dependencies.
`nerves_hub_link` pulls in `nerves_hub_cli` and includes the target runtime
components necessary to use it.

Once installed, you can access available commands and documentation from the
command-line using `mix help`:

```sh
$ mix help
...
mix nerves_hub.deployment # Manages NervesHub deployments
mix nerves_hub.device     # Manages your NervesHub devices
mix nerves_hub.firmware   # Manages firmware on NervesHub
mix nerves_hub.key        # Manages your firmware signing keys
mix nerves_hub.product    # Manages your products
mix nerves_hub.user       # Manages your NervesHub user account
...

$ mix help nerves_hub.device
...
```

## Environment variables

`NervesHubCLI` may be configured using environment variables to simplify
automation. The following variables are available:

* `NERVES_HUB_CERT` - Certificate contents for authenticating with NervesHub
* `NERVES_HUB_KEY`  - The private key associated with `NERVES_HUB_CERT`
* `NERVES_HUB_ORG`  - NervesHub organization to use
* `NERVES_HUB_FW_PRIVATE_KEY` - Fwup signing private key
* `NERVES_HUB_FW_PUBLIC_KEY`  - Fwup signing public key
* `NERVES_HUB_HOME` - NervesHub CLI data directory (defaults to `~/.nerves-hub`)
* `NERVES_HUB_HOST` - NervesHub API endpoint IP address or hostname (defaults to `api.nerves-hub.org`)
* `NERVES_HUB_PORT` - NervesHub API endpoint port (defaults to 443)
* `NERVES_HUB_NON_INTERACTIVE` - Force all yes/no user interaction to be yes

For more information on using the CLI, see the
[`nerves_hub_link`](https://github.com/nerves-hub/nerves_hub_link) documentation.


## Connecting to other environments

NervesHubCLI can be directed to target other environments beside the public
NervesHub instance. See the
[documentation](https://docs.nerves-hub.org/nerves-hub/setup/connecting-other-envs)
for example config values to do this.
