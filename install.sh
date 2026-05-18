#!/bin/sh
set -e

RELEASES_URL="https://github.com/nerves-hub/nerves_hub_cli/releases"

check_dependencies() {
	missing=""
	platform=$(uname -s)
	deps="curl tar"
	if [ "$platform" != "Darwin" ]; then
		deps="$deps xz"
	fi
	for cmd in $deps; do
		if ! command -v "$cmd" > /dev/null 2>&1; then
			missing="$missing $cmd"
		fi
	done
	if [ -n "$missing" ]; then
		printf 'Error: missing required dependencies:%s\n' "$missing" >&2
		exit 1
	fi
}

download_tar() {
	if [ "$(uname -m)" = "arm64" ]
	then
		ARCH=aarch64
	else
		ARCH=x86_64
	fi

	PLATFORM=$(uname -s)

	case "$PLATFORM" in
		Darwin)
			PLATFORM=macos
			;;
		Linux)
			PLATFORM=linux
			;;
		*)
			printf 'Error: unsupported platform: %s\n' "$PLATFORM" >&2
			exit 1
			;;
	esac

	# https://github.com/nerves-hub/nerves_hub_cli/releases/download/v3.0.0/nh-macos_aarch64.tar.xz
	URL="${RELEASES_URL}/latest/download/${PLATFORM}-${ARCH}.tar.xz"

	curl --silent --location --fail "$URL"
}

main() {
	check_dependencies
	default_dir=/usr/local/bin
	tar_binary=nh

	if [ -z "$nh_bindir" ]; then
	    nh_bindir="$default_dir"
	    if [ -n "$1" ]; then
	        nh_bindir="$1"
	    fi
	fi
	if [ ! -d "$nh_bindir" ]; then
	    printf '\n\033[1;33mNervesHubCLI Installation Helper\033[0m\n\nDestination directory "%s" is not a directory\n\nUsage: %s [install-dir]\n\nIf install-dir is not provided, the installation script will use "%s"\n\n' \
	        "$nh_bindir" "$0" "$default_dir"
	    exit 1
	fi

	tmp=$(mktemp)
	trap 'rm -f "$tmp"' EXIT
	download_tar > "$tmp"
	tar -xJf "$tmp" -C "$nh_bindir" "$tar_binary"

	printf 'Installed %s to %s\n' "$tar_binary" "$nh_bindir"
}

main "$@"
