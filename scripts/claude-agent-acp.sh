#!/usr/bin/env bash
# claude-agent-acp — self-updating launcher for the Zed agent panel's ACP adapter.
#
# This is a hand-rolled twin of the wrapper `omarchy-mise-install` generates, with one
# required difference: the `mise use` line has its stdout redirected to stderr.
#
# omarchy's generated wrappers run `mise use -g <pkg>` before exec'ing the real tool, and
# mise prints "mise <config> tools: <pkg>@<version>" to STDOUT on EVERY run, not only when
# it installs something. For a TUI like claude or codex that line is cosmetic. Here it is
# not: Zed speaks ACP to this process, which is JSON-RPC over stdio, so a non-JSON line at
# the head of stdout corrupts the protocol stream on every single launch. scripts/acp-tee.sh
# passes stdout through byte for byte by design, so it will not paper over this either.
#
# Kept from omarchy's version: the tool installs on first use and self-updates thereafter,
# and MISE_MINIMUM_RELEASE_AGE=0 bypasses mise's release cooldown, which would otherwise
# hold a new adapter back for days after it ships.
#
# Two deliberate departures beyond the redirect:
#   - install progress stays on stderr rather than being silenced with MISE_QUIET=1, since
#     a first run downloads ~100MB and should not look like a hang.
#   - a failed `mise use` is a warning, not a fatal error (omarchy's wrapper exits 1). An
#     editor integration should still open offline if a version is already installed; if
#     none is, the `mise x` below fails on its own with a clearer message.
set -euo pipefail

pkg="npm:@agentclientprotocol/claude-agent-acp"

export MISE_MINIMUM_RELEASE_AGE=0

mise use -g "$pkg" >&2 ||
	echo "claude-agent-acp: could not check for updates, using the installed version" >&2

exec mise x "$pkg" -- claude-agent-acp "$@"
