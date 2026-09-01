#!/bin/bash
# Chrome-shaped front end for launch-here.sh, used as the Exec of our shadowing
# google-chrome.desktop.
#
# It exists because several omarchy scripts resolve "the browser" by taking the
# FIRST whitespace-delimited token of the desktop file's Exec= line and then
# calling it with chrome's own flags:
#
#   omarchy-launch-webapp   -> $first_token --app=<url>
#   omarchy-launch-browser  -> $first_token [--incognito] [url]
#
# So the first token has to be a drop-in for google-chrome-stable, taking only
# chrome arguments. Pointing Exec straight at launch-here.sh made those calls
# land on its <class-regex> <new-window-flag> <command> signature instead, and
# every webapp keybind became a silent usage error.
#
# Everything else (which class to match, which flag opens a new window) is
# baked in here rather than passed by the caller.

exec "$(dirname "$(realpath "$0")")/launch-here.sh" \
  '^google-chrome$' --new-window /usr/bin/google-chrome-stable "$@"
