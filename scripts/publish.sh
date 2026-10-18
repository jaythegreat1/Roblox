#!/usr/bin/env bash
# Builds the place with Rojo and publishes it through Roblox Open Cloud.
# Needs ROBLOX_API_KEY in the environment; the key is never written to disk.
set -euo pipefail
UNIVERSE_ID=7468074111
PLACE_ID=130598952496463
: "${ROBLOX_API_KEY:?Set ROBLOX_API_KEY}"
mkdir -p build
rojo build default.project.json -o build/BladeRift.rbxl
curl -sS --fail-with-body -X POST \
  "https://apis.roblox.com/universes/v1/${UNIVERSE_ID}/places/${PLACE_ID}/versions?versionType=Published" \
  -H "x-api-key: ${ROBLOX_API_KEY}" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @build/BladeRift.rbxl
echo
