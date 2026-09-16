#!/bin/bash

# Put this person's age identity in place at ~/.config/beet/age/keys.txt, either
# restored from a passphrase-encrypted backup or freshly generated.
#
# The identity is PER PERSON, not per device: it is the one key that decrypts
# every beet vault (the committed `.env.age` files, the exported stack secrets),
# so a new machine RESTORES it from the backup rather than generating a second
# one that can read nothing. Generate only on the very first machine, then
# `beet secrets/backup` it onto a USB stick before anything depends on it.
# ~/.config/beet is deliberately NOT stowed: a private key never enters a repo.
#
# usage: just setup-age-identity [backup.age]

set -euo pipefail

BACKUP="${1:-}"
DIR=~/.config/beet/age
KEYS="$DIR/keys.txt"

mkdir -p "$DIR"
chmod 700 "$DIR"

if [[ -f "$KEYS" ]]; then
  echo "== identity already exists: $KEYS (leaving it alone)"
elif [[ -n "$BACKUP" ]]; then
  echo "== restoring the identity from $BACKUP (age will ask for the passphrase)"
  age -d -o "$KEYS" "$BACKUP"
else
  echo "== no backup given, generating a NEW identity on $(hostnamectl --static 2>/dev/null || hostname)"
  echo "   only do this on your first machine; every other machine restores:"
  echo "   just setup-age-identity /path/to/backup.age"
  age-keygen -o "$KEYS"
fi
chmod 600 "$KEYS"

echo
echo "== public key (recipient): add this to the vault declarations, ie <Vault recipients={[..]}/>"
echo
age-keygen -y "$KEYS"
echo
if [[ -z "$BACKUP" ]]; then
  echo "== back it up before anything depends on it:"
  echo "   beet secrets/backup   (a passphrase-encrypted copy for a USB stick and a printout)"
  echo "   or, before beet is built:  age -p -o keys.txt.age $KEYS"
fi
