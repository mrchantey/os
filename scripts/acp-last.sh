#!/usr/bin/env bash
# acp-last — print the most recent thing a coding agent said, as plain speakable text.
#
# Reads the tap that scripts/acp-tee.sh leaves in $XDG_RUNTIME_DIR/acp (newest log wins, so
# the agent you last talked to is the one you hear). Provider-agnostic: it only knows the
# Agent Client Protocol, not any particular agent.
#
# "The most recent thing it said" = the last unbroken run of agent_message_chunk text. A
# reply arrives as many chunks that concatenate into one message, and acp-tee marks every
# tool call, thinking block and turn end with a break, so the final run is the final answer
# rather than the whole turn. Press the key mid-turn and you get the preamble it has said
# so far, which is the honest answer to "what did it just say".
set -uo pipefail

dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/acp"
log="$(ls -t "$dir"/*.ndjson 2>/dev/null | head -1)"
[ -n "$log" ] && [ -s "$log" ] || exit 0

raw="$(jq -rs '
	[ .[]
	  | if .acpBreak then
	      {k: "break"}
	    else
	      (.params.update.content // {})
	      | if .type == "text" then {k: "text", t: .text} else {k: "break"} end
	    end
	]
	| reverse as $r
	# skip back over any breaks at the tail, then take the run of text below them
	| ([ range(0; ($r | length)) | select($r[.].k == "text") ] | first) as $start
	| if $start == null then
	    ""
	  else
	    ($r[$start:]) as $tail
	    | ([ range(0; ($tail | length)) | select($tail[.].k != "text") ] | first) as $stop
	    | (if $stop == null then $tail else $tail[0:$stop] end)
	    | reverse | map(.t) | join("")
	  end
' "$log" 2>/dev/null)"

[ -n "${raw// /}" ] || exit 0

# Strip the markdown that reads badly out loud: code fences and tables go entirely, the
# rest keeps its words and loses its punctuation.
text="$(printf '%s' "$raw" | perl -0777 -pe '
	s/```.*?```//gs;
	s/^\s*\|.*\|\s*$//mg;
	s/!\[[^\]]*\]\([^)]*\)//g;
	s/\[([^\]]*)\]\([^)]*\)/$1/g;
	s/^\s{0,3}#{1,6}\s*//mg;
	s/`([^`]*)`/$1/g;
	s/\*\*([^*]+)\*\*/$1/g;
	s/(?<!\*)\*([^*\n]+)\*(?!\*)/$1/g;
	s/^\s*[-*+]\s+/ /mg;
	s/^\s*[-=_]{3,}\s*$//mg;
	s/[ \t]+$//mg;
	s/\n{3,}/\n\n/g;
')"

text="${text#"${text%%[![:space:]]*}"}"    # trim leading whitespace
text="${text%"${text##*[![:space:]]}"}"    # trim trailing whitespace
[ -n "$text" ] || exit 0

# A wall of text is a minute of monologue; cut it at a word and say so.
MAX_CHARS=4000
if [ "${#text}" -gt "$MAX_CHARS" ]; then
	text="${text:0:$MAX_CHARS}"
	text="${text% *}, and there is more on screen."
fi

printf '%s\n' "$text"
