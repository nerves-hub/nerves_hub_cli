# NervesHubCLI

The recommended CLI tool for working with [NervesHub](https://www.nerves-hub.org) and
[NervesCloud](https://nervescloud.com) from the command-line.

Features include:

* Uploading firmware to NervesHub
* Generating device certificates and registration
* Managing device provisioning metadata
* Creating and managing firmware signing keys
* Manage firmware deployments
* Manage user and organization accounts

---

### Quick Installation (Mac and Linux)

#### Using Homebrew

```bash
brew install nerves-hub/tap/nh
```

#### Using Curl

```bash
curl --proto '=https' --tlsv1.2 -fsSL https://raw.githubusercontent.com/nerves-hub/nerves_hub_cli/master/install.sh | sh
```

This installs the `nh` binary to `/usr/local/bin`.

> [!NOTE]
> It's best practice to read any installation scripts before running them

#### Using a Mac?

If you are using a Mac and your get an error message that the binary isn't trusted, please follow these steps:

1. Open the System Settings.
2. Click on the "Privacy & Security" icon.
3. Scroll down to the "Security" section.
4. Click open next to the warning about the `nh` executable.
5. Click on the "Open Anyway" button in the warning dialog.
6. Run the `nh` command again.

For more information, see the [Apple Support article](https://support.apple.com/en-nz/guide/mac-help/mh40616/mac).

---

## Custom Installation

The CLI is a compiled binary that can be downloaded from the [releases page](https://github.com/nerves-hub/nerves_hub_cli/releases).

Once downloaded you can run the binary directly, although we recommend adding it to your `PATH` so
that it's accessible across terminal sessions.

You can access available commands and documentation from the command-line using `nh help`. eg.

```
$ nh help
$ nh help device
```

Burritos magic is how it creates a platform specific Erlang release, compresses it into a binary, which is then
extracted to a directory managed by Burrito when the binary is executed for the first time.

Subsquent use of the binary will proxy the commands to the extracted release, invisible to the user.


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



## Uninstalling the CLI

When you uninstall the NervesHubCLI it is highly recommended to run:

```
$ nh maintenance uninstall
```

which tells Burrito to remove the cached contents.

Once you have run the above command you can safely delete the `nh` binary.
