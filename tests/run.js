// Ejecuta fuera del dispositivo las pruebas de la lógica pura con el intérprete "brs" y además verifica que todas
// las claves de traducción usadas en el código existan en español, inglés y portugués.
// Uso: npm test            (públicas con el Plugins.brs neutro y, si hay plugin, públicas + plugin con el real)
//      npm test -- --no-plugins   (solo el árbol público)
// El plugin se busca como en scripts/plugins.js (PARCHE_ROKU_PLUGINS, ../ParcheRoku.Sources); sus pruebas
// son los .brs de <plugin>/tests (con su propio Main).
const fs = require("fs");
const path = require("path");
const os = require("os");
const brs = require("brs");
const { resolvePlugin, logPlugin } = require("../scripts/plugins");

const root = path.join(__dirname, "..");
const libDir = path.join(root, "components", "lib");
const stubPlugins = path.join(libDir, "Plugins.brs");
// Api.brs y Ui.brs dependen de nodos y de la red de Roku; no se cargan en las pruebas, salvo las funciones puras
// de Api.brs (VideoId, SubtitlesParse/Filter), que se extraen a un archivo temporal.
const libNames = ["Util.brs", "Strings.brs", "Language.brs", "Streams.brs", "Settings.brs", "Catalog.brs"];

function pureFromApi() {
    const src = fs.readFileSync(path.join(libDir, "Api.brs"), "utf8");
    const wanted = ["VideoId", "SubtitlesParse", "SubtitlesFilter", "SubtitlesContains"];
    let out = "";
    for (const name of wanted) {
        const m = src.match(new RegExp("function " + name + "\\([\\s\\S]*?\\nend function", "i"));
        if (!m) throw new Error("No se encontró " + name + " en Api.brs");
        out += m[0] + "\n\n";
    }
    const tmp = path.join(os.tmpdir(), "parche_api_pure.brs");
    fs.writeFileSync(tmp, out);
    return tmp;
}

// Archivos .brs de una carpeta (recursivo).
function brsFiles(dir) {
    const out = [];
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
        const p = path.join(dir, e.name);
        if (e.isDirectory()) out.push(...brsFiles(p));
        else if (e.name.endsWith(".brs")) out.push(p);
    }
    return out.sort();
}

// 1) Traducciones: las claves usadas con Tx("...") deben existir en Strings.brs o en el Plugins.brs activo.
function checkTranslations(pluginsFile, componentDirs, label) {
    let failures = 0;
    const defineSrc = fs.readFileSync(path.join(libDir, "Strings.brs"), "utf8") + "\n" + fs.readFileSync(pluginsFile, "utf8");
    const defined = new Set([...defineSrc.matchAll(/t\["([a-z0-9_]+)"\]\s*=\s*\[/g)].map((m) => m[1]));
    const used = new Set();
    for (const dir of componentDirs) {
        for (const p of brsFiles(dir)) {
            if (path.resolve(p) === path.resolve(stubPlugins) && pluginsFile !== stubPlugins) continue;
            for (const m of fs.readFileSync(p, "utf8").matchAll(/\bTx\("([a-z0-9_]+)"/g)) used.add(m[1]);
        }
    }
    // Claves construidas dinámicamente (filas de TMDB).
    for (const m of fs.readFileSync(path.join(libDir, "Catalog.brs"), "utf8").matchAll(/title: "(home_[a-z_]+)"/g)) used.add(m[1]);
    const missing = [...used].filter((k) => !defined.has(k));
    const pairs = [...defineSrc.matchAll(/t\["([a-z0-9_]+)"\]\s*=\s*\[(.*)\]\s*$/gm)];
    // Cada clave debe traer exactamente tres textos no vacíos: [español, inglés, portugués].
    const q = '"((?:[^"]|"")+)"';
    const trio = new RegExp("^" + q + "\\s*,\\s*" + q + "\\s*,\\s*" + q + "$");
    const badPairs = pairs.filter((m) => !trio.test(m[2].replace(/" \+ Chr\(10\) \+ "/g, "~"))).map((m) => m[1]);
    console.log(missing.length ? `FAIL traducciones faltantes (${label}): ` + missing.join(", ") : `PASS traducciones (${label}): ${used.size} claves usadas, todas definidas`);
    if (missing.length) failures++;
    if (badPairs.length) { console.log("FAIL tríos es/en/pt mal formados o vacíos: " + badPairs.join(", ")); failures++; }
    const unused = [...defined].filter((k) => !used.has(k));
    if (unused.length) console.log("AVISO claves sin usar: " + unused.join(", "));
    return failures;
}

// 2) Lógica BrightScript: ejecuta los archivos juntos (el último define Main).
async function runBrs(label, files) {
    console.log(`\n== ${label} ==`);
    let output = "";
    const out = { write: (s) => { output += s; return true; } };
    await brs.execute(files, { root, stdout: out, stderr: out });
    process.stdout.write(output);
    let failures = 0;
    if (/^FAIL /m.test(output)) failures++;
    if (!/RESULT:\s+0\s+fallos/.test(output)) failures++;
    return failures;
}

async function main() {
    const plugin = resolvePlugin(process.argv.includes("--no-plugins"));
    logPlugin(plugin);
    const libs = libNames.map((f) => path.join(libDir, f));
    const helpers = [path.join(__dirname, "Helpers.brs"), path.join(__dirname, "Tests.brs")];
    let failures = 0;

    // Pasada 1: árbol público con el Plugins.brs neutro.
    failures += checkTranslations(stubPlugins, [path.join(root, "components")], "público");
    failures += await runBrs("Pruebas públicas (Plugins.brs neutro)", [...libs, stubPlugins, pureFromApi(), ...helpers, path.join(__dirname, "Main.brs")]);

    // Pasada 2: con el plugin (sus pruebas traen su propio Main).
    if (plugin) {
        const pluginPlugins = path.join(plugin.dir, "components", "lib", "Plugins.brs");
        const pluginComponents = path.join(plugin.dir, "components");
        failures += checkTranslations(pluginPlugins, [path.join(root, "components"), pluginComponents], "con plugin");
        const testsDir = path.join(plugin.dir, "tests");
        if (fs.existsSync(testsDir)) {
            failures += await runBrs("Pruebas públicas + plugin (Plugins.brs real)", [...libs, pluginPlugins, pureFromApi(), ...helpers, ...brsFiles(testsDir)]);
        } else {
            console.log("AVISO: el plugin no trae tests/; solo se revisaron sus traducciones.");
        }
    }
    console.log(failures ? "\nPRUEBAS FALLIDAS" : "\nTODAS LAS PRUEBAS PASARON");
    process.exit(failures ? 1 : 0);
}
main().catch((e) => { console.error(e); process.exit(2); });
