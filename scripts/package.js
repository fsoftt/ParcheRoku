// Empaqueta el canal en un .zip listo para instalar (sideload) en un Roku en modo desarrollador.
// Uso: node scripts/package.js [--skip-check] [--no-plugins]
//   Antes de empaquetar valida con BrighterScript (0 errores) y corre las pruebas; --skip-check lo omite.
//   Si hay un plugin (PARCHE_ROKU_PLUGINS, ../ParcheRoku.Sources; ver scripts/plugins.js) se mezcla en el
//   zip: sus components/ reemplazan o agregan archivos. --no-plugins lo ignora y empaqueta el cliente neutro.
// Resultado: dist/ParcheRoku-<version>.zip, o dist/ParcheRoku-<version>-public.zip sin plugin
//   (manifest en la raíz del zip, como exige Roku).
// No necesita dependencias para comprimir: escribe el zip con el módulo zlib de Node.
const fs = require("fs");
const path = require("path");
const zlib = require("zlib");
const { spawnSync } = require("child_process");

const { root, resolvePlugin, logPlugin, collectFiles } = require("./plugins");

const noPlugins = process.argv.includes("--no-plugins");
const plugin = resolvePlugin(noPlugins);
logPlugin(plugin);

function run(cmd, args) {
    const r = spawnSync(cmd, args, { cwd: root, stdio: "inherit", shell: process.platform === "win32" });
    if (r.status !== 0) {
        console.error("\nFalló: " + cmd + " " + args.join(" "));
        process.exit(r.status || 1);
    }
}

if (!process.argv.includes("--skip-check")) {
    const extra = noPlugins ? ["--no-plugins"] : [];
    console.log("== Validando con BrighterScript ==");
    run("node", ["scripts/lint.js", ...extra]);
    console.log("== Pruebas ==");
    run("node", ["tests/run.js", ...extra]);
}

const crcTable = (() => {
    const t = new Uint32Array(256);
    for (let n = 0; n < 256; n++) {
        let c = n;
        for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
        t[n] = c >>> 0;
    }
    return t;
})();
function crc32(buf) {
    let c = 0xffffffff;
    for (let i = 0; i < buf.length; i++) c = crcTable[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
    return (c ^ 0xffffffff) >>> 0;
}

function zip(entries) {
    const locals = [];
    const centrals = [];
    let offset = 0;
    const stamp = new Date();
    const dosTime = (stamp.getHours() << 11) | (stamp.getMinutes() << 5) | (stamp.getSeconds() >> 1);
    const dosDate = ((stamp.getFullYear() - 1980) << 9) | ((stamp.getMonth() + 1) << 5) | stamp.getDate();
    for (const { name, data } of entries) {
        const nameBuf = Buffer.from(name, "utf8");
        const deflated = zlib.deflateRawSync(data, { level: 9 });
        const useDeflate = deflated.length < data.length;
        const body = useDeflate ? deflated : data;
        const method = useDeflate ? 8 : 0;
        const crc = crc32(data);

        const lh = Buffer.alloc(30);
        lh.writeUInt32LE(0x04034b50, 0);
        lh.writeUInt16LE(20, 4);
        lh.writeUInt16LE(0x0800, 6); // nombres en UTF-8
        lh.writeUInt16LE(method, 8);
        lh.writeUInt16LE(dosTime, 10);
        lh.writeUInt16LE(dosDate, 12);
        lh.writeUInt32LE(crc, 14);
        lh.writeUInt32LE(body.length, 18);
        lh.writeUInt32LE(data.length, 22);
        lh.writeUInt16LE(nameBuf.length, 26);
        lh.writeUInt16LE(0, 28);
        locals.push(lh, nameBuf, body);

        const ch = Buffer.alloc(46);
        ch.writeUInt32LE(0x02014b50, 0);
        ch.writeUInt16LE(20, 4);
        ch.writeUInt16LE(20, 6);
        ch.writeUInt16LE(0x0800, 8);
        ch.writeUInt16LE(method, 10);
        ch.writeUInt16LE(dosTime, 12);
        ch.writeUInt16LE(dosDate, 14);
        ch.writeUInt32LE(crc, 16);
        ch.writeUInt32LE(body.length, 20);
        ch.writeUInt32LE(data.length, 24);
        ch.writeUInt16LE(nameBuf.length, 28);
        ch.writeUInt32LE(offset, 42);
        centrals.push(ch, nameBuf);
        offset += lh.length + nameBuf.length + body.length;
    }
    const centralBuf = Buffer.concat(centrals);
    const end = Buffer.alloc(22);
    end.writeUInt32LE(0x06054b50, 0);
    end.writeUInt16LE(entries.length, 8);
    end.writeUInt16LE(entries.length, 10);
    end.writeUInt32LE(centralBuf.length, 12);
    end.writeUInt32LE(offset, 16);
    return Buffer.concat([...locals, centralBuf, end]);
}

const manifest = fs.readFileSync(path.join(root, "manifest"), "utf8");
const get = (k) => (manifest.match(new RegExp("^" + k + "=(.*)$", "m")) || [, "0"])[1].trim();
const version = `${get("major_version")}.${get("minor_version")}.${get("build_version")}`;

const files = collectFiles(plugin);
const entries = [...files].map(([name, abs]) => ({ name, data: fs.readFileSync(abs) }));
const dist = path.join(root, "dist");
fs.mkdirSync(dist, { recursive: true });
const outFile = path.join(dist, `ParcheRoku-${version}${plugin ? "" : "-public"}.zip`);
fs.writeFileSync(outFile, zip(entries));
console.log(`\nOK: ${files.size} archivos -> ${path.relative(root, outFile)} (${(fs.statSync(outFile).size / 1024).toFixed(1)} KB)`);
console.log("Instálalo en http://IP_DEL_ROKU (modo desarrollador) subiendo ese .zip.");
