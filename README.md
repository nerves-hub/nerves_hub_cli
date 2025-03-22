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

Once downloaded, you can run the binary directly, although we recommend adding it to your `PATH` so
that it's accessible across terminal sessions.

You can access available commands and documentation from the command-line using `nh help`. eg.

```
$ nh help
$ nh help device
```

Burritos magic is how it creates a platform specific Erlang release, compresses it into a binary, which is then
extracted to a directory managed by Burrito when the binary is executed for the first time.

Every other time you run the binary it will proxy the commands to the extracted release, invisible to the user.


## Uninstalling the CLI

When you uninstall the NervesHubCLI it is highly recommended to run:

```
$ nh maintenance uninstall
```

which tells Burrito to remove the cached contents.

Once you have run the above command you can safely delete the `nh` binary.


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
$ nh config set uri "https://my.nerveshub.instance/"
```

and for [NervesCloud](https://nervescloud.com):

```sh
$ nh config set uri "https://manage.nervescloud.com/"
```

Finally, you need to authorize your account on the NervesHub instance by running:

```sh
$ nh user whoami
$ nh user auth
```
