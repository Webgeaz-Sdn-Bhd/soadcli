#!/usr/bin/env bash
set -euo pipefail

repo=Webgeaz-Sdn-Bhd/soadcli
os="$(uname -s | tr '[:upper:]' '[:lower:]')"
arch="$(uname -m)"

case "$os" in
  darwin|linux) ;;
  *) echo "Unsupported OS: $os. See https://github.com/$repo/releases." >&2; exit 1 ;;
esac

case "$arch" in
  x86_64|amd64) arch=amd64 ;;
  arm64|aarch64) arch=arm64 ;;
  *) echo "Unsupported architecture: $arch." >&2; exit 1 ;;
esac

archive="sufia_${os}_${arch}.tar.gz"
tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "$tmp_dir"' EXIT

echo "Downloading $archive..."
curl -fsSL "https://github.com/$repo/releases/latest/download/$archive" -o "$tmp_dir/$archive"
tar -xzf "$tmp_dir/$archive" -C "$tmp_dir" sufia
sudo install -m 0755 "$tmp_dir/sufia" /usr/local/bin/sufia

echo "Installed sufia to /usr/local/bin/sufia."
