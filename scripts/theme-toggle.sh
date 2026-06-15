#!/bin/bash

# Toggle between a dark and a light Omarchy theme.
# Decides direction by checking whether the current theme is a light theme
# (Omarchy marks light themes with a light.mode file in the theme dir).

DARK_THEME="Everforest"
LIGHT_THEME="Solarized Light"

if [[ -f ~/.config/omarchy/current/theme/light.mode ]]; then
  omarchy theme set "$DARK_THEME"
else
  omarchy theme set "$LIGHT_THEME"
fi
