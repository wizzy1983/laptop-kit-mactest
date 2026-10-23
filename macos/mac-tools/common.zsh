# common.zsh: sourced by clean-mac.zsh. Logging, the lists the report is built from, the users, quarantine and undo.
# The caller sets WORK (results folder on the drive), UNDO, LOG and QUAR before sourcing.
typeset -ga Removed Attention Notes Fyi Problems

ts()        { date '+%-I:%M%p' | tr 'APM' 'apm' }
say()       { print -r -- "$*" >> "$LOG"; print -r -- "$*" }
step()      { say ""; say "== $(ts) $*"; print -r -- "$(date '+%H:%M:%S') $*" >> "$WORK/progress.txt" }
note()      { Notes+=("$*"); say "  NOTE: $*" }
removed()   { Removed+=("$*"); say "  REMOVED: $*" }
attention() { Attention+=("$*"); say "  NEEDS A PERSON: $*" }
problem()   { Problems+=("$*"); say "  PROBLEM: $*" }
fyi()       { Fyi+=("$*"); print -r -- "  FYI: $*" >> "$LOG" }
# Runs a command for at most $1 seconds (stock macOS has no "timeout"; an alarm survives exec). Exit 142 = timed out.
limit()     { local s=$1; shift; /usr/bin/perl -e 'alarm shift; exec @ARGV or exit 127' "$s" "$@" }

# Real user accounts: "name home" lines (UID 501 and up, home folder under /Users).
kit_users() {
  local u id h
  /usr/bin/dscl . -list /Users UniqueID | while read -r u id; do
    (( id >= 501 && id < 100000 )) || continue
    h=$(/usr/bin/dscl . -read "/Users/$u" NFSHomeDirectory 2>/dev/null | /usr/bin/awk '{print $2}')
    [[ -d $h && $h == /Users/* ]] && print -r -- "$u $h"
  done
}

# Moves a file or folder into the quarantine folder on this Mac, keeping its full path under it. Never deletes.
quarantine() {
  local p=$1
  [[ -e $p || -L $p ]] || return 1
  local dest="$QUAR${p:h}"
  /bin/mkdir -p "$dest" || return 1
  if ! /bin/mv -f "$p" "$dest/" 2>>"$LOG"; then
    /bin/cp -Rp "$p" "$dest/" 2>>"$LOG" && /bin/rm -rf "$p"
  fi
  [[ ! -e $p && ! -L $p ]]
}

# Saves a copy of a file to the undo folder before it is changed.
save_undo() {
  [[ -e $1 ]] || return 0
  /bin/mkdir -p "$UNDO"
  /bin/cp -p "$1" "$UNDO/${${1#/}//\//_}-$(date +%H%M%S)" 2>>"$LOG"
}

# Full Disk Access for Terminal (root alone is not enough): this file can only be read with it.
kit_has_fda() { /bin/cat "/Library/Application Support/com.apple.TCC/TCC.db" >/dev/null 2>&1 }

# The person signed in at the screen, and their numeric id.
console_user() { /usr/bin/stat -f %Su /dev/console }
