#!/usr/bin/env bash
# Text-to-speech via the local Kokoro server. Two ways in:
#
#   1. Keybind/selection flow (mirror of the voxtype dictation flow): highlight
#      text, press the bind, hear it read; press again to stop. This is the
#      `toggle` mode, bound to SHIFT+PAUSE / SHIFT+INSERT in bindings.conf.
#   2. CLI flow: `tts gday mate` speaks the literal arguments; `echo hi | tts`
#      speaks stdin. Symlinked onto PATH as `tts` (see `just install-tts`).
#
# `tts stop` halts whatever is currently playing.
#
# Kokoro streams raw 24kHz mono PCM, which we pipe straight into pw-play so audio
# starts as soon as the first chunk lands rather than after full synthesis.
set -uo pipefail

PORT=9000
VOICE=am_michael
SPEED=1.5   # playback rate, 0.25-4.0 (1.0 = normal)
runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/tts"
mkdir -p "$runtime"
pidfile="$runtime/play.pid"

stop() {
	# kill the pipeline subshell and its children (curl + pw-play) so sound halts now
	[ -f "$pidfile" ] || return 0
	local pid
	pid="$(head -1 "$pidfile" 2>/dev/null)"
	if [ -n "$pid" ]; then
		pkill -TERM -P "$pid" 2>/dev/null || true
		kill -TERM "$pid" 2>/dev/null || true
	fi
	rm -f "$pidfile"
}

playing() {
	[ -f "$pidfile" ] && kill -0 "$(head -1 "$pidfile" 2>/dev/null)" 2>/dev/null
}

# fire the synth->playback pipeline in the background; clear the pidfile when it ends
# on its own so the next invocation starts fresh rather than thinking it's still playing.
speak() {
	local text="$1"
	{
		curl -sS -N -X POST "http://127.0.0.1:${PORT}/v1/audio/speech" \
			-H "Content-Type: application/json" \
			-d "$(jq -n --arg t "$text" --arg v "$VOICE" --argjson s "$SPEED" \
				'{model:"kokoro", input:$t, voice:$v, speed:$s, response_format:"pcm"}')" |
			pw-play --raw --format=s16 --rate=24000 --channels=1 -
		rm -f "$pidfile"
	} &
	echo "$!" >"$pidfile"
}

# Bare `tts` defaults to the keybind's toggle/selection flow, EXCEPT when stdin is
# piped in (`echo hi | tts`), in which case we speak that.
mode="${1:-toggle}"
if [ "$#" -eq 0 ] && [ ! -t 0 ]; then
	mode="__cli__"
fi

case "$mode" in
	stop)
		stop
		exit 0
		;;
	toggle)
		# second press while still playing = stop; otherwise read the selection
		if playing; then
			stop
			exit 0
		fi
		text="$(wl-paste --primary --no-newline 2>/dev/null)"
		if [ -z "${text// /}" ]; then
			notify-send -a TTS "Nothing selected" "Highlight some text first." 2>/dev/null || true
			exit 0
		fi
		;;
	__cli__)
		# bare invocation with piped stdin: speak it
		text="$(cat)"
		if [ -z "${text// /}" ]; then
			echo "usage: tts <text>   |   <cmd> | tts   |   tts stop" >&2
			exit 1
		fi
		stop   # halt any in-flight playback before starting a new phrase
		;;
	*)
		# CLI: speak the literal arguments
		text="$*"
		if [ -z "${text// /}" ]; then
			echo "usage: tts <text>   |   <cmd> | tts   |   tts stop" >&2
			exit 1
		fi
		stop   # halt any in-flight playback before starting a new phrase
		;;
esac

speak "$text"
