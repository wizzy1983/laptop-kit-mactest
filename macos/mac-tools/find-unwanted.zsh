# find-unwanted.zsh: sourced by clean-mac.zsh. Finds unwanted programs and browser hijacks by what they do, not by a
# virus list (on the Windows laptop on 2026-10-23 every scanner found nothing while two bundled browsers, two add-ons
# and a replaced search engine were there). Rules and their sources: research/2026-10-23-mac-unwanted-families-persistence.md
# (rule numbers "P<n>") and research/2026-10-23-mac-browser-hijacks.md ("B<n>"). Nothing is deleted outright: programs
# and files go to $QUAR, settings files are copied to $UNDO first. A rule removes only when every condition holds;
# anything in doubt goes to the "needs a person" list.

# Makers whose signed programs are normal on family Macs (research P section 6; the signer is checked, never the name).
TrustedTeams='EQHXZ8M8AV|UBF8T346G9|QGS93ZLCU7|JQ525L2MZD|BJ4HAAB9B3|G7HH3F8CAK|2FNC3A47ZF|QED4VVPZWA|43AQ936H96|KL8N8XSYF4|A2P9LX4JPN|4XF3XNRN6Y|S6N382Y83G|HKE973VLUW|2DC432GLL2|Q6L2SF6YDW|BQR82RBBHL|53Q6R32WPB|57T9237FN3|DE8Y96K9QP|2BUA8C4S2C|LTZ2PFU5D6|GVZRY6KDKR|GUNFMW623Y|S8EX82NJP6|MXGJJ98X76|96DBZ92D3Y|W8F64X92K3|6HB5Y2QTA3|TXAEAV5RN4|XE2XNRRXZ5|5HCL85FLGW|EG27766DY7|Y93VXCB8Q5|4C6364ACXT|M683GB7CPW|94KV3E626L|72ES32VZUA|2G4LW83Q3E|TC292Y5427|W5W395V82Y|YHUG37CKN8|2SB5Z68H26|J6S6Q257EK|W5364U7YZB|U68MSDN6DR|6N38VWS5BX|C67CF9S4VU|S272Y5R93J|9BNSXJN65R|EG7KH642X6|VBG97UB4TA|H7UGFBUGV6|KHRWM533LU'
# Makers of browsers that are fine to have (Google, Microsoft, Mozilla, Brave, Opera, Vivaldi, Browser Company, DuckDuckGo, OpenAI).
BrowserTeams='EQHXZ8M8AV|UBF8T346G9|43AQ936H96|KL8N8XSYF4|A2P9LX4JPN|4XF3XNRN6Y|S6N382Y83G|HKE973VLUW|2DC432GLL2'
# Label prefixes that belong to one maker: a program behind such a label signed by anyone else is an impersonation (P4).
typeset -gA MakerPrefix=([com.google.]=EQHXZ8M8AV [org.chromium.]=EQHXZ8M8AV [com.microsoft.]='UBF8T346G9|QGS93ZLCU7' [us.zoom.]=BJ4HAAB9B3 [com.adobe.]=JQ525L2MZD [com.dropbox.]=G7HH3F8CAK [com.spotify.]=2FNC3A47ZF)
# Bundled "free" browsers and other programs that arrive inside other downloads (Windows kit list + Mac adware names).
PupNames='Blazer|Pulse ?Browser|Wave ?Browser|Wavesor|OneLaunch|OneStart|Shift Browser|Epibrowser|PDFast|AppSuite|Manual ?Finder|Web ?Companion|SearchMine|AnySearch|MyCouponSmart|GoSearch|Search ?Marquis|Search ?Baron|SearchQuest|SearchDaemon|ExpertModuleSearch|SmartWebSearch|AlphaLookup|ApolloSearch|DataSearch|MaxOfferDeal|Genieo|InstallMac|Mughthesec|SurfBuyer|WebVideoPlayer|HelperModule'
# Launch item names and leftover files of password-stealing programs (P1, P2).
StealerLabels='^(com\.finder\.helper|goldenticketsshop\.com|com\.test\.simple|com\.user\.loginscript|com\.apple\.finder\.agent|com\.apple\.crashreporter\.helper|com\.apple\.qtop|com\.driver9990as7tpatch)$'
StealerFiles=(.agent .helper .mainhelper .pwd .chost .botid 'Library/Application Support/System/.repair-run' 'Library/Application Support/System/.githooks' 'Library/Application Support/com.apple.finder.core' 'Library/Application Support/Google/GoogleUpdate.app' '.cache/com.apple.crashreporter' '.local/share/.stream')
# Remote-control programs scammers use (same list as the Windows kit, step "Switching off remote-control programs").
RemoteNames='AnyDesk|TeamViewer|UltraViewer|ScreenConnect|ConnectWise|LogMeIn|Splashtop|RustDesk|Supremo|Ammyy|AeroAdmin|RemotePC|GoTo ?Assist|GoTo Resolve|Zoho ?Assist|NetSupport|\bAtera|SimpleHelp|Action1|DWService|HopToDesk|Mesh ?Agent|Remote ?Utilities|\bRadmin\b|TightVNC|UltraVNC|RealVNC|VNC Server|chromoting|Chrome Remote Desktop|AweSun|AweRay|ToDesk|getscreen'
# "Cleaner" and antivirus programs that are often bundled: reported, never removed (someone may have paid).
CleanerNames='MacKeeper|zeobit|Advanced Mac Cleaner|Mac Auto Fixer|Mac Tweak Pro|Mac Speedup Pro|Mac Cleanup Pro|Smart Mac Booster|Mac Mechanic|Combo ?Cleaner|Mac Booster'
AvNames='\b(Norton|McAfee|Avast|AVG|Avira|Kaspersky|Bitdefender|TotalAV|Total Security|Intego|Webroot|Trend Micro|ESET|Sophos|PC ?Matic|Scanguard|MacScan|Airo)\b'
WalletNames='^(Ledger Live|Ledger Wallet|Trezor Suite|Exodus|Atomic Wallet|Electrum)\.app$'
Interpreters='^(bash|sh|zsh|dash|ksh|tcsh|csh|osascript|python|python3|perl|ruby|node|env|open|nohup|arch)$'
DownloadRun='(curl|wget|dig)[^|;]*(\||;|&&)[[:space:]]*(/bin/|/usr/bin/)?(ba|z)?sh|osascript[[:space:]]+-e|base64 +(-d|-D|--decode)|eval[[:space:](]'
ScarewareWords='security|protect|virus|alert|cleaner|antivirus|defender|warning|support'

