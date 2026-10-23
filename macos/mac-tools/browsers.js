// browsers.js: checks one Chromium browser profile (Chrome, Edge, Brave, Vivaldi, Opera) and, in "fix" mode, repairs it.
// Run by clean-mac.zsh as: osascript -l JavaScript browsers.js <fix|check> "<label>" "<profile folder>" "<undo folder>"
// It prints one line per finding: R<TAB>text (removed), A<TAB>text (needs a person), N<TAB>text (note),
// Q<TAB>path (a folder for the caller to move to quarantine), X<TAB>id (an add-on whose outside install entries the
// caller removes). The rules are the Windows kit's (tools/Find-Unwanted.ps1, Repair-ChromiumProfile), from
// research/2026-10-23-browser-hijack-detection.md: protected settings are only ever DELETED (the browser then uses its
// own default), never changed, and their checksums ("protection.macs") are never touched.
// Numbers are kept exactly as written (a plain JSON rewrite turns 0.0 into 0, which changes a checksummed value and
// makes the browser reset a good add-on), so this file has its own small JSON reader and writer.
ObjC.import('Foundation');
const app = Application.currentApplication();
app.includeStandardAdditions = true;

const BadExtensionIds = ['jnannpdmmiphnkpaooplhegabbghlplj', 'cajkghbacphcjgemgmmachjcgamkcacd'];
const BadExtensionNames = /^Search ?(Protect|Shield|Pro|Marquis|Baron)\b/i;
const GoodSearchHosts = /(^|\.)(google(\.[a-z]{2,3}){1,2}|bing\.com|yahoo\.com|yahoo\.co\.[a-z]+|duckduckgo\.com|ecosia\.org|search\.brave\.com|startpage\.com|yandex(\.[a-z]{2,3}){1,2}|ya\.ru|baidu\.com|qwant\.com|naver\.com|seznam\.cz|perplexity\.ai|you\.com|kagi\.com|mojeek\.com|daum\.net|coccoc\.com|sogou\.com|so\.com)$/;
const GoodStartHosts = /(^|\.)(msn\.com|microsoft\.com|live\.com|office\.com|outlook\.com|gmail\.com|youtube\.com|google(\.[a-z]{2,3}){1,2}|bing\.com|yahoo\.com|duckduckgo\.com|instructure\.com|apple\.com|icloud\.com)$|\.(edu|gov)$/;
// Websites that may keep sending notifications (mail, chat, school). Every other allowed site is removed.
const GoodNotifyHosts = /(^|\.)(google\.com|gmail\.com|youtube\.com|live\.com|office\.com|office365\.com|outlook\.com|microsoft\.com|whatsapp\.com|facebook\.com|messenger\.com|instagram\.com|x\.com|twitter\.com|linkedin\.com|zoom\.us|webex\.com|slack\.com|discord\.com|icloud\.com|apple\.com|yahoo\.com|amazon\.com|instructure\.com|d2l\.com|blackboard\.com)$|\.(edu|gov)$/;

