#!/bin/zsh
# verify-mac.zsh "<drive>": checks, after the kit ran, that every planted unwanted thing is gone and every KEEP item is
# still there, that the browsers still start, and what the report says. Prints PASS/FAIL lines; exits 1 on any FAIL.
set -u
VOL=$1; H=$HOME; AS="$H/Library/Application Support"
Q="/Library/Application Support/LaptopCleanupKit/Quarantine"
REPORT="$VOL/LATEST-SUMMARY-MAC.txt"
pass=0; fail=0
ok()   { if eval "$2"; then print "PASS $1"; ((pass++)); else print "FAIL $1"; ((fail++)); fi }
gone() { ok "gone: $1" "[[ ! -e \"$1\" ]]" }
kept() { ok "kept: $1" "[[ -e \"$1\" ]]" }
inrep(){ ok "report says: $1" "grep -qiF -- \"$1\" \"$REPORT\"" }
notrep(){ ok "report does not say: $1" "! grep -qiF -- \"$1\" \"$REPORT\"" }

print "== removed"
gone "$H/Applications/Wave Browser.app"; gone "$H/Library/LaunchAgents/com.wavebrowser.update.plist"
ok "Wave Browser process stopped" "! pgrep -f 'Wave Browser.app' >/dev/null"
gone "$AS/.3276169528277499560"; gone "/Library/Application Support/.3276169528277499560"
gone "$H/Library/LaunchAgents/com.SwitcherGuard.service.plist"; gone /Library/LaunchDaemons/com.SwitcherGuard.system.plist
ok "Adload process stopped" "! pgrep -f SwitcherGuard >/dev/null"
gone "$AS/com.SearchQuest"; gone "$H/Library/LaunchAgents/com.SearchQuest.plist"
ok "crontab line for SearchQuest removed" "! crontab -l 2>/dev/null | grep -q SearchQuest"
gone "$H/.mainhelper"; gone "$H/.agent"; gone "$H/.pwd"; gone /Library/LaunchDaemons/com.finder.helper.plist
gone "$H/Library/LaunchAgents/com.apple.updates.agent.plist"
gone "$H/Library/LaunchAgents/com.google.keystone.agent.plist"; gone "$AS/Google/GoogleUpdate.app"
gone /Library/LaunchDaemons/com.system.maintenance.plist; gone "$H/Library/LaunchAgents/com.pulsebrowser.updater.plist"
gone /Library/LaunchAgents/com.teamviewer.teamviewer.plist
gone "$H/Applications/Security Alert.app"
ok "quarantine holds the Wave Browser" "[[ -d \"$Q\" ]] && sudo find \"$Q\" -maxdepth 6 -name 'Wave Browser.app' | grep -q ."
ok "zshrc: stealer block removed" "! grep -q sysnotif-repair $H/.zshrc"
ok "hosts: bing line disabled" "! grep -qE '^127\.0\.0\.1[[:space:]]+www\.bing\.com' /etc/hosts"
ok "Chrome policy HomepageLocation removed" "! defaults read com.google.Chrome HomepageLocation >/dev/null 2>&1"
ok "Chrome policy DefaultSearchProviderSearchURL removed" "! defaults read com.google.Chrome DefaultSearchProviderSearchURL >/dev/null 2>&1"
ok "Chrome policy ExtensionInstallForcelist removed" "! defaults read com.google.Chrome ExtensionInstallForcelist >/dev/null 2>&1"
ok "machine-wide Chrome RestoreOnStartupURLs removed" "! defaults read /Library/Preferences/com.google.Chrome RestoreOnStartupURLs >/dev/null 2>&1"
ok "Firefox policy Homepage__URL removed" "! defaults read org.mozilla.firefox Homepage__URL >/dev/null 2>&1"
ok "Safari home page reset" "! defaults read com.apple.Safari HomePage >/dev/null 2>&1"

