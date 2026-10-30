#!/usr/bin/env bash
# Open an agent board region, or close it when it is already open.
# Usage: toggle.sh [board|strip]   (board is the right edge, strip the bottom)
set -u
HERDR="${HERDR_BIN_PATH:-herdr}"
plugin="${HERDR_PLUGIN_ID:-demo.agent-board}"
entrypoint="${1:-board}"
region=$("$HERDR" region list | jq -r --arg plugin "$plugin" --arg entrypoint "$entrypoint" \
  '.result.regions // [] | map(select(.plugin_id == $plugin and .entrypoint == $entrypoint)) | .[0].region_id // empty')
if [ -n "$region" ]; then
  exec "$HERDR" region close "$region"
fi
exec "$HERDR" region open "$plugin" "$entrypoint"
