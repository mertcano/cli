#!/bin/sh
# qfex CLI installer.
#
#   curl -fsSL https://raw.githubusercontent.com/QFEX-Org/cli/main/install.sh | sh
#
# Detects your OS and CPU architecture, then installs the matching release:
#   macOS         Homebrew if available, otherwise a tarball
#   Debian/Ubuntu the .deb package (also installs shell completions)
#   other Linux   a tarball
#
# Options (flags or environment variables):
#   --version vX.Y.Z   QFEX_VERSION   version to install (default: latest release)
#   --bin-dir DIR      QFEX_BIN_DIR   where to put the binary for tarball installs
#   --method M         QFEX_METHOD    auto | brew | deb | tarball
#   --help

set -eu

REPO="QFEX-Org/cli"
VERSION="${QFEX_VERSION:-}"
BIN_DIR="${QFEX_BIN_DIR:-}"
METHOD="${QFEX_METHOD:-auto}"

usage() {
	cat <<'EOF'
qfex CLI installer.

  curl -fsSL https://raw.githubusercontent.com/QFEX-Org/cli/main/install.sh | sh

Detects your OS and CPU architecture, then installs the matching release:
  macOS          Homebrew if available, otherwise a tarball
  Debian/Ubuntu  the .deb package (also installs shell completions)
  other Linux    a tarball

Options (flags or environment variables):
  --version vX.Y.Z   QFEX_VERSION   version to install (default: latest release)
  --bin-dir DIR      QFEX_BIN_DIR   where to put the binary for tarball installs
  --method M         QFEX_METHOD    auto | brew | deb | tarball
  --help
EOF
}

info() { printf '%s\n' "$*" >&2; }
warn() { printf 'warning: %s\n' "$*" >&2; }
err() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

have() { command -v "$1" >/dev/null 2>&1; }

while [ $# -gt 0 ]; do
	case "$1" in
	--version)
		VERSION="${2:-}"
		shift 2
		;;
	--version=*)
		VERSION="${1#*=}"
		shift
		;;
	--bin-dir)
		BIN_DIR="${2:-}"
		shift 2
		;;
	--bin-dir=*)
		BIN_DIR="${1#*=}"
		shift
		;;
	--method)
		METHOD="${2:-}"
		shift 2
		;;
	--method=*)
		METHOD="${1#*=}"
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*) err "unknown option: $1 (try --help)" ;;
	esac
done

# fetch URL -> stdout
fetch() {
	if have curl; then
		curl -fsSL "$1"
	elif have wget; then
		wget -qO- "$1"
	else
		err "need curl or wget to download qfex"
	fi
}

# download URL FILE
download() {
	if have curl; then
		curl -fsSL -o "$2" "$1"
	elif have wget; then
		wget -qO "$2" "$1"
	else
		err "need curl or wget to download qfex"
	fi
}

detect_os() {
	case "$(uname -s)" in
	Linux) echo linux ;;
	Darwin) echo darwin ;;
	*) err "unsupported OS: $(uname -s). qfex ships binaries for Linux and macOS." ;;
	esac
}

detect_arch() {
	case "$(uname -m)" in
	x86_64 | amd64) echo amd64 ;;
	aarch64 | arm64) echo arm64 ;;
	*) err "unsupported architecture: $(uname -m). qfex ships binaries for amd64 and arm64." ;;
	esac
}

# Resolve the latest tag from the release redirect, falling back to the API.
latest_version() {
	tag=""
	if have curl; then
		url=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest" 2>/dev/null || true)
		case "$url" in
		*/tag/*) tag="${url##*/tag/}" ;;
		esac
	fi
	if [ -z "$tag" ]; then
		tag=$(fetch "https://api.github.com/repos/$REPO/releases/latest" |
			sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)
	fi
	[ -n "$tag" ] || err "could not determine the latest version. Pass one explicitly: --version v1.2.3"
	echo "$tag"
}

# Prefix for commands that need root. Empty when already root.
sudo_prefix() {
	if [ "$(id -u)" -eq 0 ]; then
		echo ""
	elif have sudo; then
		echo "sudo"
	else
		echo ""
	fi
}

# verify_checksum FILE ASSET_NAME
verify_checksum() {
	file="$1"
	name="$2"
	if have sha256sum; then
		actual=$(sha256sum "$file" | cut -d' ' -f1)
	elif have shasum; then
		actual=$(shasum -a 256 "$file" | cut -d' ' -f1)
	else
		warn "no sha256sum or shasum available, skipping checksum verification"
		return 0
	fi
	expected=$(fetch "https://github.com/$REPO/releases/download/$TAG/checksums.txt" 2>/dev/null |
		awk -v n="$name" '$2 == n || $2 == "*" n { print $1 }' | head -1)
	if [ -z "$expected" ]; then
		warn "no checksum published for $name, skipping verification"
		return 0
	fi
	[ "$actual" = "$expected" ] || err "checksum mismatch for $name (expected $expected, got $actual)"
}