print "== kept"
for f in ${(f)"$(cat /tmp/kit-baseline-plists.txt)"}; do kept "$f"; done
for f in /Library/LaunchAgents/com.google.keystone.xpcservice.plist "$H/Library/LaunchAgents/com.family.backup.plist" "$H/.config/backup.sh" "$H/Applications/Notes Helper.app" /Applications/MacKeeper.app "/Applications/Norton 360.app" "$H/Applications/YouTube.app" "/Applications/Google Chrome.app" "/Applications/Microsoft Edge.app" /Applications/Firefox.app /Applications/TeamViewer.app; do kept "$f"; done
ok "zshrc: own lines kept and file still valid" "grep -q 'export KEEP_ME=1' $H/.zshrc && zsh -n $H/.zshrc"
ok "hosts: localhost kept" "grep -qE '^127\.0\.0\.1[[:space:]]+localhost' /etc/hosts"
ok "crontab KEEP line kept" "crontab -l 2>/dev/null | grep -q 'KEEP family job'"
ok "Chrome's own LastRunAppBundlePath kept" "defaults read com.google.Chrome LastRunAppBundlePath >/dev/null 2>&1"

print "== browser profiles"
python3 - "$AS" <<'PY'
import json, os, sqlite3, sys
AS = sys.argv[1]; res = []
def chk(name, cond): print(('PASS ' if cond else 'FAIL ') + name)
def g(d, *p):
    for k in p:
        if not isinstance(d, dict) or k not in d: return None
        d = d[k]
    return d
C = os.path.join(AS, 'Google/Chrome/Default')
p = json.load(open(os.path.join(C, 'Preferences'))); s = json.load(open(os.path.join(C, 'Secure Preferences')))
raw = open(os.path.join(C, 'Secure Preferences')).read()
both = lambda *k: [g(p, *k), g(s, *k)]
chk('Chrome: SearchProtect add-on removed', all(x is None for x in both('extensions', 'settings', 'jnannpdmmiphnkpaooplhegabbghlplj')))
chk('Chrome: Docs Offline (store add-on) kept', g(s, 'extensions', 'settings', 'ghbmnnjooekpmoecnnnilnnbdlolhkhi') is not None)
chk('Chrome: number 0.0 kept exactly as written', '"kit_float_probe":0.0' in raw)
chk('Chrome: developer mode off', all(x is None for x in both('extensions', 'ui', 'developer_mode')))
chk('Chrome: search engine reset', all(x is None for x in both('default_search_provider_data')) and all(x is None for x in both('default_search_provider', 'guid')))
chk('Chrome: start-up pages reset', all(x is None for x in both('session', 'startup_urls')))
chk('Chrome: account copy of start-up pages reset', all(x is None for x in both('account_values', 'session', 'startup_urls')))
chk('Chrome: home page reset', all(x is None for x in both('homepage')))
n = g(p, 'profile', 'content_settings', 'exceptions', 'notifications') or {}
chk('Chrome: notifications from news-alerts.example removed', 'https://news-alerts.example:443,*' not in n)
chk('Chrome: notifications from mail.google.com kept', 'https://mail.google.com:443,*' in n)
chk('Chrome: account copy of notifications cleaned', 'https://win-prize.example:443,*' not in (g(p, 'account_values', 'profile', 'content_settings', 'exceptions', 'notifications') or {}))
chk('Chrome: exit marked normal', g(p, 'profile', 'exit_type') == 'Normal')
chk('Chrome: saved tabs removed', not os.path.exists(os.path.join(C, 'Sessions')))
chk('Chrome: unpacked add-on folder moved away', not os.path.exists(os.path.join(AS, 'SearchProtectExt')))
db = sqlite3.connect(os.path.join(C, 'Web Data')); names = [r[0] for r in db.execute('select short_name from keywords')]; db.close()
chk('Chrome: Search Pro row removed from Web Data', 'Search Pro' not in names)
chk('Chrome: Wikipedia row kept in Web Data', 'Wikipedia' in names)
chk('Chrome: settings files still owned by the user', all(os.stat(os.path.join(C, f)).st_uid == os.getuid() for f in ('Preferences', 'Secure Preferences', 'Web Data')))
E = os.path.join(AS, 'Microsoft Edge/Default'); es = json.load(open(os.path.join(E, 'Secure Preferences')))
chk('Edge: SearchShield add-on removed', g(es, 'extensions', 'settings', 'cajkghbacphcjgemgmmachjcgamkcacd') is None)
chk('Edge: search engine reset', g(es, 'default_search_provider_data') is None)
X = os.path.join(AS, 'Google/Chrome/External Extensions')
chk('Chrome: re-install instruction for SearchProtect removed', not os.path.exists(os.path.join(X, 'jnannpdmmiphnkpaooplhegabbghlplj.json')))
chk('Chrome: store re-install instruction kept', os.path.exists(os.path.join(X, 'aapbdbdomjkkjkaonfhkkikfgjllcleb.json')))
import glob
for fp in glob.glob(os.path.join(AS, 'Firefox/Profiles/*kittest')):
    chk('Firefox: forced user.js disabled', not os.path.exists(os.path.join(fp, 'user.js')) and os.path.exists(os.path.join(fp, 'user.js.kit-disabled')))
    db = sqlite3.connect(os.path.join(fp, 'permissions.sqlite')); o = [r[0] for r in db.execute("select origin from moz_perms where type='desktop-notification'")]; db.close()
    chk('Firefox: notifications from win-prize.example removed', 'https://win-prize.example' not in o)
    chk('Firefox: notifications from mail.google.com kept', 'https://mail.google.com' in o)
