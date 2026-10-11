// Valida con BrighterScript (+ bslint): primero el árbol público solo (con el Plugins.brs neutro) y, si hay plugin,
// también el árbol mezclado (el plugin copiado sobre el público en out/merged). Debe dar 0 errores y 0 avisos.
// Uso: node scripts/lint.js [--no-plugins]
const path = require("path");
const { spawnSync } = require("child_process");
const { root, resolvePlugin, logPlugin, stageMerged } = require("./plugins");

function bsc(label, args, cwd) {
    console.log(`== bsc: ${label} ==`);
    const r = spawnSync("npx", ["bsc", ...args], { cwd, encoding: "utf8", shell: process.platform === "win32" });
    const output = (r.stdout || "") + (r.stderr || "");
    process.stdout.write(output);
    // bsc sale con 0 aunque haya avisos de bslint; aquí 0 errores y 0 avisos es obligatorio.
    if (r.status !== 0 || / - (warning|error) /.test(output)) {
        console.error(`
Falló la validación (${label}): hay errores o avisos.`);
        process.exit(r.status || 1);
    }
}

const plugin = resolvePlugin(process.argv.includes("--no-plugins"));
logPlugin(plugin);
bsc("árbol público", ["--project", "bsconfig.json", "--noEmit"], root);
if (plugin) {
    const dir = path.join(root, "out", "merged");
    const cfg = stageMerged(plugin, dir);
    bsc("árbol con plugin", ["--project", cfg, "--noEmit"], root);
}
console.log("\nOK: validación completa.");
