#!/bin/zsh
# Double-clicked in Finder on the USB drive. Asks for this Mac's password once, checks that Terminal may read every
# file (Full Disk Access; without it macOS hides Safari and the personal folders even from an administrator), then
# runs the kit as administrator from a copy on the Mac. Research: research/2026-10-23-mac-protections-cli.md.
KIT="${0:A:h}"
TEST=${KIT_TEST:-0}
clear
print "LAPTOP CLEANUP KIT (Mac)"
print ""
print "Keep the charger plugged in and the lid open. It takes about 1 to 2 hours"
print "(longer when there are many photos to back up)."
print "If the Mac asks whether Terminal may use files on a removable volume, click Allow."
print ""
# Touching the drive now makes macOS ask its removable-volume question while someone is here to answer it.
if ! { touch "$KIT/.kit-write-test" && rm -f "$KIT/.kit-write-test" }; then
  print "The kit cannot write to the USB drive. Click Allow when asked, or check the drive, then start again."
  exit 1
fi
print "Type this Mac's login password below and press Return."
print "(Nothing shows while you type. That is normal.)"
print ""
if ! /usr/bin/sudo -v -p "Password: "; then
  print ""
  print "The password was not accepted, or this account is not an administrator."
  print "Close this window and double-click START-HERE-MAC again, signed in as an administrator."
  exit 1
fi
if [[ $TEST != 1 ]] && ! /usr/bin/sudo /bin/cat "/Library/Application Support/com.apple.TCC/TCC.db" >/dev/null 2>&1; then
  print ""
  print "ONE MORE STEP: Terminal needs Full Disk Access, so the kit can check Safari and back up the files."
  print "1. In the window that opens now (Full Disk Access), switch on Terminal."
  print "   (If Terminal is not in the list, click +, open Applications > Utilities, choose Terminal.)"
  print "2. macOS then offers to quit Terminal: click Quit & Reopen (or Later, then quit Terminal yourself)."
  print "3. Double-click START-HERE-MAC on the USB drive again."
  print ""
  print "To run without it instead (no backup, no Safari check), press Return."
  /usr/bin/open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles" 2>/dev/null
  read -r _
fi
RUN=/private/var/tmp/LaptopCleanupKit
/usr/bin/sudo /bin/rm -rf "$RUN"
/usr/bin/sudo /bin/mkdir -p "$RUN"
/usr/bin/sudo /bin/cp -R "$KIT/mac-tools/" "$RUN/"
print ""
print "Started at $(date '+%-I:%M%p' | tr 'APM' 'apm'). You can leave the Mac alone now."
/usr/bin/sudo -H /usr/bin/env KIT_TEST=$TEST /usr/bin/caffeinate -dims /bin/zsh "$RUN/clean-mac.zsh" "$KIT"
st=$?
/usr/bin/sudo /bin/rm -rf "$RUN"
print ""
if [ $st -eq 0 ]; then
  print "Finished at $(date '+%-I:%M%p' | tr 'APM' 'apm'). The report is open on the screen and saved on the USB drive"
  print "(LATEST-SUMMARY-MAC.txt) and on the desktop (Laptop Cleanup Report.txt)."
else
  print "The kit stopped early (code $st). What it did so far is in the Results folder on the USB drive."
fi
print "You can close this window."
exit $st
