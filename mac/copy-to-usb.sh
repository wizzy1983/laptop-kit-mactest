#!/bin/zsh
# copy-to-usb.sh "/Volumes/<drive>" : copies the kit (the Windows kit: START-HERE.bat, READ-ME.txt, tools/*.ps1; the
# Mac kit: START-HERE-MAC.command, READ-ME-MAC.txt, mac-tools/*) to the root of the USB drive, without macOS extra files
# or download marks, then proves every file on the drive matches the Mac copy byte for byte (SHA-256).
# It never formats or deletes anything except the kit's own files and the macOS "._" files next to them.
# Run with bash it would copy only the first file ($FILES is a zsh array; 2026-10-23 11:41am), so it restarts in zsh.
[ -n "${ZSH_VERSION:-}" ] || exec /bin/zsh "$0" "$@"
set -eu
VOL="${1:?usage: copy-to-usb.sh /Volumes/<drive>}"
KIT="$(cd "$(dirname "$0")/.." && pwd)"
[ -d "$VOL" ] || { echo "not a mounted volume: $VOL"; exit 1; }
FS=$(diskutil info "$VOL" | awk -F: '/Type \(Bundle\)/{gsub(/ /,"",$2);print $2}')
echo "drive: $VOL  file system: $FS  free: $(df -h "$VOL" | awk 'NR==2{print $4}')"
# source path in the kit folder -> path on the drive
FILES=(START-HERE.bat READ-ME.txt tools/Clean-Laptop.ps1 tools/Common.ps1 tools/After-Restart.ps1 tools/Find-Unwanted.ps1
  macos/START-HERE-MAC.command macos/READ-ME-MAC.txt macos/mac-tools/clean-mac.zsh macos/mac-tools/common.zsh
  macos/mac-tools/find-unwanted.zsh macos/mac-tools/browsers.js macos/mac-tools/inspect.js)
dest() { print -r -- "${1#macos/}" }
mkdir -p "$VOL/tools" "$VOL/mac-tools"
for f in $FILES; do cp -X "$KIT/$f" "$VOL/$(dest $f)"; done
# A quarantined .command cannot be opened by double-click; exFAT keeps no marks, but strip them in case it ever does.
xattr -cr "$VOL/START-HERE-MAC.command" "$VOL/mac-tools" 2>/dev/null || true
dot_clean -m "$VOL" 2>/dev/null || true
find "$VOL" -maxdepth 2 -name '._*' -delete 2>/dev/null || true
sync
bad=0
for f in $FILES; do
  a=$(shasum -a 256 "$KIT/$f" | cut -d' ' -f1); b=$(shasum -a 256 "$VOL/$(dest $f)" | cut -d' ' -f1)
  if [ "$a" = "$b" ]; then echo "OK   $(dest $f)  $a"; else echo "DIFF $(dest $f)"; bad=1; fi
done
[ -x "$VOL/START-HERE-MAC.command" ] || { echo "NOT RUNNABLE: START-HERE-MAC.command"; bad=1; }
[ -z "$(xattr "$VOL/START-HERE-MAC.command" 2>/dev/null)" ] || { echo "HAS MARKS: START-HERE-MAC.command $(xattr "$VOL/START-HERE-MAC.command")"; bad=1; }
echo "files checked: ${#FILES} (all must say OK)"
echo "on the drive now:"; ls -la "$VOL" "$VOL/tools" "$VOL/mac-tools"
exit $bad