PY

print "== report"
ok "report exists on the drive" "[[ -s \"$REPORT\" ]]"
inrep "RESULT: NEEDS ATTENTION"
inrep "PASSWORD-STEALING PROGRAM"; inrep "Wave Browser"; inrep "SwitcherGuard"; inrep "pretends to be Apple"; inrep "uses the name of com.google"
inrep "downloads and runs code"; inrep "no longer there"; inrep "Remote-control programs switched off"; inrep "MacKeeper"; inrep "Norton 360"
inrep "Search Pro"; inrep "scam-alert.example"; inrep "news-alerts.example"; inrep "Safari"; inrep "Search Helper"; inrep "www.bing.com"
notrep "Came back"; notrep "could not be checked"; notrep "PROBLEM"; notrep "Notes Helper\" is a web browser"
notrep "family.backup (" ; notrep "keystone.xpcservice"
ok "backup holds the planted document" "tar -tf \"\$(ls -d \"$VOL\"/Backup/*/$(id -un).tar | head -1)\" | grep -q 'Documents/kit-backup-test.txt'"
ok "no ._ files left on the drive" "[[ -z \$(find \"$VOL\" -name '._*' | head -1) ]]"

print "== browsers still start"
for b in "Google Chrome" "Microsoft Edge"; do
  "/Applications/$b.app/Contents/MacOS/$b" --no-first-run --no-default-browser-check --use-mock-keychain about:blank >/dev/null 2>&1 &
  sleep 20
  ok "$b starts and keeps running" "pgrep -x \"$b\" >/dev/null"
  pkill -TERM -x "$b"; sleep 6; pkill -KILL -x "$b" 2>/dev/null
done
python3 - "$AS" <<'PY'
import json, os, sys
C = os.path.join(sys.argv[1], 'Google/Chrome/Default')
s = json.load(open(os.path.join(C, 'Secure Preferences'))); p = json.load(open(os.path.join(C, 'Preferences')))
reset = json.dumps(s.get('prefs', {}).get('tracked_preferences_reset', [])) + json.dumps(p.get('prefs', {}).get('tracked_preferences_reset', []))
print(('PASS ' if 'ghbmnnjooekpmoecnnnilnnbdlolhkhi' in json.dumps(s.get('extensions', {}).get('settings', {})) else 'FAIL ') + 'Chrome after restart: Docs Offline add-on still there')
print(('PASS ' if 'ghbmnnjooekpmoecnnnilnnbdlolhkhi' not in reset else 'FAIL ') + 'Chrome after restart: did not reset the kept add-on (' + reset[:200] + ')')
print(('PASS ' if 'searchpro' not in json.dumps(s).lower() + json.dumps(p).lower() else 'FAIL ') + 'Chrome after restart: Search Pro did not come back')
PY
print "== totals: $pass shell checks passed, $fail failed (python checks are counted by the workflow)"
(( fail == 0 ))