// ---- JSON that keeps numbers exactly as written ----
function Num(raw) { this.raw = raw; }
function parseJson(text) {
    let i = 0;
    const n = text.length;
    const reNum = /-?\d+(\.\d+)?([eE][+-]?\d+)?/y, reStr = /"(?:[^"\\]|\\.)*"/y;
    function ws() { while (i < n && ' \t\r\n'.indexOf(text[i]) >= 0) i++; }
    function str() {
        reStr.lastIndex = i;
        const m = reStr.exec(text);
        if (!m) throw new Error('bad text at character ' + i);
        i = reStr.lastIndex;
        return JSON.parse(m[0]);
    }
    function val() {
        ws();
        const c = text[i];
        if (c === '{') {
            i++;
            const o = Object.create(null);
            ws();
            if (text[i] === '}') { i++; return o; }
            for (;;) {
                ws();
                const k = str();
                ws();
                if (text[i++] !== ':') throw new Error('missing : at character ' + i);
                o[k] = val();
                ws();
                const d = text[i++];
                if (d === '}') return o;
                if (d !== ',') throw new Error('missing , at character ' + i);
            }
        }
        if (c === '[') {
            i++;
            const a = [];
            ws();
            if (text[i] === ']') { i++; return a; }
            for (;;) {
                a.push(val());
                ws();
                const d = text[i++];
                if (d === ']') return a;
                if (d !== ',') throw new Error('missing , at character ' + i);
            }
        }
        if (c === '"') return str();
        if (text.startsWith('true', i)) { i += 4; return true; }
        if (text.startsWith('false', i)) { i += 5; return false; }
        if (text.startsWith('null', i)) { i += 4; return null; }
        reNum.lastIndex = i;
        const m = reNum.exec(text);
        if (!m) throw new Error('bad value at character ' + i);
        i = reNum.lastIndex;
        return new Num(m[0]);
    }
    const v = val();
    ws();
    if (i !== n) throw new Error('extra text at character ' + i);
    return v;
}
function toJson(v) {
    if (v === null || v === undefined) return 'null';
    if (v instanceof Num) return v.raw;
    if (typeof v === 'boolean') return v ? 'true' : 'false';
    if (typeof v === 'number') return String(v);
    if (typeof v === 'string') return JSON.stringify(v);
    if (Array.isArray(v)) return '[' + v.map(toJson).join(',') + ']';
    return '{' + Object.keys(v).map(k => JSON.stringify(k) + ':' + toJson(v[k])).join(',') + '}';
}
function isObj(x) { return x !== null && typeof x === 'object' && !Array.isArray(x) && !(x instanceof Num); }
function has(o, k) { return isObj(o) && Object.prototype.hasOwnProperty.call(o, k); }
function num(x) { return x instanceof Num ? Number(x.raw) : (typeof x === 'number' ? x : NaN); }
function getPath(o, path) {
    for (const k of path) { if (!has(o, k)) return undefined; o = o[k]; }
    return o;
}
function removePath(o, path) {
    const parent = path.length === 1 ? o : getPath(o, path.slice(0, -1));
    if (has(parent, path[path.length - 1])) { delete parent[path[path.length - 1]]; return true; }
    return false;
}

// ---- files ----
function exists(p) { return $.NSFileManager.defaultManager.fileExistsAtPath(p); }
function readText(p) {
    const s = $.NSString.stringWithContentsOfFileEncodingError(p, $.NSUTF8StringEncoding, null);
    return s.isNil() ? null : s.js;
}
function sh(cmd) { return app.doShellScript(cmd); }
function q(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }
// Writes the file in place and gives it back its owner and permissions (this runs as root).
function writeText(p, text) {
    const owner = sh('/usr/bin/stat -f %u:%g:%Lp ' + q(p)).split(':');
    if (!$(text).writeToFileAtomicallyEncodingError(p, true, $.NSUTF8StringEncoding, null)) throw new Error('could not write ' + p);
    sh('/usr/sbin/chown ' + owner[0] + ':' + owner[1] + ' ' + q(p) + ' && /bin/chmod ' + owner[2] + ' ' + q(p));
}
function backup(p, undo, tag) {
    sh('/bin/mkdir -p ' + q(undo) + ' && /bin/cp -p ' + q(p) + ' ' + q(undo + '/' + tag + '-' + Date.now()));
}
function listDirs(p) {
    const a = $.NSFileManager.defaultManager.contentsOfDirectoryAtPathError(p, null);
    return a.isNil() ? [] : ObjC.deepUnwrap(a);
}

