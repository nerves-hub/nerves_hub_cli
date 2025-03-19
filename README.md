# NervesHubCLI

The recommended CLI tool for working with [NervesHub](https://www.nerves-hub.org) and
[NervesCloud](https://nervescloud.com) from the command-line

Features include:

* Uploading firmware to NervesHub
* Generating device certificates and registration
* Managing device provisioning metadata
* Creating and managing firmware signing keys
* Manage firmware deployments
* Manage user and organization accounts


## Installation

The CLI is a compiled binary that can be downloaded from the [releases page](https://github.com/nerves-hub/nerves_hub_cli/releases).

Once downloaded, you can run the binary directly, although we recommend adding it to your PATH.

You can access available commands and documentation from the command-line using `nhcli help`. eg.

```
$ nhcli help
$ nhcli help device
```

To uninstall, just delete the binary.


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


## Connecting to NervesHub

NervesHubCLI must be configured to connect to your chosen NervesHub host.

To configure the NervesHub URI, run:

```sh
$ nhcli config set uri "https://my.nerveshub.instance/"
```

and for [NervesCloud](https://nervescloud.com):

```sh
$ nhcli config set uri "https://manage.nervescloud.com/"
```

Finally, you need to authorize your account on the NervesHub instance by running:

```sh
$ nhcli user whoami
$ nhcli user auth
```
