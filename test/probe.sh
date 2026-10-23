#!/bin/zsh
# probe.sh: measures what a GitHub macOS runner offers the Mac kit. Read-only except a throw-away browser profile.
h=$HOME
sec() { print "\n===== $1"; }
sec "system"; sw_vers; uname -m; id; sysctl -n hw.ncpu hw.memsize; who; stat -f '%Su' /dev/console
sec "sudo"; sudo -n true && echo "passwordless sudo: yes"
sec "runtimes (stock paths only)"
for t in /usr/bin/python3 /usr/bin/perl /usr/bin/ruby /usr/bin/jq /usr/bin/sqlite3 /usr/bin/plutil /usr/libexec/PlistBuddy /usr/bin/osascript /usr/bin/rsync /usr/bin/ditto /usr/bin/caffeinate /usr/bin/sfltool /usr/sbin/sfltool /usr/bin/xprotect /usr/bin/profiles /usr/bin/codesign /usr/sbin/spctl; do
  [ -e $t ] && print "yes $t" || print "NO  $t"; done
xcode-select -p 2>&1; /usr/bin/rsync --version 2>&1 | head -1; /usr/bin/perl -v 2>&1 | sed -n 2p
osascript -l JavaScript -e 'JSON.stringify({ok:1, v: $.NSProcessInfo.processInfo.operatingSystemVersionString.js})' 2>&1
sec "protections"
spctl --status 2>&1; csrutil status 2>&1; fdesetup status 2>&1
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>&1
sudo systemsetup -getremotelogin 2>&1; sudo launchctl print-disabled system 2>&1 | grep -Ei 'screensharing|ARD|ssh'
xprotect version 2>&1 | head -5
defaults read /Library/Apple/System/Library/CoreServices/XProtect.bundle/Contents/Info.plist CFBundleShortVersionString 2>&1
ls /Library/Apple/System/Library/CoreServices/XProtect.app/Contents/MacOS/ 2>&1 | head -30
sudo defaults read /Library/Preferences/com.apple.SoftwareUpdate 2>&1 | head -30
sec "profiles"; sudo profiles list 2>&1 | head; sudo profiles status -type enrollment 2>&1
sec "BTM"; sudo sfltool dumpbtm 2>&1 | head -60; sudo sfltool dumpbtm 2>&1 | wc -l
sec "launch items"; ls -la ~/Library/LaunchAgents /Library/LaunchAgents /Library/LaunchDaemons 2>&1 | head -60
sec "TCC: can root read these?"
for p in "$h/Library/Safari" "$h/Library/Containers/com.apple.Safari/Data/Library/Preferences" "$h/Library/Mail" "$h/Library/Application Support/com.apple.TCC/TCC.db" "/Library/Application Support/com.apple.TCC/TCC.db"; do
  if sudo ls "$p" >/dev/null 2>&1; then print "readable: $p"; else print "BLOCKED:  $p ($(sudo ls "$p" 2>&1 | head -1))"; fi; done
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "select service,client,auth_value from access" 2>&1 | head -40
sec "network"; networksetup -listallnetworkservices; scutil --dns | head -20; cat /etc/hosts
sec "browsers"
for a in "Google Chrome" "Microsoft Edge" "Brave Browser" "Firefox" "Safari" "Opera" "Vivaldi"; do
  p="/Applications/$a.app"; [ -d "$p" ] && print "$a $(defaults read "$p/Contents/Info.plist" CFBundleShortVersionString)" || print "$a: not installed"; done
codesign -dv --verbose=2 "/Applications/Google Chrome.app" 2>&1 | grep -E 'TeamIdentifier|Authority' | head -3
sec "chrome default profile after a GUI launch"
/usr/bin/open -na "Google Chrome" --args --no-first-run --no-default-browser-check --use-mock-keychain about:blank 2>&1
sleep 25; pgrep -lf "Google Chrome" | head -3
pkill -x "Google Chrome"; sleep 5
d="$h/Library/Application Support/Google/Chrome"; ls -la "$d" "$d/Default" 2>&1 | head -60
for f in Preferences "Secure Preferences"; do print "-- $f"; osascript -l JavaScript -e "var s=\$.NSString.stringWithContentsOfFileEncodingError('$d/Default/$f',4,null).js; var j=JSON.parse(s); Object.keys(j).join(',') + ' | macs: ' + (j.protection&&j.protection.macs?Object.keys(j.protection.macs).join(','):'none')" 2>&1; done
sec "edge default profile after a GUI launch"
/usr/bin/open -na "Microsoft Edge" --args --no-first-run --no-default-browser-check about:blank 2>&1; sleep 25; pkill -x "Microsoft Edge"; sleep 5
ls -la "$h/Library/Application Support/Microsoft Edge/Default" 2>&1 | head -40
sec "firefox profile"; ls "$h/Library/Application Support/Firefox/Profiles" 2>&1; ls /Applications/Firefox.app/Contents/Resources/distribution 2>&1
sec "end"
