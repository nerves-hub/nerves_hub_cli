# NervesHubCLI

[![CircleCI](https://circleci.com/gh/nerves-hub/nerves_hub_cli.svg?style=svg)](https://circleci.com/gh/nerves-hub/nerves_hub_cli)

**Important**

This is the 2.0 development branch of NervesHubCLI. If you have been using NervesHub prior to around April, 2023 and are not following 2.0 development, see the `maint-v0` branch. The `maint-v0` branch is being used in production. 2.0 development is in progress, and we don't have guides or good documentation yet. If you use the 2.0 development branch, we don't expect breaking changes, but please bear with us as we complete the 2.0 release.

---

`NervesHubCLI` is an [escript](https://hexdocs.pm/mix/main/Mix.Tasks.Escript.Build.html)
CLI tool for working with [NervesHub](https://www.nerves-hub.org) from the command-line.
Features include:

* Uploading firmware to NervesHub
* Generating device certificates and registration
* Managing device provisioning metadata
* Creating and managing firmware signing keys
* Manage firmware deployments
* Manage user and organization accounts

The recommended way of using the CLI is to run `mix escript.install hex nerves_hub_cli`.
Note that you may have to add the binary installation directory to your PATH

Once installed, you can access available commands and documentation from the
command-line using `nerves_hub help`:

```sh
$ nerves_hub help
$ nerves_hub help device
```

To uninstall, run `mix escript.uninstall nerves_hub_cli`.

## Environment variables

`NervesHubCLI` may be configured using environment variables to simplify
automation. The following variables are available:

* `NERVES_HUB_TOKEN` (or `NH_TOKEN`) - Token used to authenticate API requests
* `NERVES_HUB_CERT` - Certificate contents for authenticating with NervesHub
* `NERVES_HUB_KEY`  - The private key associated with `NERVES_HUB_CERT`
* `NERVES_HUB_ORG`  - NervesHub organization to use
* `NERVES_HUB_FW_PRIVATE_KEY` - Fwup signing private key
* `NERVES_HUB_FW_PUBLIC_KEY`  - Fwup signing public key
* `NERVES_HUB_HOME` - NervesHub CLI data directory (defaults to `~/.nerves-hub`)
* `NERVES_HUB_URI` - NervesHub API host, port, scheme (all in one)
* `NERVES_HUB_HOST` - NervesHub API endpoint IP address or hostname
* `NERVES_HUB_PORT` - NervesHub API endpoint port
* `NERVES_HUB_SCHEME` - NervesHub API endpoint scheme
* `NERVES_HUB_NON_INTERACTIVE` - Force all yes/no user interaction to be yes

For more information on using the CLI, see the
[`nerves_hub_link`](https://github.com/nerves-hub/nerves_hub_link) documentation.

## Connecting to NervesHub

NervesHubCLI must be configured to connect to your chosen NervesHub host.

To configure the NervesHub URI, run:

```sh
$ nerves_hub config set uri "https://my.nerveshub.instance/"
```

Finally, you need to authorize your account on the NervesHub instance by running:

```sh
$ nerves_hub user whoami
$ nerves_hub user auth
```
