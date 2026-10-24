#!/usr/bin/env bash
# Installs a tool for the checks under $RUNNER_TEMP and puts it on PATH of the following steps.
# Usage: install-tools.sh fzf|bats|shellcheck|fish|herdr VERSION
# fish is installed only on macOS; Ubuntu installs it with apt.
set -euo pipefail

tool=$1
version=$2

case $tool in
  fzf)
    os=$(uname -s | tr '[:upper:]' '[:lower:]')
    case $(uname -m) in
      x86_64) arch=amd64 ;;
      *) arch=arm64 ;;
    esac
    dir=$RUNNER_TEMP/fzf
    mkdir -p "$dir"
    curl -fsSL "https://github.com/junegunn/fzf/releases/download/v$version/fzf-$version-${os}_$arch.tar.gz" | tar -xz -C "$dir"
    ;;
  bats)
    git -c advice.detachedHead=false clone --quiet --depth 1 --branch "v$version" https://github.com/bats-core/bats-core.git "$RUNNER_TEMP/bats-core"
    dir=$RUNNER_TEMP/bats-core/bin
    ;;
  shellcheck)
    curl -fsSL "https://github.com/koalaman/shellcheck/releases/download/v$version/shellcheck-v$version.linux.x86_64.tar.xz" | tar -xJ -C "$RUNNER_TEMP"
    dir=$RUNNER_TEMP/shellcheck-v$version
    ;;
  fish)
    curl -fsSL -o "$RUNNER_TEMP/fish.app.zip" "https://github.com/fish-shell/fish-shell/releases/download/$version/fish-$version.app.zip"
    ditto -x -k "$RUNNER_TEMP/fish.app.zip" "$RUNNER_TEMP/fish"
    dir=$RUNNER_TEMP/fish/fish-$version.app/Contents/Resources/base/usr/local/bin
    ;;
  herdr)
    case $(uname -s) in
      Darwin) os=macos ;;
      *) os=linux ;;
    esac
    case $(uname -m) in
      x86_64) arch=x86_64 ;;
      *) arch=aarch64 ;;
    esac
    dir=$RUNNER_TEMP/herdr
    mkdir -p "$dir"
    curl -fsSL -o "$dir/herdr" "https://github.com/herdrdev/herdr/releases/download/v$version/herdr-$os-$arch"
    chmod +x "$dir/herdr"
    ;;
  *)
    echo "install-tools.sh: unknown tool: $tool" >&2
    exit 2
    ;;
esac

echo "$dir" >> "$GITHUB_PATH"