// ---- web addresses ----
function urlHost(url) {
    let u = String(url || '').replace(/,\*$/, '').replace(/^\[\*\.\]/, '');
    if (!/^[a-z][a-z0-9+.-]*:\/\//i.test(u)) u = 'https://' + u;
    const m = /^[a-z][a-z0-9+.-]*:\/\/(?:[^@\/?#]*@)?(\[[^\]]*\]|[^:\/?#]*)/i.exec(u);
    return m ? m[1].toLowerCase() : '';
}
function goodSearch(url) {
    if (!url || /^\{[a-z]+:baseURL\}/.test(url)) return true;
    return GoodSearchHosts.test(urlHost(url));
}

// ---- add-on details from its manifest ----
function extensionInfo(profileDir, id, entry) {
    let man = isObj(entry.manifest) ? entry.manifest : null;
    const path = typeof entry.path === 'string' ? entry.path : '';
    let dir = '';
    if (path.startsWith('/')) dir = path;
    else {
        const base = profileDir + '/Extensions/' + id;
        const vers = listDirs(base).sort().reverse();
        if (vers.length) dir = base + '/' + vers[0];
    }
    if (!man && dir && exists(dir + '/manifest.json')) { try { man = parseJson(readText(dir + '/manifest.json')); } catch (e) {} }
    let name = id;
    if (man && typeof man.name === 'string') {
        name = man.name;
        if (/^__MSG_/.test(name) && dir) {
            const key = name.replace(/^__MSG_/, '').replace(/__$/, '').toLowerCase();
            const locales = ['en', 'en_US'];
            if (typeof man.default_locale === 'string') locales.push(man.default_locale);
            for (const loc of locales) {
                const t = readText(dir + '/_locales/' + loc + '/messages.json');
                if (!t) continue;
                try {
                    const msgs = parseJson(t);
                    for (const k of Object.keys(msgs)) if (k.toLowerCase() === key && has(msgs[k], 'message')) name = msgs[k].message;
                } catch (e) {}
                if (!/^__MSG_/.test(name)) break;
            }
        }
    }
    const loc = has(entry, 'location') ? num(entry.location) : 0;
    return { id: id, name: name, location: loc, dir: dir, man: man, path: path };
}

function run(argv) {
    const fix = argv[0] === 'fix', label = argv[1], dir = argv[2], undo = argv[3];
    const out = [];
    const R = t => out.push('R\t' + t), A = t => out.push('A\t' + t), N = t => out.push('N\t' + t);
    const tag = label.replace(/\W/g, '');
    const docs = {};
    for (const n of ['Preferences', 'Secure Preferences']) {
        const f = dir + '/' + n;
        if (!exists(f)) continue;
        try { docs[f] = parseJson(readText(f) || ''); }
        catch (e) { A(label + ': its settings file ' + n + ' could not be read (' + e.message + ').'); }
    }
    const files = Object.keys(docs);
    if (!files.length) return out.join('\n');
    const changed = {};
    const drop = path => { for (const f of files) if (removePath(docs[f], path)) changed[f] = true; };

    // 1. Add-ons loaded by hand (developer mode), known hijackers, and add-ons that switch the search engine.
    const seen = {};
    for (const f of files) {
        const settings = getPath(docs[f], ['extensions', 'settings']);
        if (!isObj(settings)) continue;
        for (const id of Object.keys(settings)) {
            const e = settings[id];
            if (seen[id] || !isObj(e)) continue;
            seen[id] = true;
            const x = extensionInfo(dir, id, e);
            let why = '';
            // Chromium's Manifest::Location: 4 = unpacked (loaded by hand), 8 = command line.
            if (x.location === 4 || x.location === 8) why = 'loaded by hand from outside the add-on store';
            else if (BadExtensionIds.indexOf(id) >= 0 || BadExtensionNames.test(x.name)) why = 'a known search hijacker';
            else {
                const sp = getPath(x.man, ['chrome_settings_overrides', 'search_provider', 'search_url']);
                const upd = String(getPath(x.man, ['update_url']) || '');
                const fromStore = e.from_webstore === true || e.was_installed_by_default === true || /^https:\/\/(clients2\.google\.com|edge\.microsoft\.com)\//.test(upd);
                const takesOver = getPath(x.man, ['chrome_url_overrides', 'newtab']) || getPath(x.man, ['chrome_settings_overrides', 'homepage']) || getPath(x.man, ['chrome_settings_overrides', 'startup_pages']);
                if (sp && !goodSearch(String(sp))) why = 'it switches the search engine to ' + urlHost(String(sp));
                else if (takesOver && !fromStore && x.location !== 5 && x.location !== 10) why = 'it takes over the new tab or home page and did not come from the add-on store';
            }
            if (why) {
                if (fix) {
                    drop(['extensions', 'settings', id]);
                    if (x.location === 4 && x.dir && !/^\/(System|Applications)\//.test(x.dir)) out.push('Q\t' + x.dir);
                    if (exists(dir + '/Extensions/' + id)) out.push('Q\t' + dir + '/Extensions/' + id);
                    out.push('X\t' + id);
                    R(label + ' add-on "' + x.name + '" (' + why + ')');
                } else A(label + ' add-on "' + x.name + '" (' + why + ')');
                continue;
            }
            if (getPath(x.man, ['chrome_url_overrides', 'newtab']))
                A(label + ' add-on "' + x.name + '" replaces the new tab page. If nobody chose it, remove it: in the browser open the Extensions page and click Remove.');
        }
    }

    // 2. Developer mode lets add-ons from anywhere run.
    for (const f of files) {
        if (getPath(docs[f], ['extensions', 'ui', 'developer_mode']) === true) {
            if (fix) { drop(['extensions', 'ui', 'developer_mode']); R(label + ': developer mode (lets add-ons from outside the store run) switched off'); }
            else A(label + ': developer mode is on (lets add-ons from outside the store run).');
            break;
        }
    }

    // 3. Search engine: set in the settings, or a pointer (guid) to a row in the "Web Data" database.
    for (const f of files) {
        const t = getPath(docs[f], ['default_search_provider_data', 'template_url_data']);
        if (!isObj(t)) continue;
        const badNewTab = t.new_tab_url && !goodSearch(String(t.new_tab_url));
        if (badNewTab || !goodSearch(String(t.url || ''))) {
            const what = String(t.short_name || '') + ' (' + urlHost(String(t.url || '')) + ')';
            if (fix) { drop(['default_search_provider_data']); drop(['default_search_provider', 'guid']); R(label + ': search engine ' + what + " (set back to the browser's normal one)"); }
            else A(label + ': the search engine is ' + what + '.');
        }
    }
    let guid = '';
    for (const f of files) { const g = getPath(docs[f], ['default_search_provider', 'guid']); if (g) guid = String(g); }
    const webData = dir + '/Web Data';
    if (exists(webData)) {
        try {
            const raw = sh('/usr/bin/sqlite3 -readonly -ascii ' + q(webData) + ' "SELECT id, short_name, keyword, url, prepopulate_id, sync_guid, new_tab_url FROM keywords"');
            for (const rec of raw.split('\x1e')) {
                if (!rec) continue;
                const r = rec.split('\x1f');
                const isDefault = guid && r[5] === guid;
                if (Number(r[4]) > 0 || (goodSearch(r[3]) && goodSearch(r[6]))) continue;
                // Only the engine in use, or one with a hijacker's name, is removed; site shortcuts people made stay.
                if (!isDefault && !BadExtensionNames.test(r[1])) continue;
                const what = r[1] + ' (' + urlHost(r[3]) + ')';
                if (fix) {
                    backup(webData, undo, 'WebData-' + tag);
                    sh('/usr/bin/sqlite3 ' + q(webData) + ' "DELETE FROM keywords WHERE id = ' + Number(r[0]) + '"');
                    if (isDefault) drop(['default_search_provider']);
                    R(label + ': search engine ' + what + " (set back to the browser's normal one)");
                } else A(label + ': the search engine is ' + what + '.');
            }
        } catch (e) {
            A(label + ': its list of search engines could not be checked (' + e.message + '). Check Settings > Search engine in that browser.');
        }
    }

    // 4. Start-up pages and home page pointing to an unknown site. Chrome keeps a second, account-synced copy of these
    // under "account_values" (research/2026-10-23-mac-browser-hijacks.md, 1.3); both copies are checked.
    for (const f of files) for (const pre of [[], ['account_values']]) {
        const urls = getPath(docs[f], pre.concat(['session', 'startup_urls']));
        const bad = (Array.isArray(urls) ? urls : []).filter(u => u && !GoodStartHosts.test(urlHost(String(u))));
        if (bad.length) {
            if (fix) { drop(pre.concat(['session', 'startup_urls'])); drop(pre.concat(['session', 'restore_on_startup'])); R(label + ': start-up page(s) ' + bad.join(', ') + ' (now opens a new tab)'); }
            else A(label + ': opens ' + bad.join(', ') + ' when it starts.');
        }
        const home = String(getPath(docs[f], pre.concat(['homepage'])) || '');
        if (home && !/^(chrome|edge|brave|vivaldi|opera|about):/.test(home) && !GoodStartHosts.test(urlHost(home))) {
            if (fix) { drop(pre.concat(['homepage'])); drop(pre.concat(['homepage_is_newtabpage'])); R(label + ': home page ' + home); }
            else A(label + ': the home page is ' + home + '.');
        }
    }

    // 5. Saved tabs: a force-closed browser offers to restore pages, and one click reopens a scam page. The tabs go to the
    // undo folder (copied, then deleted: the undo folder is on the USB drive), and the exit is marked normal.
    const plain = dir + '/Preferences';
    if (fix) {
        const saved = ['Sessions', 'Sessions_Encrypted', 'Current Session', 'Current Tabs', 'Last Session', 'Last Tabs'].filter(s => exists(dir + '/' + s));
        if (saved.length) {
            const dest = undo + '/open-tabs-' + tag + '-' + Date.now();
            sh('/bin/mkdir -p ' + q(dest));
            for (const s of saved) sh('/bin/cp -Rp ' + q(dir + '/' + s) + ' ' + q(dest + '/') + ' && /bin/rm -rf ' + q(dir + '/' + s));
            N(label + ': the tabs that were open will not reopen, so a scam page cannot come back (they were moved to the undo folder; bookmarks are untouched).');
        }
        const p = getPath(docs[plain], ['profile']);
        if (isObj(p)) {
            if (has(p, 'exit_type') && p.exit_type !== 'Normal') { p.exit_type = 'Normal'; changed[plain] = true; }
            if (has(p, 'exited_cleanly') && p.exited_cleanly !== true) { p.exited_cleanly = true; changed[plain] = true; }
        }
    }

    // 6. Notifications: remove every allowed website except mail, chat and school sites, and stop websites from asking.
    if (docs[plain]) {
        for (const pre of [[], ['account_values']]) {
            const exc = getPath(docs[plain], pre.concat(['profile', 'content_settings', 'exceptions', 'notifications']));
            const allowed = [];
            if (isObj(exc)) for (const site of Object.keys(exc)) {
                const e = exc[site];
                if (has(e, 'setting') && num(e.setting) === 1 && !GoodNotifyHosts.test(urlHost(site))) allowed.push(site);
            }
            if (allowed.length) {
                const names = allowed.map(urlHost).join(', ');
                if (fix) { for (const s of allowed) delete exc[s]; changed[plain] = true; R(label + ': pop-up notifications from ' + names); }
                else A(label + ': these websites may send pop-up notifications: ' + names + '.');
            }
        }
        if (fix && isObj(docs[plain].profile)) {
            let d = getPath(docs[plain], ['profile', 'default_content_setting_values']);
            if (d === undefined) { d = Object.create(null); docs[plain].profile.default_content_setting_values = d; }
            if (isObj(d) && num(d.notifications) !== 2) {
                d.notifications = new Num('2'); changed[plain] = true;
                N(label + ': websites can no longer ask to send pop-up notifications.');
            }
        }
    }

    if (fix) for (const f of Object.keys(changed)) {
        backup(f, undo, f.split('/').pop().replace(/ /g, '') + '-' + tag);
        writeText(f, toJson(docs[f]));
    }
    return out.join('\n');
}
