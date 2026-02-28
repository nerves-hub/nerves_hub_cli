# NervesCloud and NervesHub CLI

The recommended CLI tool for working with [NervesCloud](https://nervescloud.com) and self-hosted [NervesHub](https://github.com/nerves-hub/nerves_hub_web) platforms.

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

## Connecting to your NervesHub

When using the CLI, the default URI points to [NervesCloud](https://nervescloud.com) : `https://manage.nervescloud.com`.  

To configure a different URI you can use:

```sh
$ nh config set uri "https://my.selfhosted.instance/"
```

Finally, you need to authorize your account with the choosen platform by running:

```sh
$ nh user auth
```


## Environment variables

The CLI can be configured using environment variables to simplify automation. 

The following variables are available:

* `NERVES_CLOUD_TOKEN`/`NERVES_HUB_TOKEN` - Token used to authenticate API requests
* `NERVES_CLOUD_ORG`/`NERVES_HUB_ORG` - Organization used for API requests
* `NERVES_CLOUD_PRODUCT`/`NERVES_HUB_PRODUCT` - Product to used for API requests
* `NERVES_CLOUD_FW_PRIVATE_KEY`/`NERVES_HUB_FW_PRIVATE_KEY` - Private key used for signing firmware
* `NERVES_CLOUD_FW_PUBLIC_KEY`/`NERVES_HUB_FW_PUBLIC_KEY` - Public key used for verifying firmware
* `NERVES_CLOUD_DATA_DIR`/`NERVES_HUB_DATA_DIR` - Directory used for storing config and signing keys (defaults to `~/.nerves-cloud`/`~/.nerves-hub`)
* `NERVES_CLOUD_URI`/`NERVES_HUB_URI` - Platform URI (defaults to `https://manage.nervescloud.com`)
* `NERVES_CLOUD_NON_INTERACTIVE`/`NERVES_HUB_NON_INTERACTIVE` - Force all yes/no user interaction to be yes


## Uninstalling the CLI

When you uninstall the CLI, it's highly recommended to run:

```
$ nh maintenance uninstall
```

Once you have run the above command you can safely delete the `nh` binary.
