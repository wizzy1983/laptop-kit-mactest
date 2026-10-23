#!/bin/zsh
# clean-mac.zsh "<kit folder on the drive>": the Mac kit. Started as root by START-HERE-MAC.command (sudo -H, under
# caffeinate). Runs unattended. Writes everything to Results/<computer>_<date> on the drive, and the report to the
# drive (LATEST-SUMMARY-MAC.txt), the signed-in person's desktop, and the screen.
# Research behind each step: research/2026-10-23-mac-*.md. KIT_TEST=1 (GitHub tests only) skips the slow downloads,
# the backup size limit and opening the report on screen.
emulate -L zsh
setopt no_nomatch extended_glob typeset_silent
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/libexec
umask 022

KIT=${1:?usage: clean-mac.zsh <kit folder>}
TOOLS=${0:A:h}
TEST=${KIT_TEST:-0}
stamp=$(date +%Y-%m-%d_%H%M)
host=$(scutil --get ComputerName 2>/dev/null || hostname -s)
hostsafe=${host//[^A-Za-z0-9-]/_}
WORK="$KIT/Results/${hostsafe}_$stamp"
UNDO="$WORK/undo"
LOG="$WORK/log.txt"
QUAR="/Library/Application Support/LaptopCleanupKit/Quarantine/$stamp"
mkdir -p "$WORK" "$UNDO" || { print "Cannot write to the USB drive: $WORK"; exit 2 }
source "$TOOLS/common.zsh"
source "$TOOLS/find-unwanted.zsh"
started=$(ts)
(( EUID == 0 )) || { print "This must run as administrator (START-HERE-MAC.command does that)."; exit 2 }

# ---------------------------------------------------------------- 1. About this Mac
step "1. About this Mac"
ver=$(sw_vers -productVersion); major=${ver%%.*}
arch=$(uname -m)
say "  macOS $ver ($(sw_vers -buildVersion)), $arch, computer name: $host"
FDA=0; kit_has_fda && FDA=1
say "  Full Disk Access for Terminal: $([[ $FDA == 1 ]] && print yes || print no)"
USERS=("${(@f)$(kit_users)}")
say "  user accounts: ${(j:, :)${USERS%% *}}"
CONSOLE=$(console_user)
# Apple gives security fixes to the three newest macOS versions (27, 26 and 15 on 2026-10-23; Apple security releases page).
SUPPORTED_MIN=15
if (( major < SUPPORTED_MIN )); then
  attention "This Mac runs macOS $ver, which no longer gets security fixes from Apple (only macOS 15 and newer do, as of October 2026). Install a newer macOS in System Settings > General > Software Update if the Mac can take it; if it cannot, it should not be used for banking or email."
fi
MDM=0
if limit 60 profiles status -type enrollment 2>/dev/null | grep -q 'MDM enrollment: Yes'; then
  MDM=1
  attention "This Mac is managed by an organization (school or work). The kit did not change its profiles or update settings; ask that organization before removing anything."
fi
pmset -g batt 2>/dev/null | grep -q "AC Power" || note "The Mac was running on battery when the kit started; keep it plugged in next time."
if [[ $FDA == 0 ]]; then
  attention "Terminal did not have Full Disk Access, so Safari, the backup and the deep start-up check were skipped. To include them: System Settings > Privacy & Security > Full Disk Access > switch on Terminal, click Quit & Reopen, and run the kit again."
fi

# ---------------------------------------------------------------- 2. Backup
step "2. Backup of each person's files"
backup_users() {
  local dest="$KIT/Backup/${hostsafe}_$stamp" line u h need free list
  for line in $USERS; do
    u=${line%% *}; h=${line#* }
    # Files kept only in iCloud ("dataless") are skipped without downloading them; they are safe in iCloud.
    list="$WORK/backup-$u.list"
    ( cd "$h" && find Desktop Documents Pictures Movies Music Downloads -flags +dataless -prune -o -type f -print0 2>/dev/null ) > "$list"
    need=$( (cd "$h" && xargs -0 stat -f %z < "$list" 2>/dev/null) | awk '{s+=$1} END {printf "%.0f", s/1024}')
    free=$(df -k "$KIT" | awk 'NR==2 {print $4}')
    if (( need + 1048576 > free )); then
      attention "Backup of $u skipped: the files need $(( need / 1048576 )) GB and the USB drive has $(( free / 1048576 )) GB free. Use a bigger drive to include it."
      continue
    fi
    mkdir -p "$dest"
    say "  $u: $(tr -cd '\0' < "$list" | wc -c | tr -d ' ') files, $(( need / 1024 )) MB"
    if ( cd "$h" && tar --null -cf "$dest/$u.tar" -T "$list" 2>>"$LOG" ); then
      note "The files of $u (Desktop, Documents, Pictures, Movies, Music, Downloads) were copied to the USB drive: Backup/${hostsafe}_$stamp/$u.tar (double-click it on a Mac to open)."
    else
      note "The backup of $u is in Backup/${hostsafe}_$stamp/$u.tar, but some files could not be read (they are named in the log)."
    fi
    rm -f "$list"
  done
}
if [[ $FDA == 1 ]]; then backup_users; else say "  skipped: no Full Disk Access"; fi

# ---------------------------------------------------------------- 3. Built-in protection
step "3. Built-in protection (Gatekeeper, system protection, firewall, automatic updates)"
csrutil status 2>/dev/null | grep -q 'enabled' || attention "System Integrity Protection is off. Only a person can turn it back on (it needs Recovery mode); ask whoever set up the Mac."
fdesetup status 2>/dev/null | grep -q 'FileVault is On' || fyi "FileVault (disk encryption) is off. It protects the files if the Mac is stolen: System Settings > Privacy & Security > FileVault."
if ! spctl --status 2>/dev/null | grep -q 'assessments enabled'; then
  spctl --global-enable 2>>"$LOG" || spctl --master-enable 2>>"$LOG"
  if spctl --status 2>/dev/null | grep -q 'assessments enabled'; then removed "Gatekeeper was switched off (any downloaded app could run); it is on again"
  else attention "Gatekeeper is off, so any downloaded app can run. Turn it on: System Settings > Privacy & Security > Allow applications from > App Store and identified developers."; fi
fi
fw=/usr/libexec/ApplicationFirewall/socketfilterfw
if ! $fw --getglobalstate 2>/dev/null | grep -qi 'enabled'; then
  $fw --setglobalstate on >>"$LOG" 2>&1
  $fw --getglobalstate 2>/dev/null | grep -qi 'enabled' && note "The firewall was off; it is on now." || attention "The firewall could not be switched on: System Settings > Network > Firewall."
fi
if [[ $MDM == 0 ]]; then
  su=/Library/Preferences/com.apple.SoftwareUpdate
  save_undo $su.plist; save_undo /Library/Preferences/com.apple.commerce.plist
  off=()
  for k in AutomaticCheckEnabled AutomaticDownload ConfigDataInstall CriticalUpdateInstall; do
    [[ $(defaults read $su $k 2>/dev/null) == 1 ]] || { off+=$k; defaults write $su $k -bool true }
  done
  [[ $(defaults read /Library/Preferences/com.apple.commerce AutoUpdate 2>/dev/null) == 1 ]] || { off+=AppStoreAutoUpdate; defaults write /Library/Preferences/com.apple.commerce AutoUpdate -bool true }
  (( ${#off} )) && note "Automatic updates were partly off ($off); security updates and app updates now install by themselves."
fi

# ---------------------------------------------------------------- 4. Apple's malware protection (XProtect)
step "4. Apple's malware protection (XProtect)"
xp_versions() {
  print -r -- "XProtect $(defaults read /Library/Apple/System/Library/CoreServices/XProtect.bundle/Contents/Info.plist CFBundleShortVersionString 2>/dev/null), Remediator $(defaults read /Library/Apple/System/Library/CoreServices/XProtect.app/Contents/Info.plist CFBundleShortVersionString 2>/dev/null)"
}
before=$(xp_versions); say "  before: $before"
labels=$(limit 300 softwareupdate -l --include-config-data 2>&1 | tee -a "$LOG" | sed -n 's/^[* ]*Label: //p' | grep -E '^(XProtect|Gatekeeper|MRT|Bridge OS)' )
for l in ${(f)labels}; do say "  installing $l"; limit 900 softwareupdate -i --include-config-data "$l" >>"$LOG" 2>&1; done
[[ -x /usr/bin/xprotect ]] && limit 300 xprotect update >>"$LOG" 2>&1
after=$(xp_versions); say "  after:  $after"
[[ $before != $after ]] && note "Apple's malware lists were out of date and were updated ($before -> $after)."
# Apple's own scanner runs by itself about once a day; its results are in the system log (it cannot be started by hand).
xpr=$(limit 120 /usr/bin/log show --last 30d --style ndjson --predicate 'subsystem == "com.apple.XProtectFramework.PluginAPI" && category == "XPEvent.structured"' 2>/dev/null)
nscan=$(print -r -- "$xpr" | grep -c '"status_code' )
bad=$(print -r -- "$xpr" | grep '"status_code' | grep -vE 'status_code\\?":(0|20|30|31)[,}]')
last=$(print -r -- "$xpr" | grep '"status_code' | tail -1 | sed -n 's/.*"timestamp":"\([0-9-]*\) \([0-9:]*\).*/\1 \2/p')
say "  scanner records in the last 30 days: $nscan; newest: ${last:-none}"
if [[ -n $bad ]]; then
  print -r -- "$bad" > "$WORK/xprotect-findings.txt"
  for b in ${(f)bad}; do
    mod=$(print -r -- "$b" | sed -n 's/.*XProtectRemediator\([A-Za-z0-9]*\).*/\1/p' | head -1)
    attention "Apple's malware scanner reported something (module ${mod:-unknown}, $(print -r -- "$b" | sed -n 's/.*"timestamp":"\([^"]*\)".*/\1/p')). Apple removes what it finds by itself; details in xprotect-findings.txt in the results folder."
  done
fi
[[ -z $last ]] && fyi "Apple's malware scanner left no record in the system log in the last 30 days (it scans when the Mac is idle and plugged in)."
for db in /var/protected/xprotect/db/XPdb /var/protected/xprotect/XPdb; do
  [[ -e $db ]] || continue
  ev=$(sqlite3 -readonly "$db" "select datetime(dt,'unixepoch'), violated_rule, exec_path, exec_team_id, exec_is_notarized from events where violated_rule not like '%Unsigned%' order by dt desc limit 200" 2>/dev/null)
  [[ -n $ev ]] && { print -r -- "$ev" > "$WORK/xprotect-behaviour.txt"; nev=$(print -r -- "$ev" | wc -l | tr -d ' '); fyi "Apple's behaviour monitor logged $nev event$( (( nev == 1 )) || print s) (xprotect-behaviour.txt)." }
  break
done

# ---------------------------------------------------------------- 5. Internet settings
step "5. Internet settings (proxies, DNS servers, hosts file)"
# DNS servers that are fine: home and office networks, and the big public ones (Google, Cloudflare, Quad9, OpenDNS,
# AdGuard, NextDNS). Anything else was likely set by adware to send her to fake sites.
GoodDns='^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.|100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.|127\.|169\.254\.|fe80:|fd|8\.8\.8\.8$|8\.8\.4\.4$|1\.1\.1\.1$|1\.0\.0\.1$|9\.9\.9\.9$|149\.112\.112\.112$|208\.67\.22[02]\.22[02]$|94\.140\.1[45]\.1[45]$|45\.90\.(28|30)\.|2001:4860:4860::|2606:4700:4700::|2620:fe::|2620:119:)'
repair_network() {
  local svc kind host dns
  networksetup -listallnetworkservices 2>/dev/null | tail -n +2 | sed 's/^\*//' | while IFS= read -r svc; do
    [[ -n $svc ]] || continue
    for kind in web secureweb socksfirewall; do
      if networksetup -get${kind}proxy "$svc" 2>/dev/null | grep -q '^Enabled: Yes'; then
        host=$(networksetup -get${kind}proxy "$svc" | awk '/^Server:/ {print $2}')
        print -r -- "$svc $kind proxy $host" >> "$UNDO/network.txt"
        networksetup -set${kind}proxystate "$svc" off
        removed "Proxy $host on $svc (sent web traffic through another computer)"
      fi
    done
    if networksetup -getautoproxyurl "$svc" 2>/dev/null | grep -q '^Enabled: Yes'; then
      host=$(networksetup -getautoproxyurl "$svc" | awk '/^URL:/ {print $2}')
      print -r -- "$svc autoproxy $host" >> "$UNDO/network.txt"
      networksetup -setautoproxystate "$svc" off
      removed "Automatic proxy $host on $svc"
    fi
    dns=$(networksetup -getdnsservers "$svc" 2>/dev/null | grep -E '^[0-9a-fA-F.:]+$')
    [[ -n $dns ]] || continue
    if print -r -- "$dns" | grep -vqE "$GoodDns"; then
      print -r -- "$svc dns ${(f)dns}" >> "$UNDO/network.txt"
      networksetup -setdnsservers "$svc" Empty
      removed "Unusual DNS servers on $svc (${(j:, :)${(f)dns}}); it uses the network's own again"
    fi
  done
  # A hosts line stays when it is a comment, macOS's own default, or names only this Mac itself (its own name is often
  # listed there); any other line points a website somewhere else and is disabled. BSD sed cannot do this on one line.
  local hosts=/etc/hosts line out="" n; local -i keep; local -a extra
  local -a me=(localhost broadcasthost ${(L)"$(hostname -s)"} ${(L)"$(hostname -s)"}.local ${(L)"$(hostname)"} ${(L)"$(scutil --get LocalHostName 2>/dev/null)"}.local)
  while IFS= read -r line || [[ -n $line ]]; do
    keep=1
    if [[ $line != [[:space:]]#(\#*|) ]]; then
      for n in ${${=line}[2,-1]}; do [[ $n == \#* ]] && break; (( ${me[(Ie)${(L)n}]} )) || { keep=0; break }; done
    fi
    if (( keep )); then out+="$line"$'\n'; else extra+=("$line"); out+="# removed by Laptop Cleanup Kit: $line"$'\n'; fi
  done < $hosts
  if (( $#extra )); then
    save_undo $hosts
    if print -rn -- "$out" > $hosts; then
      removed "Lines in the hosts file that redirect websites: ${(j:; :)extra}"
    else
      problem "The hosts file could not be changed; these lines still redirect websites: ${(j:; :)extra}"
    fi
    dscacheutil -flushcache; killall -HUP mDNSResponder 2>/dev/null
  fi
}
repair_network

# ---------------------------------------------------------------- 6. Remote control
step "6. Remote-control programs (switched off) and screen sharing"
stop_remote_control
remote_builtin_report

# ---------------------------------------------------------------- 7. Unwanted programs and browser hijacks
step "7. Unwanted programs and browser hijacks (found by what they do, not by a virus list)"
unwanted_cleanup fix

# ---------------------------------------------------------------- 8. Second opinion: KnockKnock
step "8. Second opinion: everything set to start by itself (Objective-See KnockKnock)"
knockknock_check

# ---------------------------------------------------------------- 9. Updates
step "9. Software updates"
upd=$(limit 600 softwareupdate -l 2>&1 | tee -a "$LOG")
if print -r -- "$upd" | grep -q 'Label:'; then
  if print -r -- "$upd" | grep -q 'Label: Safari'; then
    if [[ $TEST != 1 ]] && limit 1800 softwareupdate -i --safari-only >>"$LOG" 2>&1; then note "Safari was updated."; fi
  fi
  macos=$(print -r -- "$upd" | sed -n 's/^[* ]*Label: //p' | grep -vE '^(Safari|XProtect|Gatekeeper|MRT)')
  if [[ -n $macos ]]; then
    [[ $TEST == 1 ]] || limit 3600 softwareupdate -d -a >>"$LOG" 2>&1
    attention "macOS updates are waiting (${(j:, :)${(f)macos}}). They were downloaded; to install them click Update Now in System Settings > General > Software Update (the Mac restarts)."
  fi
else
  say "  no updates waiting"
fi

# ---------------------------------------------------------------- 10. Check again
step "10. Checking again for anything that came back"
[[ $TEST == 1 ]] && pause=${KIT_RECHECK_WAIT:-60} || pause=180
sleep $pause
# The second pass only looks for things that came back; what it says again about everything else is not repeated.
typeset -a firstRemoved=("${Removed[@]}") firstAttention=("${Attention[@]}") firstFyi=("${Fyi[@]}") firstNotes=("${Notes[@]}")
Removed=()
unwanted_cleanup fix
cameBack=("${Removed[@]}"); Removed=("${firstRemoved[@]}")
Attention=("${firstAttention[@]}"); Fyi=("${firstFyi[@]}"); Notes=("${firstNotes[@]}")
for c in $cameBack; do attention "Came back after being removed, and was removed again: $c. Something on the Mac keeps putting it back; ask for help."; done

# ---------------------------------------------------------------- Report
step "Report"
if (( ${#Problems} || ${#Attention} )); then result="NEEDS ATTENTION"
elif (( ${#Removed} )); then result="CLEANED"
else result="ALL CLEAR"; fi
report="$WORK/Laptop Cleanup Report.txt"
{
  print "LAPTOP CLEANUP REPORT (Mac)"
  print "Computer: $host   macOS $ver   Started $started, finished $(ts) on $(date '+%B %-d, %Y')"
  print ""
  print "RESULT: $result"
  case $result in
    "ALL CLEAR") print "Nothing unwanted was found, and protection is on.";;
    "CLEANED") print "Unwanted things were found and removed (listed below). Nothing is left for you to do.";;
    *) print "Something below needs a person. Each item says what it is and how to fix it.";;
  esac
  if (( ${#Attention} || ${#Problems} )); then print "\nNEEDS A PERSON"; i=0; for a in $Problems $Attention; do print "$((++i)). $a"; done; fi
  if (( ${#Removed} )); then print "\nREMOVED"; i=0; for a in $Removed; do print "$((++i)). $a"; done; fi
  if (( ${#Notes} )); then print "\nDONE"; i=0; for a in $Notes; do print "$((++i)). $a"; done; fi
  print "\nNO MATTER WHAT THE RESULT SAYS"
  print "1. For a second opinion with the largest adware list, install the free Malwarebytes from https://www.malwarebytes.com/mac-download, choose the free version, and click Scan."
  print "2. If anyone typed a password into a strange window or pasted a command into Terminal because a web page said so, change the email and bank passwords from another device."
  if (( ${#Fyi} )); then print "\nFOR YOUR INFORMATION"; i=0; for a in $Fyi; do print "$((++i)). $a"; done; fi
  print "\nUNDO: moved programs and files are in $QUAR on this Mac; changed settings are saved in Results/${WORK:t}/undo on the USB drive."
} > "$report"
cp "$report" "$KIT/LATEST-SUMMARY-MAC.txt"
print -r -- "${(F)Removed}" > "$WORK/removed.txt"; print -r -- "${(F)Attention}" > "$WORK/attention.txt"
if [[ $FDA == 1 && -n $CONSOLE && $CONSOLE != root && -d /Users/$CONSOLE/Desktop ]]; then
  cp "$report" "/Users/$CONSOLE/Desktop/" && chown "$CONSOLE" "/Users/$CONSOLE/Desktop/${report:t}"
fi
cat "$report" >> "$LOG"
say "RESULT: $result"
if [[ $TEST != 1 && -n $CONSOLE && $CONSOLE != root ]]; then
  launchctl asuser $(id -u $CONSOLE) sudo -u $CONSOLE /usr/bin/open -e "$KIT/LATEST-SUMMARY-MAC.txt" 2>/dev/null
fi
dot_clean -m "$KIT" 2>/dev/null
sync
exit 0
