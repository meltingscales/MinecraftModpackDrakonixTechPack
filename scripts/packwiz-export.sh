#!/usr/bin/env bash
# Builds build/server (real NeoForge server install + mods) and the client .mrpack.
# Called by `just packwiz-export` - see justfile for the fetch-installer/
# fetch-neoforge-installer prerequisites this assumes are already present.
set -euo pipefail

PACK_VERSION="$1"
NEOFORGE_VERSION="$2"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

rm -rf build
mkdir -p build/server
(cd build/server && java -jar "../../neoforge-${NEOFORGE_VERSION}-installer.jar" --installServer)

cd pack
packwiz serve &
SERVE_PID=$!
trap 'kill "$SERVE_PID" 2>/dev/null || true' EXIT
sleep 1
(cd ../build/server && java -jar ../../packwiz-installer-bootstrap.jar -g -s server http://localhost:8080/pack.toml)
kill "$SERVE_PID" 2>/dev/null || true
packwiz modrinth export -y -o "../build/drakonixtechpack-${PACK_VERSION}-client.mrpack"
cd ../build
(cd server && zip -qr "../drakonixtechpack-${PACK_VERSION}-server.zip" .)
