#!/bin/bash
set -e

RELEASES_URL="https://github.com/nerves-hub/nerves_hub_cli/releases"

download_tar() {
	if [[ "$(uname -m)" == "arm64" ]]
	then
		ARCH=aarch64
	else
		ARCH=x86_64
	fi

	PLATFORM=$(uname -s)

	if [[ $PLATFORM == "Darwin" ]]
	then
		PLATFORM=macos
	fi

	# https://github.com/nerves-hub/nerves_hub_cli/releases/download/v3.0.0/nh-macos_aarch64.tar.xz
	URL="${RELEASES_URL}/latest/download/${PLATFORM}-${ARCH}.tar.xz"

	curl --silent --location --fail "$URL"
}

main() {
	default_dir=/usr/local/bin
	tar_binary=nh

	if [[ -z "$nh_bindir" ]]; then
	    nh_bindir="$default_dir"
	    if [[ "$1" ]]; then
	        nh_bindir="$1"
	    fi
	fi
	if [[ ! -d "$nh_bindir" ]]; then
	    echo -e "
\033[1;33mNervesHubCLI Installation Helper\033[0m

Destination directory "$nh_bindir" is not a directory

Usage: $0 [install-dir]

If install-dir is not provided, the installation script will use "$default_dir"

"
	    exit 1
	fi

	download_tar | tar -xzf - -C "$nh_bindir" $tar_binary
}

main "$@"
