// Localiza el plugin (si hay uno) y arma el árbol "mezclado" para validar o empaquetar.
// Un plugin es una carpeta con components/ (su components/lib/Plugins.brs reemplaza al neutro del repo público) y,
// opcionalmente, tests/ con sus pruebas (el README del plugin explica el formato).
// Orden de búsqueda: variable PARCHE_ROKU_PLUGINS, luego ../ParcheRoku.Sources.
// Todos los scripts aceptan --no-plugins para ignorarlo y trabajar solo con el árbol público.
const fs = require("fs");
const path = require("path");

const root = path.join(__dirname, "..");

function isPluginDir(dir) {
    return fs.existsSync(path.join(dir, "components", "lib", "Plugins.brs"));
}

// Devuelve { dir, origin } o null si no hay plugin (o si noPlugins). Si PARCHE_ROKU_PLUGINS apunta a algo inválido, falla.
function resolvePlugin(noPlugins) {
    if (noPlugins) return null;
    const env = process.env.PARCHE_ROKU_PLUGINS;
    if (env) {
        const dir = path.resolve(env);
        if (!isPluginDir(dir)) {
            console.error(`PARCHE_ROKU_PLUGINS=${env} no es un plugin válido (falta components/lib/Plugins.brs).`);
            process.exit(1);
        }
        return { dir, origin: "PARCHE_ROKU_PLUGINS" };
    }
    const candidates = [
        { dir: path.resolve(root, "..", "ParcheRoku.Sources"), origin: "../ParcheRoku.Sources" },
    ];
    for (const c of candidates) if (isPluginDir(c.dir)) return c;
    return null;
}

function logPlugin(plugin) {
    if (plugin) console.log(`Plugin: ${plugin.dir} (${plugin.origin})`);
    else console.log("Plugin: ninguno (cliente neutro de addons)");
}

// Lista recursiva de archivos (rutas relativas con "/"), en orden estable.
function walk(base, rel) {
    const abs = path.join(base, rel);
    const st = fs.statSync(abs);
    if (st.isFile()) return [rel.split(path.sep).join("/")];
    return fs.readdirSync(abs).sort().flatMap((n) => walk(base, path.join(rel, n)));
}

// Archivos del canal: { "ruta/en/el/zip": "ruta absoluta" }. Los de plugin/components reemplazan o agregan.
function collectFiles(plugin) {
    const files = new Map();
    for (const top of ["manifest", "source", "components", "images"]) {
        for (const f of walk(root, top)) files.set(f, path.join(root, f));
    }
    if (plugin) {
        for (const f of walk(plugin.dir, "components")) files.set(f, path.join(plugin.dir, f));
    }
    for (const f of [...files.keys()]) {
        if (f.endsWith(".map") || f.includes("/.")) files.delete(f);
    }
    return files;
}

// Copia el árbol mezclado a dir (lo recrea) y deja un bsconfig.json para validarlo con bsc.
function stageMerged(plugin, dir) {
    fs.rmSync(dir, { recursive: true, force: true });
    for (const [name, abs] of collectFiles(plugin)) {
        const dest = path.join(dir, name);
        fs.mkdirSync(path.dirname(dest), { recursive: true });
        fs.copyFileSync(abs, dest);
    }
    const cfg = JSON.parse(fs.readFileSync(path.join(root, "bsconfig.json"), "utf8"));
    cfg.rootDir = ".";
    cfg.stagingDir = "staging";
    // El plugin de lint se resuelve desde este repo, no desde la carpeta temporal.
    cfg.plugins = (cfg.plugins || []).map((p) => {
        try {
            return require.resolve(p, { paths: [root] });
        } catch (e) {
            return p;
        }
    });
    const cfgPath = path.join(dir, "bsconfig.json");
    fs.writeFileSync(cfgPath, JSON.stringify(cfg, null, 2));
    return cfgPath;
}

module.exports = { root, resolvePlugin, logPlugin, collectFiles, stageMerged };
