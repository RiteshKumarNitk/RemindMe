# RemindMe — web preview run doc

Flutter app (Android-first) with a Flutter **web** build used for browser previews.
There is no `package.json`; the "server" is the Flutter web dev server (`flutter run -d web-server`).

## Reproduce the artifacts a fresh checkout needs

The web build needs the `web/` platform directory and two generated SQLite-WASM
binaries that the sqflite web package does **not** ship in the pub cache:

1. Dependencies: `flutter pub get` (lockfile already resolves everything,
   including `sqflite_common_ffi_web`, `firebase_*`, `connectivity_plus`, ...).
2. Web platform directory — if `web/` is missing:
   `flutter create --platforms=web .`
3. SQLite WASM binaries — if `web/sqflite_sw.js` or `web/sqlite3.wasm` are
   missing, regenerate them (needs network to download the wasm binary):
   `dart run sqflite_common_ffi_web:setup`
   This creates `web/sqflite_sw.js` (~254 KB) and `web/sqlite3.wasm` (~731 KB).
4. No `.env`/secret files are needed to *run* the preview: `android/app/google-services.json`
   is a documented placeholder, and Firebase is only touched when the user enables
   sync — on web without config it fails gracefully and sync stays disabled.

## Run the server

Port **8081** is used (8080 was taken on this machine). The dev server
does not auto-reload reliably after source edits on this setup — if a change
isn't picked up, restart the server.

### Check if already running
```powershell
netstat -ano | findstr "LISTENING" | findstr "8081"
```
If a dart.exe process is listening on 8081, it's already running — skip to registration.

### Start fresh (Windows, detached, outlives the terminal):
```powershell
(Start-Process -FilePath 'C:\flutter\bin\flutter.bat' -ArgumentList 'run','-d','web-server','--web-port','8081','--web-hostname','localhost' -RedirectStandardOutput '<log>' -RedirectStandardError '<log>.err' -WindowStyle Hidden -PassThru).Id
```

- stdout and stderr must go to different files (PowerShell fails otherwise).
- Confirm it survived: `Get-Process -Id <pid>`; the listener appears on `[::1]:8081`
  (IPv6 loopback) — poll `curl http://[::1]:8081/` until it returns 200 (the first
  browser load then triggers a full DDC compile; give it ~40 s).
- On a fresh port, adapt `--web-port`.

## Register in preview
```
register_preview(url="http://localhost:8081", pid=<dart_pid>)
```
Then click "Enable accessibility" in the Flutter web app to get the full semantics tree.

## Gotchas observed

- The debug web-server does **not** hot-reload file edits reliably; restart the
  server after changing `lib/` code.
- The initial browser load is slow (~30–60 s: 958 DDC modules).
- Flutter's "Enable accessibility" affordance is required before the
  accessibility tree (and therefore the preview snapshot) shows real UI.
- `home_widget` throws `MissingPluginException` on web — expected, Android-only.