matches() { print -r -- "$2" | grep -qiE -- "$1" }
as_user() { local u=$1; shift; local id=$(id -u "$u" 2>/dev/null); if launchctl print gui/$id >/dev/null 2>&1; then launchctl asuser $id sudo -u "$u" "$@"; else sudo -u "$u" "$@"; fi }
gui_uids() { local l u h; for l in $USERS; do u=${l%% *}; launchctl print gui/$(id -u $u) >/dev/null 2>&1 && id -u $u; done }

# Signing of a program: SIG_KIND = apple | team | adhoc | unsigned | missing, SIG_TEAM = its team id.
sig_info() {
  SIG_KIND=; SIG_TEAM=
  local p=$1 out
  [[ -e $p ]] || { SIG_KIND=missing; return }
  out=$(limit 30 codesign -dv --verbose=4 "$p" 2>&1)
  if [[ $out == *"not signed at all"* ]]; then SIG_KIND=unsigned
  elif [[ $out == *"Signature=adhoc"* ]]; then SIG_KIND=adhoc
  elif [[ $out == *"Authority=Software Signing"* || $out == *"Authority=Apple Mac OS Application Signing"* || $out == *"Authority=macOS Software Signing"* ]]; then SIG_KIND=apple
  else SIG_KIND=team; SIG_TEAM=$(print -r -- "$out" | sed -n 's/^TeamIdentifier=//p' | head -1); [[ $SIG_TEAM == "not set" ]] && SIG_KIND=unsigned
  fi
}
trusted() { [[ $SIG_KIND == apple ]] || { [[ $SIG_KIND == team ]] && matches "^($TrustedTeams)$" "$SIG_TEAM" } }
is_macho() { [[ -f $1 ]] && file -b "$1" 2>/dev/null | grep -q 'Mach-O' }

