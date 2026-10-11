# Parche Roku

Media center for **Roku** that plays content from the **addons you add** (compatible with the Stremio addon protocol). It
neither includes nor hosts any video catalog of its own. It is a Roku channel written in **BrightScript + SceneGraph**.
It is the Roku version of [Parche](https://github.com/fsoftt/Parche), the main app.

- Catalog from **Cinemeta** (no key) or **TMDB** (optional key).
- Sources from the **source addons** you add, sorted by preferred language, quality (with a cap) and size. Each source is
  described in plain language ("1080p · Original Blu-ray · 2.1 GB", "Origin: …").
- External subtitles (SRT) from the configured **subtitle addons** (OpenSubtitles by default), according to your languages.
- **Continue watching** (saves the position and resumes from Home) and **My list**.
- FHD 1920x1080 interface, dark theme with pink (#EC4899) and purple (#8B5CF6) accents, fully navigable with the remote.
- Spanish (Latin American first), English and Portuguese (switch in Settings).

> Parche Roku is compatible with the Stremio addon protocol, but it is an independent project: it is not affiliated with
> Stremio and does not use its brand.

## Adding addons

Without source addons you can browse the catalog, search and use My list, but when you ask for sources you get the
message "Add a sources addon in Settings." with a button that opens Settings.

1. In the channel, open **Settings**.
2. **Add sources addon**: press OK and type or paste the addon URL. The *manifest* URL (`https://…/manifest.json`) or the
   addon base works; `stremio://…` is also accepted. Only `http://` and `https://` addresses are allowed.
3. To remove an addon, focus its row in Settings and press `*` on the remote.
4. The same goes for **Add subtitles addon** (`https://opensubtitles-v3.strem.io` is included by default). All of them
   are queried, the tracks are merged, duplicates are removed and the result is filtered by your languages; if one
   fails it is skipped, and if all fail the video plays without subtitles.
5. Optional: **TMDB key (optional)** (v3 key or v4 token from https://www.themoviedb.org/settings/api) for data in your
   language and more rows (trending, top rated). Without a key, Cinemeta is used.
6. Preferred languages, max quality and subtitles: press OK to cycle through the options.

> Tip: typing a URL with the remote is awkward. Use the keyboard in the **Roku mobile app** (it appears when you open the
> on-screen keyboard dialog) to paste the URL from your phone's clipboard.

Roku only plays sources that arrive as a direct HTTP(S) link; the rest are discarded.

## Step-by-step installation

You need a Roku (tested on a **Roku Express**, Roku OS 15.3) and a PC on the **same network** as the Roku. The channel is
not in the Roku store: it is installed in developer mode ("sideload").

### 1. Enable developer mode on the Roku

1. Go to the Roku home screen. If the Roku is new, sign in with your Roku account first.
2. With the remote, press, in this order and without long pauses:
   **Home ×3, Up ×2, Right, Left, Right, Left, Right**.
   If nothing happens, repeat the sequence faster.
3. *Developer Settings* opens. **Note the IP** shown (for example `http://192.168.1.16`).
4. Choose **Enable installer and restart** and accept the SDK agreement (you may need to scroll to the end of the text).
5. Create a developer **password**. It is only for installing channels (user `rokudev`), not your Roku account password.
   The Roku restarts.

To check that it is active, from the PC: `curl http://YOUR_ROKU_IP:8060/query/device-info` should show
`<developer-enabled>true</developer-enabled>`.

### 2. Package the channel

On the PC, with [Node.js](https://nodejs.org) installed, inside this folder:

```
npm install
npm run package
```

It produces `dist/ParcheRoku-<version>-public.zip` (for example `ParcheRoku-0.1.00001-public.zip`; the version comes from
the `manifest`). Beforehand it validates the code with BrighterScript and runs the tests; `node scripts/package.js
--skip-check` skips that validation.

If there is a plugin next to the repo (folder `../ParcheRoku.Sources` or the one given by the `PARCHE_ROKU_PLUGINS`
variable), packaging merges it into the zip and the file is named `ParcheRoku-<version>.zip`. With `--no-plugins`
(`npm run package -- --no-plugins`) it is ignored and you always get the neutral client. A plugin is a folder with
`components/` (its `components/lib/Plugins.brs` replaces the neutral file in the repo, which documents the extension
points) and, optionally, `tests/`.

### 3. Install on the Roku

**From the browser:**

1. Open `http://YOUR_ROKU_IP` on the PC. User `rokudev` and the password from step 1.
2. In *Development Application Installer* click **Upload**, choose the `.zip` and then **Install** (or **Replace** if
   there was already a version). The channel starts by itself.

**With a single command** (packages, installs and opens the channel; handy for quick reinstalls):

```
# PowerShell
$env:ROKU_IP = "YOUR_ROKU_IP"; $env:ROKU_PASS = "PASSWORD"; npm run deploy

# bash / macOS / Linux
ROKU_IP=YOUR_ROKU_IP ROKU_PASS=PASSWORD npm run deploy
```

Options: `npm run deploy -- --skip-check` (no validation), `npm run deploy -- --no-package` (installs the latest `.zip`
without repackaging) and `npm run deploy -- --no-plugins`. Requires Node 18 or later. Opening the channel at the end only
works with network access set to *Permissive* (see [Debugging](#debugging)); otherwise, open it with the remote.

**With `curl`** (no Node):

```
curl --digest -u rokudev:PASSWORD -F "mysubmit=Install" -F "archive=@dist/ParcheRoku-0.1.00001-public.zip" http://YOUR_ROKU_IP/plugin_install
```

In Windows PowerShell 5.1 type **`curl.exe`**: plain `curl` is an alias of `Invoke-WebRequest` and does not understand
these options. The response should include `Install Success`.

The channel appears on the Roku home screen as **Parche** with the *dev* label.

### 4. Configure

Open the channel, go to **Settings** and add your addons (see [Adding addons](#adding-addons)).

### Notes

- There can be only **one** channel in developer mode: if you install another, or disable developer mode (repeating the
  sequence and choosing *Disable installer*), Parche is deleted. Your settings too.
- Updating means repackaging and installing again: saved settings are kept (including those from earlier versions:
  fields this version does not use are kept as they are in the registry).
- The Roku's IP may change if the router reassigns it. If it stops responding, look it up again in *Developer Settings*
  or in *Settings → Network → About*.
- To **uninstall**: open `http://YOUR_ROKU_IP` and click **Delete**. The channel and its settings are removed.

### Common problems

| Symptom | Cause and fix |
| --- | --- |
| The remote sequence does not open *Developer Settings* | Do it from the Roku home screen (not inside a channel) and faster, without pauses. |
| `http://YOUR_ROKU_IP` does not respond | Wrong IP, the PC is on another network (or the guest network), or developer mode is not active. Check with `curl.exe http://YOUR_ROKU_IP:8060/query/device-info`. |
| `401 Unauthorized` when installing | Wrong developer password. If you forgot it, disable and re-enable developer mode to create a new one. |
| `Install Failure: Compilation Failed` | BrightScript error. See the exact line in the console (`telnet YOUR_ROKU_IP 8085`) and run `npm run lint`. |
| `Identical to previous version` | That same `.zip` is already installed; no need to reinstall. |
| The channel does not appear on Home | Look for it at the end of the channel list; if it is not there, the installation failed: check the installer's response. |
| `403` when using ECP (`:8060/keypress`, `launch`) | *Network access → Permissive* is missing (see [Debugging](#debugging)). |
| "Add a sources addon in Settings." appears | No source addon is configured: see [Adding addons](#adding-addons). |
| Sources show up but nothing plays | The addon may return links Roku cannot open, or that require an account or credentials in the addon itself. Try another source from the list or check the addon's configuration. |

## Debugging

- **Channel console:** `telnet YOUR_ROKU_IP 8085` shows the `print`s, warnings and BrightScript errors. If the channel
  closes by itself, the error line appears there. Windows does not ship with `telnet` enabled: turn it on in *Turn Windows
  features on or off → Telnet Client*, or use PuTTY (*Raw* connection, port 8085).
- In Windows PowerShell 5.1 use **`curl.exe`** in all the commands below (plain `curl` is a different program).
- **Screenshots:** at `http://YOUR_ROKU_IP`, menu *Utilities → Screenshot*. The video layer does **not** appear in
  screenshots (it looks black even while playing); to know whether it is playing use
  `curl http://YOUR_ROKU_IP:8060/query/media-player` (`state="play"`, position and format).
- **Control the Roku from the PC (ECP):** `curl -d '' http://YOUR_ROKU_IP:8060/keypress/Down` (also `Up`, `Left`,
  `Right`, `Select`, `Back`, `Home`, and `Lit_a` to type letters). Roku blocks it by default (`403`/`401`):
  enable it in *Settings → System → Advanced system settings → Control by mobile apps → Network access → Permissive*.
  You can set it back when you are done.
  > Be careful when automating: before each key, check that the channel is still on screen
  > (`curl http://YOUR_ROKU_IP:8060/query/active-app` should say `id="dev"`). If the channel closed, the keys land in
  > the Roku menus and may change its settings.
- **Open the channel without the remote:** `curl -d '' http://YOUR_ROKU_IP:8060/launch/dev`.

## Controls

| Where | Remote |
| --- | --- |
| Top menu (Home, Search, My list, Settings) | Up from the first row; left/right and OK |
| Home | The hero shows the focused title; OK opens its page (in "Continue watching" it resumes directly) |
| Detail page | Play/Resume, + My list; for series, seasons on the left and episodes on the right |
| Sources | "Play the best" or pick a row; if one does not respond in 45 s the next is tried |
| Player | Standard Roku controls; `*` switches subtitle track; Back saves the position |
| My list | `*` removes the focused title |
| Settings | OK changes or opens the keyboard; `*` removes the focused addon |

## Structure

```
manifest                 title, version, icons and splash screen (FHD UI)
source/main.brs          entry point
components/
  MainScene.*            navigation: roots (Home/Search/My list/Settings) + stack (detail, sources, player)
  HomeScreen.* SearchScreen.* DetailScreen.* SourcePickerScreen.* PlayerScreen.* MyListScreen.* SettingsScreen.*
  ButtonBar.*            menu and buttons with visible focus
  PosterItem.* TextItem.* EpisodeItem.*   list cells (pink focus ring)
  MediaNode.xml RowNode.xml               data nodes
  ApiTask.*              network Task (roUrlTransfer + SetCertificatesFile + ParseJson)
  lib/
    Streams.brs          source parsing, ranking and plain-language description (pure)
    Language.brs         language detection and subtitle codes (pure)
    Settings.brs         settings, addon list, Continue watching/My list (pure) and registry (roRegistrySection)
    Catalog.brs          Cinemeta/TMDB URLs and parsing (pure)
    Api.brs              HTTP requests and operations (only inside the Task)
    Plugins.brs          extension points (neutral version; a plugin replaces it when packaging)
    Strings.brs          es/en/pt translations       Ui.brs / Util.brs  helpers
images/                  icons, splash screen and gradients (generated by scripts/make-images.js)
scripts/package.js       validation + zip for sideload      scripts/deploy.js  installs on the Roku (npm run deploy)
scripts/lint.js          BrighterScript (public tree and, if there is a plugin, the merged one)   scripts/plugins.js  finds the plugin
scripts/make-images.js   placeholder PNGs
tests/                   tests of the pure logic (npm test)
```

Persistence (`roRegistrySection "Parche"`): `settings`, `mylist` (max 50) and `watch` (max 15). Roku limits the
registry to ~32 KB per channel, which is why compact versions of the titles are stored.

## Development and validation

```
npm install
npm run lint      # BrighterScript + bslint: must give 0 errors and 0 warnings (public tree and, if there is a plugin, the merged one)
npm test          # ranking, source parsing, addons, settings, history, catalogs and translations (Node "brs" interpreter)
npm run images    # regenerates the PNGs
```

`npm run lint -- --no-plugins` and `npm test -- --no-plugins` validate only the public tree. The tests run the pure
logic (everything in `components/lib` except network and UI) with the `brs` interpreter in Node; **they do not replace
testing on a real Roku** (SceneGraph screens, playback and subtitles can only be verified on the device).

## Disclaimer

This channel neither includes nor hosts any content: it plays what the addons you add provide. You are responsible for
having the right to access that content and for complying with the laws and the terms of the services you use. It is not
in the Roku Channel Store; it is installed by sideloading.

## TMDB

This product uses the TMDB API but is not endorsed or certified by TMDB.

## Stremio

Parche is compatible with the Stremio addon protocol, but it is an independent project: it has no relationship with
Stremio and is not affiliated with, sponsored or endorsed by Stremio. Stremio is a trademark of its respective owners.

## License

[MIT](LICENSE). Copyright (c) 2026 fsoftt.
