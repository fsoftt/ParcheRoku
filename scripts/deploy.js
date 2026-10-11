// Empaqueta e instala el canal en un Roku en modo desarrollador, y lo abre.
// Uso: node scripts/deploy.js [--skip-check] [--no-package] [--no-plugins]
//   Necesita las variables ROKU_IP y ROKU_PASS (contraseña de desarrollador; usuario "rokudev").
//   --skip-check  empaqueta sin validar ni correr las pruebas
//   --no-package  instala el último .zip de dist/ sin volver a empaquetar
//   --no-plugins  instala el cliente neutro (sin plugin); ver scripts/package.js
// Requiere Node 18 o superior (fetch, FormData y Blob integrados).
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const { spawnSync } = require("child_process");

const root = path.join(__dirname, "..");
const ip = process.env.ROKU_IP;
const pass = process.env.ROKU_PASS;
const user = process.env.ROKU_USER || "rokudev";

function fail(msg) {
    console.error(msg);
    process.exit(1);
}

if (!ip || !pass) {
    fail(
        "Faltan ROKU_IP y/o ROKU_PASS.\n" +
            "  PowerShell: $env:ROKU_IP='192.168.1.16'; $env:ROKU_PASS='tu_contraseña'; npm run deploy\n" +
            "  bash:       ROKU_IP=192.168.1.16 ROKU_PASS=tu_contraseña npm run deploy"
    );
}

if (!process.argv.includes("--no-package")) {
    const args = [path.join(__dirname, "package.js")];
    if (process.argv.includes("--skip-check")) args.push("--skip-check");
    if (process.argv.includes("--no-plugins")) args.push("--no-plugins");
    const r = spawnSync(process.execPath, args, { cwd: root, stdio: "inherit" });
    if (r.status !== 0) process.exit(r.status || 1);
}

const manifest = fs.readFileSync(path.join(root, "manifest"), "utf8");
const get = (k) => (manifest.match(new RegExp("^" + k + "=(.*)$", "m")) || [, "0"])[1].trim();
const version = `${get("major_version")}.${get("minor_version")}.${get("build_version")}`;
const { resolvePlugin } = require("./plugins");
const suffix = resolvePlugin(process.argv.includes("--no-plugins")) ? "" : "-public";
const zipPath = path.join(root, "dist", `ParcheRoku-${version}${suffix}.zip`);
if (!fs.existsSync(zipPath)) fail(`No existe ${path.relative(root, zipPath)}. Corre "npm run package" primero.`);

const md5 = (s) => crypto.createHash("md5").update(s).digest("hex");

// Respuesta a un reto HTTP Digest (RFC 2617, qop=auth), que es lo que pide el instalador del Roku.
function digestHeader(challenge, method, uri) {
    const field = (k) => (challenge.match(new RegExp(k + '="?([^",]+)"?', "i")) || [])[1];
    const realm = field("realm");
    const nonce = field("nonce");
    const qop = field("qop");
    const opaque = field("opaque");
    const ha1 = md5(`${user}:${realm}:${pass}`);
    const ha2 = md5(`${method}:${uri}`);
    const nc = "00000001";
    const cnonce = crypto.randomBytes(8).toString("hex");
    const response = qop ? md5(`${ha1}:${nonce}:${nc}:${cnonce}:auth:${ha2}`) : md5(`${ha1}:${nonce}:${ha2}`);
    let h = `Digest username="${user}", realm="${realm}", nonce="${nonce}", uri="${uri}", response="${response}"`;
    if (qop) h += `, qop=auth, nc=${nc}, cnonce="${cnonce}"`;
    if (opaque) h += `, opaque="${opaque}"`;
    return h;
}

function form() {
    const f = new FormData();
    f.append("mysubmit", "Install");
    f.append("archive", new Blob([fs.readFileSync(zipPath)]), path.basename(zipPath));
    return f;
}

async function main() {
    const uri = "/plugin_install";
    const url = `http://${ip}${uri}`;
    console.log(`\n== Instalando ${path.basename(zipPath)} en ${ip} ==`);

    let res;
    try {
        res = await fetch(url, { method: "POST", body: form() });
    } catch (e) {
        fail(`No se pudo conectar con ${url} (${e.cause?.code || e.message}). ¿IP correcta y modo desarrollador activo?`);
    }
    if (res.status === 401) {
        const challenge = res.headers.get("www-authenticate") || "";
        res = await fetch(url, {
            method: "POST",
            body: form(),
            headers: { Authorization: digestHeader(challenge, "POST", uri) },
        });
    }
    if (res.status === 401) fail("401 Unauthorized: contraseña de desarrollador incorrecta.");

    const html = await res.text();
    const messages = [...html.matchAll(/<font color="red">([^<]*)<\/font>|"text":"([^"]*)"/g)]
        .map((m) => (m[1] || m[2] || "").trim())
        .filter(Boolean);
    if (/Install Success|Identical to previous version/i.test(html)) {
        console.log("OK: " + (messages.join(" | ") || "Install Success"));
    } else {
        fail(`Falló la instalación (HTTP ${res.status}): ${messages.join(" | ") || "sin detalle"}\n` +
            `Mira la consola del canal: telnet ${ip} 8085`);
    }

    // Abre el canal. Si el Roku no está en "Acceso a la red: Permisivo" responde 403; no es un error de instalación.
    try {
        const l = await fetch(`http://${ip}:8060/launch/dev`, { method: "POST" });
        console.log(l.ok ? "Canal abierto." : `No se pudo abrir el canal por ECP (HTTP ${l.status}); ábrelo con el control.`);
    } catch {
        console.log("No se pudo abrir el canal por ECP; ábrelo con el control.");
    }
}

main();
