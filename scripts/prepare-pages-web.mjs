#!/usr/bin/env node

import { copyFile, readdir, readFile, rm, stat, writeFile } from "node:fs/promises";
import path from "node:path";
import { gzipSync } from "node:zlib";

const outputDirectory = path.resolve(process.argv[2] ?? "dist/web");
const pagesFileLimit = 25 * 1024 * 1024;
const wasmPartSize = 20 * 1024 * 1024;
const loaderFile = "wasm-loader.js";
const loaderSource = new URL("./wasm-loader.js", import.meta.url);



const entries = await readdir(outputDirectory, { withFileTypes: true });
const wasmFiles = entries.filter((entry) => entry.isFile() && entry.name.endsWith(".wasm"));

if (wasmFiles.length !== 1) {
  throw new Error(`Expected one .wasm file in ${outputDirectory}, found ${wasmFiles.length}.`);
}

const wasmPath = path.join(outputDirectory, wasmFiles[0].name);
const wasm = await readFile(wasmPath);
const partCount = Math.ceil(wasm.byteLength / wasmPartSize);

for (let index = 0; index < partCount; index += 1) {
  const part = wasm.subarray(index * wasmPartSize, (index + 1) * wasmPartSize);
  await writeFile(`${wasmPath}.part${index}`, part);
  await writeFile(`${wasmPath}.part${index}.gz`, gzipSync(part, { level: 9 }));
}
await rm(wasmPath);
await copyFile(loaderSource, path.join(outputDirectory, loaderFile));

const htmlPath = path.join(outputDirectory, "index.html");
const html = await readFile(htmlPath, "utf8");
const loaderTag = `<script>window.GODOT_WASM_PARTS=${JSON.stringify({
  [wasmFiles[0].name]: partCount,
})};window.GODOT_WASM_GZIP=true;</script>\n<script src="${loaderFile}"></script>`;

if (!html.includes("<head>")) {
  throw new Error("The exported index.html does not contain a <head> element.");
}

await writeFile(htmlPath, html.replace("<head>", `<head>\n${loaderTag}`).replace('<html lang="en">', '<html lang="ja">'));

for (const entry of await readdir(outputDirectory, { withFileTypes: true })) {
  if (entry.isFile()) {
    const file = path.join(outputDirectory, entry.name);
    const { size } = await stat(file);
    if (size >= pagesFileLimit) {
      throw new Error(`${entry.name} is too large for Cloudflare Pages (${size} bytes).`);
    }
  }
}

console.log(`Split ${wasmFiles[0].name} into ${partCount} WebAssembly parts for Cloudflare Pages.`);
