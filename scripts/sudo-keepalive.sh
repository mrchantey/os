#!/usr/bin/env bash
# Run a long, sudo-heavy command and only ever be asked for the password once.
#
#   sudo-keepalive.sh <command> [args...]
#
# sudo remembers an authentication for `timestamp_timeout`, five minutes by
# default and not overridden on this machine (`sudo -l` shows only secure_path
# and passwd_tries=10). A single `sudo -v` at the top of a long install is
# therefore worthless: `pacman -Syu`, a yay AUR build, or cargo-binstall over a
# slow link all outrun five minutes on their own, and the NEXT sudo call part way
# through prompts again. If nobody is sitting at the terminal, that prompt then
# dies of `passwd_timeout` (also five minutes) and takes the whole run with it:
#
#   sudo pacman -S --noconfirm --needed rustup cargo-binstall
#   [sudo] password for pete:
#   sudo: timed out reading password
#   error: recipe `install-rust` failed on line 201 with exit code 1
#
# That is a real failure from `just init-silver-fox-sudo` on 2026-09-10, about
# halfway in, after the user had walked away from an install that legitimately
# takes an hour.
#
# So: authenticate once here, then refresh the timestamp from the background for
# as long as the command runs. One prompt, at the very start, while the user is
# still watching. Nothing is written to /etc/sudoers -- this only re-asserts an
# authentication the user already gave, and it stops the moment we exit.
set -euo pipefail

[[ $# -gt 0 ]] || {
	echo "usage: $(basename "$0") <command> [args...]" >&2
	exit 2
}

# The one and only prompt. `set -e` aborts here if the user cannot authenticate,
# rather than letting a whole install run and fail on its first pacman call.
sudo -v

# `set -m` gives this background job its own process group, whose id is the job's
# pid. That is what makes the cleanup below able to take the whole loop down in
# one go. Without it, killing the loop's subshell while it sits in `sleep` leaves
# the sleep behind as an orphan reparented to init -- harmless, since it exits on
# its own, but it means the script does not fully clean up after itself.
set -m
# Refresh well inside the five-minute window. `kill -0 $$` makes the loop exit if
# this script is killed outright, so even a SIGKILL cannot strand it looping
# forever holding sudo open.
while true; do
	sudo -n true 2>/dev/null || true
	sleep 50
	kill -0 "$$" 2>/dev/null || exit 0
done &
keepalive=$!
set +m

# Drop the refresher however we leave: success, failure, or Ctrl-C. The leading
# `-` makes this a process-group kill, so the in-flight `sleep` goes too.
trap 'kill -- -"${keepalive}" 2>/dev/null || true' EXIT

"$@"
