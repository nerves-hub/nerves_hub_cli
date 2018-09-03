# NervesHubCLI

[![CircleCI](https://circleci.com/gh/nerves-hub/nerves_hub_cli.svg?style=svg)](https://circleci.com/gh/nerves-hub/nerves_hub_cli)
[![Hex version](https://img.shields.io/hexpm/v/nerves_hub_cli.svg "Hex version")](https://hex.pm/packages/nerves_hub_cli)

`NervesHubCLI` provides a set of [Mix](https://hexdocs.pm/mix/Mix.html) tasks so
that you can work with [NervesHub](https://www.nerves-hub.org) from the command
line. Features include:

* Uploading firmware to NervesHub
* Generating device certificates and registration
* Managing device provisioning metadata
* Creating and managing firmware signing keys
* Manage firmware deployments
* Manage user and organization accounts

The recommended way of using the CLI is to include
[`nerves_hub`](https://github.com/nerves-hub/nerves_hub) in your dependencies.
`nerves_hub` pulls in `nerves_hub_cli` and includes the target runtime
components necessary to use it.

Once installed, you can access available commands and documentation from the
commandline using `mix help`:

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

For more information on using the CLI, see the
[`nerves_hub`](https://github.com/nerves-hub/nerves_hub) documentation.

