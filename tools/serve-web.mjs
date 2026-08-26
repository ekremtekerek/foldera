// KATLA web surumunu yerel agda yayinlar -- telefondan test etmek icin.
//
//   node tools/serve-web.mjs [klasor] [port]
//
// Godot 4.7 web sablonu is parcacigi (thread) destegiyle derlendigi icin
// tarayicinin SharedArrayBuffer'a izin vermesi gerekiyor. Bu da yalnizca
// "cross-origin isolation" basliklariyla mumkun -- basit bir dosya sunucusu
// veya file:// ile ACILMAZ, bos ekran gelir. Asagidaki iki baslik tam olarak
// bunun icin.

import { createServer } from "node:http";
import { readFile, stat } from "node:fs/promises";
import { join, extname, normalize } from "node:path";
import { networkInterfaces } from "node:os";

const ROOT = normalize(process.argv[2] ?? "D:/Temp/katla-web");
const PORT = Number(process.argv[3] ?? 8080);

const TYPES = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript",
  ".mjs": "text/javascript",
  ".wasm": "application/wasm",
  ".pck": "application/octet-stream",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".json": "application/json",
  ".webmanifest": "application/manifest+json",
};

const server = createServer(async (req, res) => {
  const setHeaders = () => {
    // SharedArrayBuffer icin sart olan ikili
    res.setHeader("Cross-Origin-Opener-Policy", "same-origin");
    res.setHeader("Cross-Origin-Embedder-Policy", "require-corp");
    res.setHeader("Cache-Control", "no-store");
  };

  try {
    const url = decodeURIComponent((req.url ?? "/").split("?")[0]);
    const rel = url === "/" ? "index.html" : url.replace(/^\/+/, "");
    const file = normalize(join(ROOT, rel));
    if (!file.startsWith(ROOT)) {
      res.writeHead(403).end("forbidden");
      return;
    }
    const info = await stat(file);
    const body = await readFile(file);
    setHeaders();
    res.writeHead(200, {
      "Content-Type": TYPES[extname(file)] ?? "application/octet-stream",
      "Content-Length": info.size,
    });
    res.end(body);
  } catch {
    setHeaders();
    res.writeHead(404).end("not found");
  }
});

server.listen(PORT, "0.0.0.0", () => {
  const lan = Object.values(networkInterfaces())
    .flat()
    .filter((n) => n && n.family === "IPv4" && !n.internal)
    .map((n) => n.address);
  console.log(`KATLA web  ->  ${ROOT}`);
  console.log(`  bilgisayar : http://localhost:${PORT}/`);
  for (const ip of lan) console.log(`  telefon    : http://${ip}:${PORT}/`);
  console.log("\n  (telefon ayni Wi-Fi agina bagli olmali; durdurmak icin Ctrl+C)");
});
