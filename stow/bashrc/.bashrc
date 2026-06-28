# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
source ~/.local/share/omarchy/default/bash/rc
#
# Set a custom prompt with the directory revealed (alternatively use https://starship.rs)
# PS1="\W \[\e]0;\w\a\]$PS1"
# . "$HOME/.cargo/env"

alias hx='helix'

export EDITOR="zed"
# NOTE: deliberately no CARGO_TARGET_DIR. A single shared target dir made every
# git worktree build into the same place, so parallel agents serialized on the
# build lock and thrashed each other's fingerprints. Each checkout/worktree now
# uses its own local ./target (cargo's default). Shared dep builds are recovered
# via the sccache compile cache below instead.
export SCCACHE_DIR="$HOME/.cargo_sccache"
export SCCACHE_CACHE_SIZE="150G"
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="/home/pete/.local/bin:$PATH"

# Copy current prompt line to clipboard (Ctrl+Y)
if command -v wl-copy &> /dev/null; then
  copy_line_to_clipboard() {
    printf %s "$READLINE_LINE" | wl-copy
  }
  bind -x '"\C-y": copy_line_to_clipboard'
fi

# if [[ "$PWD" == "$HOME" ]]; then
#   cd ~/me
# fi

# add Pulumi to the PATH
export PATH=$PATH:/home/pete/.pulumi/bin

# Vite+ bin (https://viteplus.dev)
. "$HOME/.vite-plus/env"
