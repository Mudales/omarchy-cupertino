#!/bin/bash

# Install this desktop style on a fresh Omarchy machine: the Cupertino look
# plus the Tahoe lock screen it was drawn next to. Both land as ordinary
# git-managed plugin checkouts, so `omarchy plugin update` keeps working on
# each of them afterwards.
#
#   git clone https://github.com/Mudales/omarchy-cupertino
#   ./omarchy-cupertino/bootstrap.sh
#
# The clone you run this from is just the installer; the live copies go to
# ~/.config/omarchy/plugins/. Override either source with CUPERTINO_URL or
# TAHOE_LOCK_URL in the environment.

set -euo pipefail

PLUGINS_DIR="$HOME/.config/omarchy/plugins"
CUPERTINO_ID="io.github.mudales.cupertino"
TAHOE_LOCK_ID="tahoe.lock"
CUPERTINO_URL="${CUPERTINO_URL:-https://github.com/Mudales/omarchy-cupertino}"
TAHOE_LOCK_URL="${TAHOE_LOCK_URL:-https://github.com/Mudales/omarchy-tahoe-lock}"

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# A fork installs itself, not the upstream it was forked from.
if origin=$(git -C "$script_dir" remote get-url origin 2>/dev/null) && [[ -n $origin ]]; then
  CUPERTINO_URL="$origin"
fi

command -v omarchy >/dev/null 2>&1 ||
  { echo "bootstrap: omarchy is not on PATH — this needs Omarchy 4.x" >&2; exit 1; }

install_plugin() {
  local id="$1" url="$2"

  if [[ -d "$PLUGINS_DIR/$id" ]]; then
    # Bash reads a script as it runs it, so never let a pull rewrite the file
    # currently executing.
    if [[ "$script_dir" == "$PLUGINS_DIR/$id" ]]; then
      echo "==> $id is the checkout running this script; leaving it alone"
    else
      echo "==> $id already installed; updating"
      omarchy plugin update "$id" --yes || echo "    (update skipped)"
    fi
  else
    echo "==> adding $id from $url"
    omarchy plugin add "$url" --enable --yes
  fi

  # `add --enable` already wrote the shell.json entry; this covers a checkout
  # that was dropped in by hand, and is a no-op when it is already enabled.
  omarchy plugin enable "$id" >/dev/null 2>&1 || true
}

install_plugin "$CUPERTINO_ID" "$CUPERTINO_URL"
install_plugin "$TAHOE_LOCK_ID" "$TAHOE_LOCK_URL"

echo "==> restarting the shell"
omarchy restart shell

cat <<'DONE'

Done. Both plugins are services, so the restart above is what put them live.

  omarchy-shell lock preview                 check the lock screen safely
  ~/.config/omarchy/shell.json               radius / chrome settings, hot-reloaded
  omarchy plugin update                      pull later changes to both

DONE