# The file a launch item really runs: for bash/osascript/open and the like, the first existing path in its arguments.
launch_target() {
  local prog=$1; shift
  if matches "$Interpreters" "${prog:t}"; then
    local a; for a in "$@"; do [[ $a == /* && -e $a && $a != $prog ]] && { print -r -- "$a"; return }; done
  fi
  print -r -- "$prog"
}

# The folder that holds a program, when it is safe to move away as a whole (its .app, its own Application Support
# folder, its hidden folder in a home); otherwise the program file alone.
removal_root() {
  local p=$1 r
  if [[ $p == *.app/* ]]; then r=${p%%.app/*}.app
  elif [[ $p =~ '^(/Users/[^/]+)?/Library/Application Support/[^/]+' ]]; then r=$MATCH
  elif [[ $p =~ '^/Users/[^/]+/\.[^/]+' ]]; then r=$MATCH
  elif [[ $p =~ '^/var/root/\.[^/]+' || $p =~ '^/private/var/root/\.[^/]+' ]]; then r=$MATCH
  else r=$p; fi
  safe_to_remove "$r" && print -r -- "$r" || print -r -- "$p"
}
safe_to_remove() {
  local p=$1
  [[ $p == /Users/[^/]##/Library/Application\ Support/?* || $p == /Library/Application\ Support/?* ]] && [[ ${p:t} != (Google|Microsoft|Apple|com.apple.*|Mozilla|Firefox) ]] && return 0
  [[ $p == /Users/[^/]##/.?* && ${p:t} != (.Trash|.ssh|.config|.local|.cache|.zshrc|.bash_profile|.profile) ]] && return 0
  [[ $p == (/Applications|/Users/[^/]##/Applications)/?*.app ]] && return 0
  [[ $p == (/private|)/tmp/?* || $p == /private/var/tmp/?* || $p == /Users/Shared/?* || $p == (/private|)/var/root/.?* ]] && return 0
  return 1
}

# Stops processes started from a path (matched on the full path, never a bare name).
stop_path() {
  local p=$1 pid cmd
  [[ -n $p && $p == /* ]] || return 0
  ps -axo pid=,command= | while read -r pid cmd; do
    [[ $cmd == "$p"* || $cmd == *" $p"* ]] && kill -TERM $pid 2>/dev/null
  done
  sleep 2
  ps -axo pid=,command= | while read -r pid cmd; do
    [[ $cmd == "$p"* || $cmd == *" $p"* ]] && kill -KILL $pid 2>/dev/null
  done
}

# Unloads a launch item and moves its file (and, when given, its program's folder) to quarantine.
remove_launch_item() {
  local plist=$1 label=$2 why=$3 root=$4 uid
  if [[ $plist == /Library/LaunchDaemons/* ]]; then launchctl bootout system/$label >>"$LOG" 2>&1
  elif [[ $plist == /Library/LaunchAgents/* ]]; then for uid in $(gui_uids); do launchctl bootout gui/$uid/$label >>"$LOG" 2>&1; done
  else uid=$(stat -f %u "$plist"); launchctl bootout gui/$uid/$label >>"$LOG" 2>&1; fi
  [[ -n $root ]] && stop_path "$root"
  quarantine "$plist" || { attention "Could not move away the start-up item $plist ($why)."; return 1 }
  if [[ -n $root && -e $root ]]; then quarantine "$root" || attention "Could not move away $root ($why)."; fi
  removed "Start-up item ${label:-${plist:t}} ($why)${root:+, with $root}"
  RemovedPaths+=("$root")
}

# ---------------------------------------------------------------- programs that start by themselves
LaunchDirs() { local l; for l in $USERS; do print -r -- "${l#* }/Library/LaunchAgents"; done; print /Library/LaunchAgents; print /Library/LaunchDaemons }

check_launch_items() {
  local fix=$1 d f ip label prog argstr bprog empty target why root
  local -a files args
  for d in ${(f)"$(LaunchDirs)"}; do
    files=("$d"/*.plist(N))
    (( ${#files} )) || continue
    while IFS=$'\t' read -r -u 3 ip label prog argstr bprog empty; do
      [[ -e $ip ]] || continue
      [[ $empty == unreadable ]] && { attention "A start-up item could not be read: $ip"; continue }
      [[ $empty == 1 || ( -z $prog && -z $bprog ) ]] && continue   # empty placeholder (Google leaves these on purpose)
      matches "$RemoteNames" "$label $ip $prog" && continue      # handled by the remote-control step
      args=("${(@ps:\x1f:)argstr}")
      target=$(launch_target "$prog" "${args[@]}")
      sig_info "$target"
      why=; root=
      local base=${ip:t:r}
      if [[ -n $bprog && -z $prog ]]; then continue; fi           # runs from inside an app; judged with the app
      if matches "$StealerLabels" "$label" || matches "$StealerLabels" "$base"; then
        trusted || { why="a password-stealing program's start-up item"; STEALER=1 }
      fi
      if [[ -z $why && ( $label == com.apple.* || $base == com.apple.* ) ]] && [[ $SIG_KIND != apple ]]; then
        why="pretends to be Apple's but is not signed by Apple"
      fi
      if [[ -z $why && $SIG_KIND != missing ]]; then
        local pre; for pre in ${(k)MakerPrefix}; do
          if [[ $label == $pre* ]] && ! { [[ $SIG_KIND == team ]] && matches "^(${MakerPrefix[$pre]})$" "$SIG_TEAM" } && [[ $SIG_KIND != apple ]]; then
            why="uses the name of ${pre%.} but is not signed by it"; break
          fi
        done
      fi
      if [[ -z $why ]] && [[ $target == (/private|)/tmp/* || $target == /private/var/tmp/* || $target == /Users/Shared/* || $target == (/private|)/var/root/.* ]] && ! trusted; then
        why="runs a program from a temporary or shared folder"
      fi
      if [[ -z $why && ( $SIG_KIND == unsigned || $SIG_KIND == adhoc ) ]] && [[ $target =~ '^/Users/[^/]+/(.*/)?\.[^/]+/' ]] && is_macho "$target"; then
        why="runs an unsigned program hidden in a dot-folder"
      fi
      if [[ -z $why ]] && [[ $target =~ '/Application Support/\.[0-9]{19,}(/|$)' ]]; then why="adware (Adload: hidden numbered folder)"; fi
      if [[ -z $why && ( $SIG_KIND == unsigned || $SIG_KIND == adhoc ) ]] && [[ $target =~ '/Application Support/com\.([A-Za-z]+)/([A-Za-z]+)$' && ${match[1]} == ${match[2]} ]]; then
        why="adware (Adload pattern com.${match[1]})"
      fi
      if [[ -z $why ]] && [[ $label =~ '^com\.([A-Za-z]+)\.(service|system)$' ]] && [[ $SIG_KIND == unsigned || $SIG_KIND == adhoc ]]; then
        why="adware (Adload service/system pair)"
      fi
      if [[ -z $why ]] && matches "$DownloadRun" "${args[*]}"; then why="downloads and runs code from the internet"; fi
      if [[ -z $why && $SIG_KIND == missing && $target == /* && $target != /Volumes/* ]] && ! matches "$Interpreters" "${target:t}"; then
        why="left behind by a program that is no longer there"
      fi
      if [[ -z $why ]] && [[ " ${args[*]} " == *" --wake "* ]] && ! { [[ $SIG_KIND == team ]] && matches "^($BrowserTeams)$" "$SIG_TEAM" }; then
        why="an updater copied from a browser maker's but not signed by one (comes with bundled browsers)"
      fi
      if [[ -z $why ]] && matches "$PupNames" "$label $ip $prog"; then why="part of a bundled unwanted program"; fi
      if [[ -n $why ]]; then
        [[ $SIG_KIND != missing && $why != *"no longer there"* ]] && root=$(removal_root "$target")
        [[ $root == /System/* || $root == /usr/* || $root == /bin/* || $root == /sbin/* ]] && root=
        if [[ $fix == fix ]]; then remove_launch_item "$ip" "$label" "$why" "$root"
        else attention "Start-up item $label ($why): $ip"; fi
        continue
      fi
      if [[ $SIG_KIND == unsigned || $SIG_KIND == adhoc ]]; then
        attention "Start-up item ${label:-$base} runs a program that no known maker signed: $target (from $ip, created $(stat -f '%Sm' -t '%Y-%m-%d' "$ip")). If nobody here set it up on purpose, ask for help removing it."
      fi
    done 3< <(osascript -l JavaScript "$TOOLS/inspect.js" launchd "${files[@]}" 2>>"$LOG")
  done
}

# ---------------------------------------------------------------- apps
AppList() {
  local l
  print -rl -- /Applications/*.app(N) /Applications/*/*.app(N)
  for l in $USERS; do print -rl -- "${l#* }"/Applications/*.app(N) "${l#* }"/Applications/*/*.app(N); done
}
check_apps() {
  local fix=$1 ip bid name web fw age
  local -a apps=("${(@f)$(AppList)}")
  (( ${#apps} )) && [[ -n ${apps[1]} ]] || return 0
  while IFS=$'\t' read -r -u 3 ip bid name web fw; do
    [[ -d $ip && $bid != com.apple.* ]] || continue
    age=$(( ( $(date +%s) - $(stat -f %B "$ip") ) / 86400 ))
    if matches "$RemoteNames" "${ip:t} $bid"; then continue; fi
    if matches "$CleanerNames" "${ip:t} $bid $name"; then
      attention "\"${ip:t:r}\" is a \"cleaner\" program that is often installed by accident and shows scary warnings to sell itself. If nobody bought it on purpose, quit it and drag it from Applications to the Trash."
      continue
    fi
    if (( age <= 120 )) && matches "$AvNames" "${ip:t} $name"; then
      attention "Antivirus program \"${ip:t:r}\" was installed $age days ago. Trials often come bundled with other downloads; if nobody bought it, uninstall it (a Mac does not need it, Apple's protection is built in). The kit did not remove it, because only a person knows whether it was bought."
      continue
    fi
    if matches "$WalletNames" "${ip:t}"; then
      limit 120 codesign --verify --deep --strict "$ip" >/dev/null 2>&1 || attention "URGENT: the crypto wallet app ${ip:t:r} has been changed after its maker signed it (fake wallets steal the recovery words). Stop using it, move the money to a new wallet made on a clean device, and reinstall the app only from the maker's site."
      continue
    fi
    [[ $web == 1 && $fw == 1 ]] || { (( age <= 60 )) && fyi "Installed in the last 60 days: ${ip:t:r} ($ip)"; continue }
    # A browser engine plus web-link handling = a browser. One not made by a known browser maker is treated as bundled.
    sig_info "$ip"
    [[ $SIG_KIND == apple ]] && continue
    [[ $SIG_KIND == team ]] && matches "^($BrowserTeams)$" "$SIG_TEAM" && continue
    if matches "$PupNames" "${ip:t} $bid $name" || [[ $ip == /Users/* ]]; then
      if [[ $fix == fix ]]; then
        stop_path "$ip"
        if quarantine "$ip"; then removed "Browser \"${ip:t:r}\" (bundled with other downloads; not made by a known browser maker)"; RemovedPaths+=("$ip")
        else attention "Could not move away the bundled browser $ip."; fi
      else attention "Bundled browser \"${ip:t:r}\" ($ip)"; fi
    else
      attention "\"${ip:t:r}\" is a web browser from a little-known maker ($ip, signed by ${SIG_TEAM:-nobody}). If nobody chose it on purpose, drag it to the Trash."
    fi
  done 3< <(osascript -l JavaScript "$TOOLS/inspect.js" app "${apps[@]}" 2>>"$LOG")
}

# ---------------------------------------------------------------- leftovers of password-stealing programs (P2) and shell files (P8)
check_home_leftovers() {
  local fix=$1 l u h f rc
  for l in $USERS; do
    u=${l%% *}; h=${l#* }
    for f in $StealerFiles "${h}"/.local-*/pw.dat(N); do
      [[ $f == /* ]] || f="$h/$f"
      [[ -e $f ]] || continue
      [[ $f == */.helper || $f == */.mainhelper ]] && ! is_macho "$f" && continue
      [[ $f == */.agent && ! -f $f ]] && continue
      STEALER=1
      if [[ $fix == fix ]]; then quarantine "$f" && removed "Leftover of a password-stealing program: $f" || attention "Could not move away $f (left by a password-stealing program)."
      else attention "Leftover of a password-stealing program: $f"; fi
    done
    for rc in .zshrc .zprofile .zshenv .bash_profile .bashrc .profile; do
      f="$h/$rc"; [[ -f $f ]] || continue
      if grep -q 'sysnotif-repair' "$f"; then
        if [[ $fix == fix ]]; then
          cp -p "$f" "$f.kit-new" && sed -i '' '/sysnotif-repair/,/sysnotif-repair/d' "$f.kit-new"
          if zsh -n "$f.kit-new" 2>/dev/null; then quarantine "$f"; mv "$f.kit-new" "$f"; removed "Lines added by a password-stealing program to $f"; STEALER=1
          else rm -f "$f.kit-new"; attention "$f contains lines added by a password-stealing program (marked sysnotif-repair); remove them by hand."; fi
        else attention "$f contains lines added by a password-stealing program."; fi
      elif grep -vE '^[[:space:]]*#' "$f" | grep -qE 'curl .*\|.*sh|base64 (-d|-D|--decode)|osascript -e|DYLD_INSERT_LIBRARIES|nohup .*(/tmp/|/Users/Shared/)'; then
        attention "$f (runs each time Terminal opens) contains a command that downloads or hides code. If nobody here wrote it, ask for help."
      fi
    done
    # Read as text: "git" itself is only an installer stub on most family Macs and would open a dialog.
    grep -qs 'Application Support/System/.githooks' "$h/.gitconfig" && attention "$h/.gitconfig points Git at hooks left by a password-stealing program."
  done
}

# ---------------------------------------------------------------- crontab (P12)
check_crontabs() {
  local fix=$1 l u tab keep line hit r
  for l in $USERS root; do
    u=${l%% *}
    tab=$(crontab -l -u "$u" 2>/dev/null | grep -vE '^[[:space:]]*(#|$)') || continue
    [[ -n $tab ]] || continue
    keep=(); hit=()
    for line in ${(f)tab}; do
      r=0; for p in $RemovedPaths; do [[ -n $p && $line == *"$p"* ]] && r=1; done
      matches "$DownloadRun|/Application Support/[^ ]*[0-9a-f]{8}-[0-9a-f]{4}-" "$line" && r=1
      (( r )) && hit+=("$line") || keep+=("$line")
    done
    if (( ${#hit} )) && [[ $fix == fix ]]; then
      crontab -l -u "$u" > "$UNDO/crontab-$u.txt" 2>/dev/null
      { crontab -l -u "$u" 2>/dev/null | grep -vxF -f <(print -rl -- $hit) } | crontab -u "$u" - && removed "Scheduled command(s) for $u that started the removed programs: ${(j:; :)hit}"
    elif (( ${#hit} )); then attention "Scheduled command(s) for $u: ${(j:; :)hit}"; fi
    (( ${#keep} )) && fyi "Scheduled commands (crontab) for $u: ${(j:; :)keep}"
  done
}

# ---------------------------------------------------------------- configuration profiles (B3, B4, P9)
check_profiles() {
  local fix=$1 xml="$WORK/profiles.xml" scope id name org types forced where
  limit 60 profiles show -type configuration -output stdout-xml > "$xml" 2>/dev/null || return 0
  grep -q '<dict>' "$xml" || return 0
  [[ -e $UNDO/profiles-before.xml ]] || cp "$xml" "$UNDO/profiles-before.xml"
  case $major in 12) where="System Preferences > Profiles";; 13|14) where="System Settings > Privacy & Security > Profiles";; *) where="System Settings > General > Device Management";; esac
  while IFS=$'\t' read -r -u 3 scope id name org types forced; do
    [[ -n $id && $id != com.apple.* ]] || continue
    if [[ -n $forced || $types == *com.apple.proxy* ]] && [[ $MDM == 0 && $types != *com.apple.mdm* ]]; then
      if [[ $fix == fix ]]; then
        if [[ $scope == _computerLevel ]]; then limit 60 profiles remove -identifier "$id" >>"$LOG" 2>&1; else limit 60 profiles remove -identifier "$id" -user "$scope" >>"$LOG" 2>&1; fi
        if limit 60 profiles show -type configuration 2>/dev/null | grep -qF "$id"; then
          attention "The profile \"$name\" forces browser settings ($forced). Remove it: $where, select it, click Remove (minus)."
        else removed "Profile \"$name\" that forced browser settings ($forced) (a copy is in the undo folder)"; fi
      else attention "Profile \"$name\" forces browser settings ($forced)."; fi
    else
      fyi "Configuration profile \"$name\" (${org:-no organization}, $types)."
    fi
  done 3< <(osascript -l JavaScript "$TOOLS/inspect.js" profiles "$xml" 2>>"$LOG")
}

# ---------------------------------------------------------------- browser policies in preference files (B5, B21)
PolicyKeys='^(HomepageLocation|HomepageIsNewTabPage|ShowHomeButton|RestoreOnStartup|RestoreOnStartupURLs|NewTabPageLocation|DefaultSearchProvider.*|ExtensionInstallForcelist|ExtensionSettings|ExtensionInstallSources|ExtensionInstallAllowlist|ProxyMode|ProxyServer|ProxyPacUrl|ProxySettings|DnsOverHttpsTemplates)$'
FirefoxPolicyKeys='^(Homepage.*|SearchEngines.*|ExtensionSettings.*|Extensions.*|NewTabPage|FirefoxHome.*|Proxy.*|DNSOverHTTPS.*|Certificates.*)$'
check_policies() {
  local fix=$1 l u h dom file key val keys
  local -a domains=(com.google.Chrome com.google.Chrome.beta com.google.Chrome.dev com.google.Chrome.canary org.chromium.Chromium com.microsoft.Edge com.microsoft.Edge.Beta com.microsoft.Edge.Dev com.microsoft.edgemac com.brave.Browser com.brave.Browser.beta com.brave.Browser.nightly com.vivaldi.Vivaldi com.operasoftware.Opera org.mozilla.firefox)
  local -a places=("/Library/Preferences")
  for l in $USERS; do places+=("${l#* }/Library/Preferences"); done
  for file in ${^places}/${^domains}.plist(N); do
    dom=${file:t:r}
    [[ $dom == org.mozilla.firefox ]] && keys=$FirefoxPolicyKeys || keys=$PolicyKeys
    # Firefox's EnterprisePoliciesEnabled switch is left alone: by itself it forces nothing.
    local found=$(osascript -l JavaScript "$TOOLS/inspect.js" policy "$file" "$keys" 2>>"$LOG" | grep -v '^EnterprisePoliciesEnabled')
    [[ -n $found ]] || continue
    if [[ $fix == fix && $MDM == 0 ]]; then
      save_undo "$file"
      u=$(stat -f %Su "$file")
      for key in ${(f)"$(print -r -- "$found" | cut -f1)"}; do
        if [[ $file == /Library/* ]]; then defaults delete "${file:r}" "$key" 2>>"$LOG"; else as_user "$u" defaults delete "$dom" "$key" 2>>"$LOG"; fi
      done
      removed "Browser rules forced in $file: ${(j:, :)${(f)$(print -r -- "$found" | cut -f1)}}"
    else
      attention "Browser rules are forced in $file: ${(j:, :)${(f)$(print -r -- "$found" | cut -f1)}}"
    fi
  done
  # Firefox's policies.json inside the app (B21).
  for file in /Applications/Firefox*.app/Contents/Resources/distribution/policies.json(N); do
    grep -qE '"(Homepage|SearchEngines|ExtensionSettings|Extensions|NewTabPage|Proxy|DNSOverHTTPS|Certificates)"' "$file" || continue
    if [[ $fix == fix && $MDM == 0 ]]; then
      quarantine "$file" && removed "Firefox rules file $file (forced the home page, search engine or add-ons)" || attention "Firefox has a rules file that forces settings ($file); it could not be moved. Reinstall Firefox from mozilla.org."
    else attention "Firefox rules file $file"; fi
  done
}

# ---------------------------------------------------------------- Chromium browsers (Chrome, Edge, Brave, Vivaldi, Opera)
ChromiumRoots() {
  local l h d
  for l in $USERS; do
    h=${l#* }
    for d in "$h/Library/Application Support"/{Google/Chrome,Google/Chrome\ Beta,Google/Chrome\ Dev,Google/Chrome\ Canary,Chromium,Microsoft\ Edge,Microsoft\ Edge\ Beta,Microsoft\ Edge\ Dev,BraveSoftware/Brave-Browser,BraveSoftware/Brave-Browser-Beta,Vivaldi,com.operasoftware.Opera,com.operasoftware.OperaGX}(N) "$h/Library/Application Support"/*/Local\ State(N:h) "$h/Library/Application Support"/*/*/Local\ State(N:h); do
      [[ -d $d ]] && print -r -- "$d"
    done
  done | awk '!seen[$0]++'
}
BrowserProcs='Google Chrome|Google Chrome Beta|Google Chrome Dev|Google Chrome Canary|Chromium|Microsoft Edge|Microsoft Edge Beta|Microsoft Edge Dev|Brave Browser|Brave Browser Beta|Vivaldi|Opera|Opera GX|Firefox|firefox|Safari'
stop_browsers() {
  local n
  for n in ${(s:|:)BrowserProcs}; do pkill -TERM -x "$n" 2>/dev/null; done
  for n in 1 2 3 4 5 6 7 8 9 10; do pgrep -qx "($BrowserProcs)" 2>/dev/null || break; sleep 1; done
  for n in ${(s:|:)BrowserProcs}; do pkill -KILL -x "$n" 2>/dev/null; done
  sleep 1
}
check_chromium() {
  local fix=$1 root prof label kind line t v owner
  local -a xids
  for root in ${(f)"$(ChromiumRoots)"}; do
    owner=${${root#/Users/}%%/*}
    kind=${${root#*/Application Support/}//\// }
    for prof in "$root"/*/Preferences(N:h) "$root"/Preferences(N:h); do
      label="$kind ($owner, ${prof:t})"
      [[ $prof == $root ]] && label="$kind ($owner)"
      for line in ${(f)"$(osascript -l JavaScript "$TOOLS/browsers.js" $fix "$label" "$prof" "$UNDO" 2>&1)"}; do
        t=${line%%$'\t'*}; v=${line#*$'\t'}
        case $t in
          R) removed "$v";;
          A) attention "$v";;
          N) note "$v";;
          Q) [[ -e $v || -L $v ]] || continue   # already moved away for another browser that used the same folder
             quarantine "$v" >/dev/null || attention "Could not move away the add-on folder $v";;
          X) xids+=("$v");;
          *) [[ -n $line ]] && attention "$label could not be checked: $line";;
        esac
      done
    done
  done
  check_external_extensions $fix "${xids[@]}"
}
# Add-ons another program told the browser to install (B10): removed with the add-on, otherwise listed.
check_external_extensions() {
  local fix=$1; shift
  local -a ids=("$@") dirs
  local l f id url
  for l in $USERS; do dirs+=("${l#* }/Library/Application Support"/{Google/Chrome,Microsoft\ Edge,BraveSoftware/Brave-Browser,Vivaldi,Chromium}/External\ Extensions(N)); done
  dirs+=(/Library/Application\ Support/*/External\ Extensions(N) /Library/Application\ Support/*/*/External\ Extensions(N) /Library/Application\ Support/*/*/*/External\ Extensions(N))
  for f in ${^dirs}/*.json(N); do
    id=${f:t:r}
    url=$(sed -n 's/.*"external_update_url"[^"]*"\([^"]*\)".*/\1/p' "$f" | head -1)
    if (( ${ids[(Ie)$id]} )) && [[ $fix == fix ]]; then quarantine "$f" && removed "The instruction that kept re-installing add-on $id ($f)"
    elif [[ $url != https://clients2.google.com/service/update2/crx* && $url != https://edge.microsoft.com/extensionwebstorebase/* ]]; then
      attention "A program told the browser to install add-on $id from outside the add-on store ($f, ${url:-no address}). If nobody here installed it on purpose, remove that file and the add-on."
    else fyi "A program asks the browser to install add-on $id from the store ($f)."; fi
  done
}

# ---------------------------------------------------------------- Firefox (B22, B25)
GoodNotifyFirefox='(google\.com|gmail\.com|youtube\.com|live\.com|office\.com|outlook\.com|microsoft\.com|whatsapp\.com|facebook\.com|messenger\.com|instagram\.com|x\.com|twitter\.com|linkedin\.com|zoom\.us|webex\.com|slack\.com|discord\.com|icloud\.com|apple\.com|yahoo\.com|amazon\.com|instructure\.com|d2l\.com|blackboard\.com|\.edu|\.gov)$'
check_firefox() {
  local fix=$1 l u h p f origin
  for l in $USERS; do
    u=${l%% *}; h=${l#* }
    for p in "$h/Library/Application Support/Firefox/Profiles"/*(N/); do
      f="$p/user.js"
      if [[ -f $f ]] && grep -E 'browser\.(startup\.homepage|search|newtab|newtabpage)' "$f" | grep -qvE "https?://([a-z0-9-]+\.)*(google\.[a-z.]+|bing\.com|duckduckgo\.com|mozilla\.org|yahoo\.com)"; then
        if [[ $fix == fix ]]; then cp "$f" "$UNDO/firefox-user.js-$u-${p:t}"; mv "$f" "$f.kit-disabled" && removed "Firefox ($u): user.js that forced the home page or search engine (renamed user.js.kit-disabled)"
        else attention "Firefox ($u): user.js forces the home page or search engine."; fi
      fi
      f="$p/extensions.json"
      if [[ -f $f ]]; then
        osascript -l JavaScript -e 'function run(a){var j=JSON.parse($.NSString.stringWithContentsOfFileEncodingError(a[0],4,null).js);return (j.addons||[]).filter(function(x){return x.location!=="app-builtin"&&x.location!=="app-system-defaults"&&x.active&&(x.foreignInstall||x.signedState<=0)}).map(function(x){return (x.defaultLocale&&x.defaultLocale.name||x.id)+"\t"+(x.foreignInstall?"put there by another program":"not signed by Mozilla")}).join("\n")}' "$f" 2>/dev/null | while IFS=$'\t' read -r n w; do
          [[ -n $n ]] && attention "Firefox ($u) add-on \"$n\" ($w). If nobody here added it, remove it: Firefox menu > Add-ons and themes."
        done
      fi
      f="$p/permissions.sqlite"
      if [[ -f $f ]]; then
        local bad=()
        for origin in ${(f)"$(sqlite3 -readonly "$f" "select origin from moz_perms where type='desktop-notification' and permission=1" 2>/dev/null)"}; do
          matches "$GoodNotifyFirefox" "$(print -r -- "$origin" | sed -E 's#^[a-z]+://##; s#[:/].*##')" || bad+=("$origin")
        done
        if (( ${#bad} )); then
          if [[ $fix == fix ]]; then
            cp "$f" "$UNDO/firefox-permissions-$u-${p:t}.sqlite"
            for origin in $bad; do sqlite3 "$f" "delete from moz_perms where type='desktop-notification' and permission=1 and origin='${origin//\'/''}'" 2>>"$LOG"; done
            removed "Firefox ($u): pop-up notifications from ${(j:, :)bad}"
          else attention "Firefox ($u): these websites may send pop-up notifications: ${(j:, :)bad}"; fi
        fi
      fi
    done
  done
}

# ---------------------------------------------------------------- Safari (B17-B20); its files need Full Disk Access
GoodSafariSearch='^(com\.google\.www|com\.bing\.www|com\.duckduckgo|com\.yahoo\.www|org\.ecosia\.www|com\.baidu\.www|com\.sogou\.www|com\.yandex\.www|ru\.yandex\.www)$'
check_safari() {
  local fix=$1 l u h hp host prov app bid url line ext parent
  [[ $FDA == 1 ]] || return 0
  for l in $USERS; do
    u=${l%% *}; h=${l#* }
    hp=$(as_user "$u" defaults read com.apple.Safari HomePage 2>/dev/null)
    if [[ -n $hp ]]; then
      host=$(print -r -- "$hp" | sed -E 's#^[a-zA-Z]+://##; s#[:/?].*##' | tr 'A-Z' 'a-z')
      if ! matches '(^|\.)(apple\.com|icloud\.com|google(\.[a-z]{2,3}){1,2}|bing\.com|yahoo\.com|duckduckgo\.com|msn\.com|microsoft\.com|live\.com|outlook\.com|office\.com|gmail\.com|youtube\.com|instructure\.com)$|\.(edu|gov)$' "$host"; then
        if [[ $fix == fix ]]; then
          print -r -- "$u Safari HomePage $hp" >> "$UNDO/safari.txt"
          as_user "$u" defaults delete com.apple.Safari HomePage 2>>"$LOG"
          [[ $(as_user "$u" defaults read com.apple.Safari NewWindowBehavior 2>/dev/null) == 0 ]] && as_user "$u" defaults delete com.apple.Safari NewWindowBehavior 2>/dev/null
          [[ $(as_user "$u" defaults read com.apple.Safari NewTabBehavior 2>/dev/null) == 0 ]] && as_user "$u" defaults delete com.apple.Safari NewTabBehavior 2>/dev/null
          removed "Safari ($u): home page $hp"
        else attention "Safari ($u): the home page is $hp"; fi
      fi
    fi
    prov=$(as_user "$u" defaults read -g NSPreferredWebServices 2>/dev/null | sed -n 's/.*NSProviderIdentifier = "\{0,1\}\([^";]*\)"\{0,1\};.*/\1/p' | head -1)
    [[ -n $prov ]] && ! matches "$GoodSafariSearch" "$prov" && attention "Safari ($u): the search engine is \"$prov\", which is not one of Safari's own. Safari > Settings > Search."
    # Safari extensions live inside apps; one from an app that no known maker signed needs a person.
    for line in ${(f)"$(as_user "$u" pluginkit -mAvvv -p com.apple.Safari.extension 2>/dev/null; as_user "$u" pluginkit -mAvvv -p com.apple.Safari.web-extension 2>/dev/null)"}; do
      [[ $line == *"Path = "* ]] || continue
      ext=${line#*Path = }; parent=${ext%%.app/*}.app
      [[ $parent == /System/* || ! -d $parent || -e $parent/Contents/_MASReceipt ]] && continue
      sig_info "$parent"; trusted && continue
      attention "Safari ($u) has an extension from \"${parent:t:r}\" ($parent), which no known maker signed. If nobody added it, drag that app to the Trash."
    done
    # Web apps (Safari "Add to Dock", Chrome app windows) named like security warnings are scareware that opens at login.
    for app in "$h/Applications"/*.app(N) "$h/Applications"/*Apps.localized/*.app(N); do
      bid=$(defaults read "$app/Contents/Info" CFBundleIdentifier 2>/dev/null)
      [[ $bid == com.apple.Safari.WebApp* || $bid == *.app.* ]] || continue
      if matches "$ScarewareWords" "${app:t:r}"; then
        if [[ $fix == fix ]]; then stop_path "$app"; quarantine "$app" && removed "Web app \"${app:t:r}\" ($u), a fake warning page that opened like a program"
        else attention "Web app \"${app:t:r}\" ($u) looks like a fake warning."; fi
      else fyi "Web app ($u): ${app:t:r}"; fi
    done
  done
}

# ---------------------------------------------------------------- remote control (step 6)
stop_remote_control() {
  local d f ip label prog rest found=()
  for d in ${(f)"$(LaunchDirs)"}; do
    local -a files=("$d"/*.plist(N)); (( ${#files} )) || continue
    while IFS=$'\t' read -r -u 3 ip label prog rest; do
      matches "$RemoteNames" "$label ${ip:t} $prog" || continue
      remove_launch_item "$ip" "$label" "remote-control program; it no longer starts by itself" "" >/dev/null && found+=("$label")
    done 3< <(osascript -l JavaScript "$TOOLS/inspect.js" launchd "${files[@]}" 2>>"$LOG")
  done
  local pid cmd
  ps -axo pid=,command= | while read -r pid cmd; do
    [[ $cmd == /Applications/* || $cmd == /Users/* || $cmd == /Library/* ]] && matches "$RemoteNames" "$cmd" && kill -TERM $pid 2>/dev/null
  done
  (( ${#found} )) && note "Remote-control programs switched off (they no longer start by themselves; the apps are still there): ${(j:, :)found}"
}
remote_builtin_report() {
  local on=()
  launchctl print system/com.openssh.sshd >/dev/null 2>&1 && on+=("Remote Login (SSH)")
  launchctl print system/com.apple.screensharing >/dev/null 2>&1 && on+=("Screen Sharing")
  pgrep -qx ARDAgent && on+=("Remote Management")
  (( ${#on} )) && attention "Other computers can connect to this Mac: ${(j:, :)on}. If nobody here uses that, switch it off in System Settings > General > Sharing."
}

# ---------------------------------------------------------------- KnockKnock second opinion (research: second-opinion scanners, 3a)
knockknock_check() {
  [[ $FDA == 1 ]] || { fyi "KnockKnock (Objective-See) was not run: it needs Full Disk Access for Terminal."; return }
  local dir="$WORK/knockknock" zip url
  mkdir -p "$dir"
  url=$(limit 30 curl -fsSL https://api.github.com/repos/objective-see/KnockKnock/releases/latest 2>/dev/null | sed -n 's/.*"browser_download_url": *"\([^"]*KnockKnock[^"]*\.zip\)".*/\1/p' | head -1)
  [[ -n $url ]] || url=https://github.com/objective-see/KnockKnock/releases/download/v4.1.0/KnockKnock_4.1.0.zip
  if ! limit 300 curl -fsSL -o "$dir/kk.zip" "$url" || ! ditto -xk "$dir/kk.zip" "$dir" 2>>"$LOG"; then
    fyi "KnockKnock could not be downloaded, so the second-opinion list was skipped."; return
  fi
  local app="$dir/KnockKnock.app"
  if ! codesign -dv "$app" 2>&1 | grep -q 'TeamIdentifier=VBG97UB4TA' || ! spctl -a -vv "$app" 2>&1 | grep -q 'Notarized Developer ID'; then
    problem "The KnockKnock download is not signed by Objective-See, so it was not run."; return
  fi
  limit 900 "$app/Contents/MacOS/KnockKnock" -whosthere -skipVT > "$dir/knockknock.json" 2> "$dir/errors.txt"
  if grep -q 'Full Disk Access' "$dir/errors.txt"; then fyi "KnockKnock refused to run without Full Disk Access."; return; fi
  # KnockKnock 4.1 JSON (measured on macOS 14-26, 2026-10-23): "signature(s)" = {signatureStatus: 0 when valid, -67062
  # when unsigned; signatureAuthorities: the signer chain, empty for ad-hoc}. Cron jobs and shell files have none.
  local out=$(osascript -l JavaScript -e 'function run(a){var t=$.NSString.stringWithContentsOfFileEncodingError(a[0],4,null);if(t.isNil())return "";t=t.js;var i=t.indexOf("{");if(i<0)return "";var j=JSON.parse(t.slice(i)),o=[],n=0,seen={};Object.keys(j).forEach(function(k){(j[k]||[]).forEach(function(x){n++;if(!x.path||seen[x.path]||/^(Cron Jobs|Shell Configuration Files)$/.test(k)||/^\/(private\/)?etc\/(defaults|periodic)\//.test(x.path))return;seen[x.path]=1;var s=x["signature(s)"]||{};if(s.signatureStatus!==0||!(s.signatureAuthorities||[]).length)o.push(k+"\t"+(x.name||"")+"\t"+x.path)})});return n+"\n"+o.join("\n")}' "$dir/knockknock.json" 2>>"$LOG")
  local total=${${(f)out}[1]}
  say "  KnockKnock listed ${total:-0} items that start by themselves; unsigned ones:"
  local cat name kp
  for line in ${${(f)out}[2,-1]}; do
    IFS=$'\t' read -r cat name kp <<< "$line"
    [[ -n $kp ]] || continue
    (( ${RemovedPaths[(I)$kp*]} )) && continue
    [[ -e $kp || $cat == BrowserExtensions ]] || continue
    fyi "KnockKnock ($cat): $name, not signed: $kp"
  done
  rm -rf "$dir/KnockKnock.app" "$dir/kk.zip"
}

# ---------------------------------------------------------------- everything, in order (also run again at the end)
unwanted_cleanup() {
  local fix=$1
  typeset -ga RemovedPaths; RemovedPaths=()
  STEALER=${STEALER:-0}
  check_apps $fix
  check_launch_items $fix
  check_home_leftovers $fix
  check_crontabs $fix
  check_profiles $fix
  check_policies $fix
  stop_browsers
  check_chromium $fix
  check_firefox $fix
  check_safari $fix
  if [[ $STEALER == 1 && -z $StealerWarned ]]; then
    StealerWarned=1
    Attention=("A PASSWORD-STEALING PROGRAM WAS ON THIS MAC. Removing it is not enough: (a) change this Mac's login password; (b) from a different device, change the Apple ID, email and bank passwords first, then every password saved in the browser; sign out of all other sessions; (c) if there is any crypto, make a new wallet on a clean device and move the money; (d) never paste a Terminal command from a web page." "${Attention[@]}")
  fi
}
