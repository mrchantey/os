#!/usr/bin/env bash
# acp-tee — run an ACP coding agent with its output stream tapped, so the last reply can
# be read aloud on a keypress (scripts/acp-last.sh + `tts last`).
#
#   usage: acp-tee.sh <agent-command> [args...]
#
# Zed's agent panel speaks the Agent Client Protocol to whatever binary it spawns: JSON-RPC
# as newline-delimited JSON over stdio. Nothing provider-specific lives in that stream, so
# tapping it here covers every ACP agent (claude, opencode, anything added later) with one
# script — the reason this sits in front of the agent command rather than hooking into any
# single agent's own event system.
#
# Wire it up in ~/.config/zed/settings.json by turning the agent's `agent_servers` entry
# from "type": "registry" into "type": "custom" with this script as the command and the
# real agent as the args.
#
# Shape of the tap:
#
#   agent ──stdout──> tee ──> Zed        (the protocol, byte for byte, untouched)
#                      └────> awk ──> log
#
# `tee` sits in the data path because it is the dumbest thing that can do the job; the awk
# filter hangs off a side branch so a mistake in it can never corrupt what Zed receives.
# --output-error=warn-nopipe keeps the agent alive even if that branch dies. The filter
# exists so the log stays kilobytes: a raw tap would spool every tool result through RAM
# (the log lives on tmpfs), and all we need are the reply chunks plus enough markers to
# know where one reply stops and the next begins.
set -uo pipefail

[ "$#" -ge 1 ] || { echo "usage: acp-tee.sh <agent-command> [args...]" >&2; exit 2; }

dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/acp"
mkdir -p "$dir"

# Drop logs belonging to agents that have exited. Keyed on pid rather than age because a
# session can sit idle for hours and must not have its log deleted out from under it.
for old in "$dir"/*.ndjson; do
	[ -e "$old" ] || continue
	oldpid="${old##*-}"
	oldpid="${oldpid%.ndjson}"
	case "$oldpid" in
		''|*[!0-9]*) continue ;;
	esac
	kill -0 "$oldpid" 2>/dev/null || rm -f "$old"
done

# $$ survives the exec below, so the agent's own pid names its log.
name="${ACP_TEE_NAME:-$(basename "$1")}"
log="$dir/${name}-$$.ndjson"
: >"$log"

# Kept: agent_message_chunk lines (the reply itself).
# Reduced to a bare marker: anything that ends a run of reply text, so acp-last.sh can tell
# "the last thing it said" from text emitted earlier in the same turn. A tool call, a
# thinking block or the response that settles the turn (stopReason) all close a run.
# Dropped: everything else, including subagent chunks, which carry parentToolUseId and are
# a subagent talking to its parent rather than the agent talking to you.
# The filter writes only to the log and never to its own stdout: it shares that stdout with
# tee, so anything it printed would land in Zed's stream twice.
exec "$@" > >(tee --output-error=warn-nopipe >(exec awk -v out="$log" '
	/"sessionUpdate":"agent_message_chunk"/ {
		if ($0 !~ /parentToolUseId/) { print >> out; fflush(out); brk = 0 }
		next
	}
	/"sessionUpdate":"(tool_call|tool_call_update|agent_thought_chunk|user_message_chunk)"/ ||
	/"stopReason":/ {
		# one marker per run: a tool-heavy turn is thousands of these and they all mean
		# the same thing to the reader, which is "the reply text stopped here".
		if (!brk) { print "{\"acpBreak\":true}" >> out; fflush(out); brk = 1 }
	}
'))