install_brew() {
	info "Installing qfex with Homebrew..."
	brew install "$REPO_TAP" || err "brew install failed"
	INSTALLED_AT=$(command -v qfex || echo "$(brew --prefix)/bin/qfex")
}

install_deb() {
	asset="qfex_${VERSION_NO_V}_linux_${ARCH}.deb"
	url="https://github.com/$REPO/releases/download/$TAG/$asset"
	info "Downloading $asset..."
	download "$url" "$TMPDIR_QFEX/$asset" || err "could not download $asset. Check that $TAG exists at https://github.com/$REPO/releases"
	verify_checksum "$TMPDIR_QFEX/$asset" "$asset"

	SUDO=$(sudo_prefix)
	if [ "$(id -u)" -ne 0 ] && [ -z "$SUDO" ]; then
		err "installing the .deb needs root, but sudo is not available. Re-run as root, or use --method tarball."
	fi
	info "Installing $asset (needs root)..."
	# shellcheck disable=SC2086
	$SUDO dpkg -i "$TMPDIR_QFEX/$asset" || err "dpkg -i failed"
	INSTALLED_AT="/usr/bin/qfex"
}

install_tarball() {
	asset="qfex_${VERSION_NO_V}_${OS}_${ARCH}.tar.gz"
	url="https://github.com/$REPO/releases/download/$TAG/$asset"
	info "Downloading $asset..."
	download "$url" "$TMPDIR_QFEX/$asset" || err "could not download $asset. Check that $TAG exists at https://github.com/$REPO/releases"
	verify_checksum "$TMPDIR_QFEX/$asset" "$asset"

	tar -xzf "$TMPDIR_QFEX/$asset" -C "$TMPDIR_QFEX" qfex || err "could not extract qfex from $asset"

	SUDO=""
	if [ -z "$BIN_DIR" ]; then
		BIN_DIR="/usr/local/bin"
		if [ ! -w "$BIN_DIR" ] 2>/dev/null; then
			SUDO=$(sudo_prefix)
			if [ "$(id -u)" -ne 0 ] && [ -z "$SUDO" ]; then
				BIN_DIR="$HOME/.local/bin"
				info "No write access to /usr/local/bin and no sudo, using $BIN_DIR"
			fi
		fi
	elif [ ! -w "$BIN_DIR" ] 2>/dev/null && [ -d "$BIN_DIR" ]; then
		SUDO=$(sudo_prefix)
	fi

	# shellcheck disable=SC2086
	$SUDO mkdir -p "$BIN_DIR" || err "could not create $BIN_DIR"
	info "Installing qfex to $BIN_DIR..."
	# shellcheck disable=SC2086
	$SUDO install -m 755 "$TMPDIR_QFEX/qfex" "$BIN_DIR/qfex" || err "could not write $BIN_DIR/qfex"
	INSTALLED_AT="$BIN_DIR/qfex"

	case ":$PATH:" in
	*":$BIN_DIR:"*) ;;
	*) warn "$BIN_DIR is not on your PATH. Add it with: export PATH=\"$BIN_DIR:\$PATH\"" ;;
	esac
}

OS=$(detect_os)
ARCH=$(detect_arch)
REPO_TAP="QFEX-org/tap/qfex"

if [ -z "$VERSION" ]; then
	TAG=$(latest_version)
else
	case "$VERSION" in
	v*) TAG="$VERSION" ;;
	*) TAG="v$VERSION" ;;
	esac
fi
VERSION_NO_V="${TAG#v}"

if [ "$METHOD" = "auto" ]; then
	if [ "$OS" = "darwin" ] && have brew; then
		METHOD="brew"
	elif [ "$OS" = "linux" ] && have dpkg; then
		METHOD="deb"
	else
		METHOD="tarball"
	fi
fi

case "$METHOD" in
brew | deb | tarball) ;;
*) err "unknown method: $METHOD (expected auto, brew, deb or tarball)" ;;
esac

TMPDIR_QFEX=$(mktemp -d "${TMPDIR:-/tmp}/qfex-install.XXXXXX")
trap 'rm -rf "$TMPDIR_QFEX"' EXIT INT TERM

info "qfex $TAG  ($OS/$ARCH, via $METHOD)"
case "$METHOD" in
brew)
	have brew || err "--method brew requires Homebrew"
	install_brew
	;;
deb)
	[ "$OS" = "linux" ] || err "--method deb only works on Linux"
	have dpkg || err "--method deb requires dpkg (Debian/Ubuntu)"
	install_deb
	;;
tarball) install_tarball ;;
esac

installed_version=$("$INSTALLED_AT" version 2>/dev/null || echo "")
if [ -n "$installed_version" ]; then
	info ""
	info "Installed qfex $installed_version to $INSTALLED_AT"
else
	info ""
	info "Installed qfex to $INSTALLED_AT"
fi
if [ "$METHOD" != "deb" ]; then
	info "Shell completions: qfex completion --help"
fi
info "Next: run 'qfex login' to authenticate, then 'qfex --help'."
