#!/usr/bin/env bash
# Text-to-speech of the current selection via the local Kokoro server — the mirror
# image of the voxtype dictation flow: highlight text, press the bind, hear it read;
# press again to stop. Bound to SHIFT+PAUSE / SHIFT+INSERT in bindings.conf.
#
# Kokoro streams raw 24kHz mono PCM, which we pipe straight into pw-play so audio
# starts as soon as the first chunk lands rather than after full synthesis.
set -uo pipefail

PORT=9000
VOICE=am_michael
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

case "${1:-toggle}" in
	stop)
		stop
		exit 0
		;;
	toggle)
		# second press while still playing = stop
		if [ -f "$pidfile" ] && kill -0 "$(head -1 "$pidfile" 2>/dev/null)" 2>/dev/null; then
			stop
			exit 0
		fi
		;;
esac

text="$(wl-paste --primary --no-newline 2>/dev/null)"
if [ -z "${text// /}" ]; then
	notify-send -a TTS "Nothing selected" "Highlight some text first." 2>/dev/null || true
	exit 0
fi

# fire the synth->playback pipeline in the background; clear the pidfile when it ends
# on its own so the next press starts fresh rather than thinking it's still playing.
{
	curl -sS -N -X POST "http://127.0.0.1:${PORT}/v1/audio/speech" \
		-H "Content-Type: application/json" \
		-d "$(jq -n --arg t "$text" --arg v "$VOICE" \
			'{model:"kokoro", input:$t, voice:$v, response_format:"pcm"}')" |
		pw-play --raw --format=s16 --rate=24000 --channels=1 -
	rm -f "$pidfile"
} &
echo "$!" >"$pidfile"
