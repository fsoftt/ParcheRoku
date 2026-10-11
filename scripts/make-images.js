// Genera los PNG de marcador de posición del canal (iconos, pantalla de carga, degradados) sin dependencias.
// Uso: node scripts/make-images.js
const fs = require("fs");
const path = require("path");
const zlib = require("zlib");

const OUT = path.join(__dirname, "..", "images");
const BG = [0x0b, 0x0b, 0x14];
const PINK = [0xec, 0x48, 0x99];
const PURPLE = [0x8b, 0x5c, 0xf6];

// ---------- codificador PNG (RGBA 8 bits) ----------
function crc32(buf) {
    return zlib.crc32 ? zlib.crc32(buf) : slowCrc(buf);
}
function slowCrc(buf) {
    let c, crc = 0xffffffff;
    for (let n = 0; n < buf.length; n++) {
        c = (crc ^ buf[n]) & 0xff;
        for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
        crc = (crc >>> 8) ^ c;
    }
    return (crc ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
    const len = Buffer.alloc(4);
    len.writeUInt32BE(data.length);
    const body = Buffer.concat([Buffer.from(type, "ascii"), data]);
    const crc = Buffer.alloc(4);
    crc.writeUInt32BE(crc32(body) >>> 0);
    return Buffer.concat([len, body, crc]);
}
function encodePng(w, h, rgba) {
    const raw = Buffer.alloc((w * 4 + 1) * h);
    for (let y = 0; y < h; y++) {
        raw[y * (w * 4 + 1)] = 0;
        rgba.copy(raw, y * (w * 4 + 1) + 1, y * w * 4, (y + 1) * w * 4);
    }
    const ihdr = Buffer.alloc(13);
    ihdr.writeUInt32BE(w, 0);
    ihdr.writeUInt32BE(h, 4);
    ihdr[8] = 8; ihdr[9] = 6; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
    return Buffer.concat([
        Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
        chunk("IHDR", ihdr),
        chunk("IDAT", zlib.deflateSync(raw, { level: 9 })),
        chunk("IEND", Buffer.alloc(0)),
    ]);
}

// ---------- lienzo ----------
class Canvas {
    constructor(w, h) { this.w = w; this.h = h; this.px = Buffer.alloc(w * h * 4); }
    set(x, y, [r, g, b], a = 255) {
        if (x < 0 || y < 0 || x >= this.w || y >= this.h) return;
        const i = (y * this.w + x) * 4;
        const sa = a / 255, da = this.px[i + 3] / 255;
        const oa = sa + da * (1 - sa);
        if (oa <= 0) return;
        this.px[i] = Math.round((r * sa + this.px[i] * da * (1 - sa)) / oa);
        this.px[i + 1] = Math.round((g * sa + this.px[i + 1] * da * (1 - sa)) / oa);
        this.px[i + 2] = Math.round((b * sa + this.px[i + 2] * da * (1 - sa)) / oa);
        this.px[i + 3] = Math.round(oa * 255);
    }
    fill(color, a = 255) { for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w; x++) this.set(x, y, color, a); }
    // Degradado diagonal rosa -> morado en un rectángulo redondeado.
    gradientRect(x0, y0, w, h, radius) {
        for (let y = y0; y < y0 + h; y++) {
            for (let x = x0; x < x0 + w; x++) {
                const dx = Math.max(x0 + radius - x, 0, x - (x0 + w - 1 - radius));
                const dy = Math.max(y0 + radius - y, 0, y - (y0 + h - 1 - radius));
                if (dx * dx + dy * dy > radius * radius) continue;
                const t = ((x - x0) / w + (y - y0) / h) / 2;
                this.set(x, y, mix(PINK, PURPLE, t));
            }
        }
    }
    png() { return encodePng(this.w, this.h, this.px); }
}
const mix = (a, b, t) => [0, 1, 2].map((i) => Math.round(a[i] + (b[i] - a[i]) * t));

// ---------- fuente de píxeles 5x7 para "PARCHE" ----------
const GLYPHS = {
    P: ["1111.", "1...1", "1...1", "1111.", "1....", "1....", "1...."],
    A: [".111.", "1...1", "1...1", "11111", "1...1", "1...1", "1...1"],
    R: ["1111.", "1...1", "1...1", "1111.", "1.1..", "1..1.", "1...1"],
    C: [".1111", "1....", "1....", "1....", "1....", "1....", ".1111"],
    H: ["1...1", "1...1", "1...1", "11111", "1...1", "1...1", "1...1"],
    E: ["11111", "1....", "1....", "1111.", "1....", "1....", "11111"],
};
function textWidth(text, s) { return text.length * 6 * s - s; }
// Dibuja texto; fillFn(x, y) devuelve el color de cada píxel.
function drawText(cv, text, x0, y0, s, fillFn) {
    [...text].forEach((ch, i) => {
        GLYPHS[ch].forEach((row, gy) => {
            [...row].forEach((c, gx) => {
                if (c !== "1") return;
                for (let yy = 0; yy < s; yy++) for (let xx = 0; xx < s; xx++) {
                    const px = x0 + i * 6 * s + gx * s + xx, py = y0 + gy * s + yy;
                    cv.set(px, py, fillFn(px, py));
                }
            });
        });
    });
}

function write(name, cv) {
    fs.writeFileSync(path.join(OUT, name), cv.png());
    console.log("  " + name + " (" + cv.w + "x" + cv.h + ")");
}

fs.mkdirSync(OUT, { recursive: true });
console.log("Generando imágenes en " + OUT);

// Icono del menú de Roku: tarjeta degradada con "PARCHE" en blanco.
function icon(w, h, name) {
    const cv = new Canvas(w, h);
    cv.gradientRect(0, 0, w, h, Math.round(h * 0.08));
    const s = Math.max(2, Math.floor((w * 0.78) / textWidth("PARCHE", 1)));
    drawText(cv, "PARCHE", Math.round((w - textWidth("PARCHE", s)) / 2), Math.round((h - 7 * s) / 2), s, () => [255, 255, 255]);
    write(name, cv);
}
icon(290, 218, "icon_focus_hd.png");
icon(246, 140, "icon_focus_sd.png");

// Pantalla de carga: fondo oscuro con la palabra en degradado.
function splash(w, h, name) {
    const cv = new Canvas(w, h);
    cv.fill(BG);
    const s = Math.floor((w * 0.42) / textWidth("PARCHE", 1));
    const tw = textWidth("PARCHE", s), x0 = Math.round((w - tw) / 2), y0 = Math.round((h - 7 * s) / 2);
    drawText(cv, "PARCHE", x0, y0, s, (x) => mix(PINK, PURPLE, (x - x0) / tw));
    write(name, cv);
}
splash(1280, 720, "splash_hd.png");
splash(1920, 1080, "splash_fhd.png");

// Degradados para el héroe de la portada (transparente -> color de fondo).
function gradient(w, h, vertical, name) {
    const cv = new Canvas(w, h);
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
        const t = vertical ? y / (h - 1) : 1 - x / (w - 1);
        cv.set(x, y, BG, Math.round(255 * Math.pow(t, 1.4)));
    }
    write(name, cv);
}
gradient(4, 256, true, "grad_bottom.png");
gradient(256, 4, false, "grad_left.png");

// Imagen transparente (anula el recuadro de foco por defecto de las listas).
write("transparent.png", new Canvas(4, 4));
