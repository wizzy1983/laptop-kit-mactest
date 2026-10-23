// inspect.js: reads Mac settings files for find-unwanted.zsh and prints plain tab-separated lines (zsh cannot read
// binary plists or nested values by itself). Run: osascript -l JavaScript inspect.js <mode> <files...>
//   launchd <plist...>   path, label, program, arguments (joined by \x1f), BundleProgram, file is empty (1/0)
//   app <App.app...>     path, bundle id, name, opens web links (1/0), has a browser engine framework (1/0)
//   profiles <xml>       scope, identifier, name, organization, payload types (,), browser settings it forces (,)
//   policy <plist> <keys regex>   each key of the file that matches, and its value as text
//   webapp <App.app>     the start address of a Safari web app, when it can be found
ObjC.import('Foundation');

function readPlist(p) {
    const d = $.NSDictionary.dictionaryWithContentsOfFile(p);
    return d.isNil() ? null : ObjC.deepUnwrap(d);
}
function text(v) {
    if (v === undefined || v === null) return '';
    if (typeof v === 'object') { try { return JSON.stringify(v); } catch (e) { return String(v); } }
    return String(v).replace(/[\t\n\r]/g, ' ');
}
function exists(p) { return $.NSFileManager.defaultManager.fileExistsAtPath(p); }
function list(p) {
    const a = $.NSFileManager.defaultManager.contentsOfDirectoryAtPathError(p, null);
    return a.isNil() ? [] : ObjC.deepUnwrap(a);
}
const BrowserDomains = /^(com\.google\.Chrome|com\.microsoft\.Edge|com\.brave\.Browser|com\.vivaldi\.Vivaldi|com\.operasoftware\.Opera|org\.mozilla\.firefox|com\.apple\.Safari|org\.chromium\.Chromium)/;
const HijackKeys = /^(Homepage|HomepageLocation|HomepageIsNewTabPage|NewTabPageLocation|RestoreOnStartup|RestoreOnStartupURLs|DefaultSearchProvider|ExtensionInstallForcelist|ExtensionSettings|ExtensionInstallSources|Proxy|DnsOverHttps|SearchEngines|Extensions|NewTabPage|FirefoxHome|HomePage|NewWindowBehavior|NewTabBehavior)/;

function run(argv) {
    const mode = argv[0], out = [];
    if (mode === 'launchd') {
        for (const p of argv.slice(1)) {
            const d = readPlist(p);
            if (!d) { out.push([p, '', '', '', '', 'unreadable'].join('\t')); continue; }
            const args = Array.isArray(d.ProgramArguments) ? d.ProgramArguments.map(text) : [];
            const prog = text(d.Program) || args[0] || '';
            out.push([p, text(d.Label), prog, args.join('\x1f'), text(d.BundleProgram), Object.keys(d).length ? '0' : '1'].join('\t'));
        }
    } else if (mode === 'app') {
        for (const p of argv.slice(1)) {
            const d = readPlist(p + '/Contents/Info.plist');
            if (!d) continue;
            let web = 0;
            for (const t of (Array.isArray(d.CFBundleURLTypes) ? d.CFBundleURLTypes : []))
                for (const s of (Array.isArray(t.CFBundleURLSchemes) ? t.CFBundleURLSchemes : [])) if (/^https?$/i.test(s)) web = 1;
            const fw = list(p + '/Contents/Frameworks').filter(f => / Framework\.framework$/.test(f) && !/^Electron /.test(f)).length ? 1 : 0;
            out.push([p, text(d.CFBundleIdentifier), text(d.CFBundleDisplayName || d.CFBundleName), web, fw].join('\t'));
        }
    } else if (mode === 'profiles') {
        const d = readPlist(argv[1]) || {};
        for (const scope of Object.keys(d)) {
            for (const pr of (Array.isArray(d[scope]) ? d[scope] : [])) {
                const types = [], forced = [];
                for (const item of (Array.isArray(pr.ProfileItems) ? pr.ProfileItems : [])) {
                    types.push(text(item.PayloadType));
                    const content = item.PayloadContent || {};
                    for (const dom of Object.keys(content)) {
                        if (!BrowserDomains.test(dom)) continue;
                        const blob = JSON.stringify(content[dom]);
                        const keys = (blob.match(/"([A-Za-z]+)"/g) || []).map(s => s.replace(/"/g, '')).filter(k => HijackKeys.test(k));
                        forced.push(dom + ':' + Array.from(new Set(keys)).join('+'));
                    }
                }
                out.push([scope, text(pr.ProfileIdentifier), text(pr.ProfileDisplayName), text(pr.ProfileOrganization), types.join(','), forced.join(',')].join('\t'));
            }
        }
    } else if (mode === 'policy') {
        const d = readPlist(argv[1]);
        const re = new RegExp(argv[2]);
        if (d) for (const k of Object.keys(d)) if (re.test(k)) out.push([k, text(d[k])].join('\t'));
    } else if (mode === 'webapp') {
        const p = argv[1], d = readPlist(p + '/Contents/Info.plist') || {};
        let url = text(d.Manifest && d.Manifest.start_url) || text(d.WebAppURL) || '';
        if (!url) {
            const m = /https?:\/\/[^\s"'<>]+/.exec(JSON.stringify(d));
            if (m) url = m[0];
        }
        out.push([p, text(d.CFBundleIdentifier), url].join('\t'));
    }
    return out.join('\n');
}
