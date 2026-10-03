import { readdir, stat } from "node:fs/promises";
import path from "node:path";

const MEBIBYTE = 1024 * 1024;
const MAX_FILE_SIZE = 25 * MEBIBYTE;
const root = path.resolve(process.argv[2] ?? "dist/web");
const oversizedFiles = [];

async function inspect(directory) {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const filePath = path.join(directory, entry.name);

    if (entry.isDirectory()) {
      await inspect(filePath);
    } else if (entry.isFile()) {
      const { size } = await stat(filePath);
      if (size >= MAX_FILE_SIZE) {
        oversizedFiles.push({ filePath, size });
      }
    }
  }
}

await inspect(root);

if (oversizedFiles.length > 0) {
  console.error("Cloudflare Pages rejects these files (25 MiB or larger):");
  for (const { filePath, size } of oversizedFiles) {
    console.error(`- ${path.relative(root, filePath)} (${(size / MEBIBYTE).toFixed(2)} MiB)`);
  }
  process.exitCode = 1;
} else {
  console.log(`All generated files are smaller than 25 MiB: ${root}`);
}
