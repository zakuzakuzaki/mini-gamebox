import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import vm from "node:vm";
import { gzipSync } from "node:zlib";

const loader = await readFile(new URL("./wasm-loader.js", import.meta.url), "utf8");
const parts = [new Uint8Array([0x00, 0x61, 0x73, 0x6d]), new Uint8Array([0x01, 0x00, 0x00, 0x00])];

function setup(fetch, wasmParts = { "index.wasm": parts.length }, gzip = false, decoder = DecompressionStream) {
  const context = {
    DecompressionStream: decoder ?? undefined,
    URL,
    Request,
    Response,
    Headers,
    Blob,
    ReadableStream,
    document: { baseURI: "https://example.com/game/" },
    window: { GODOT_WASM_PARTS: wasmParts, GODOT_WASM_GZIP: gzip, fetch },
  };
  vm.runInNewContext(loader, context);
  return context.window.fetch;
}

async function checkAssembly(resource, options) {
  const requests = [];
  const fetch = setup(async (request, actualOptions) => {
    requests.push({ request, options: actualOptions });
    const url = new URL(request instanceof Request ? request.url : request);
    const index = Number(url.pathname.match(/\.part(\d+)$/)[1]);
    // Complete out of order: assembly must still preserve part order.
    if (index === 0) await new Promise((resolve) => setTimeout(resolve, 10));
    return new Response(parts[index]);
  });
  const response = await fetch(resource, options);
  assert.deepEqual(
    new Uint8Array(await response.arrayBuffer()),
    new Uint8Array(parts.flatMap((part) => [...part])),
  );
  assert.equal(response.headers.get("Content-Type"), "application/wasm");
  const originalUrl = new URL(
    resource instanceof Request ? resource.url : resource,
    "https://example.com/game/",
  );
  assert.deepEqual(
    requests.map(({ request }) => (request instanceof Request ? request.url : request.toString())),
    parts.map((_, index) => {
      const url = new URL(originalUrl);
      url.pathname += `.part${index}`;
      return url.toString();
    }),
  );
  for (const entry of requests) {
    assert.equal(entry.options, options, "fetch options are forwarded unchanged");
    if (resource instanceof Request) {
      assert.ok(entry.request instanceof Request);
      assert.equal(entry.request.method, resource.method);
      assert.equal(entry.request.credentials, resource.credentials);
      assert.equal(entry.request.cache, resource.cache);
      assert.deepEqual([...entry.request.headers], [...resource.headers]);
    }
  }
  return requests;
}

await checkAssembly("index.wasm");
await checkAssembly(new URL("https://example.com/game/index.wasm?version=2"));
const abort = new AbortController();
const request = new Request("https://example.com/game/index.wasm?version=3", {
  headers: { "X-Test": "preserved" },
  credentials: "include",
  cache: "no-cache",
  signal: abort.signal,
});
const requests = await checkAssembly(request, { cache: "reload" });
abort.abort();
assert.ok(
  requests.every((entry) => entry.request.signal.aborted),
  "request cancellation propagates",
);

for (const resource of ["index.pck", new Request("https://example.com/game/index.pck")]) {
  const options = { headers: { "X-Test": "passthrough" } };
  const response = new Response("ordinary file");
  let calls = 0;
  const fetch = setup(async (actualResource, actualOptions) => {
    calls += 1;
    assert.equal(actualResource, resource);
    assert.equal(actualOptions, options);
    return response;
  });
  assert.equal(await fetch(resource, options), response);
  assert.equal(calls, 1);
}

const unsplit = new Response("unsplit wasm");
assert.equal(await setup(async () => unsplit, {})("index.wasm"), unsplit);

for (const failedPart of [0, 1]) {
  const fetch = setup(async (resource) => {
    const index = Number(resource.pathname.match(/\.part(\d+)$/)[1]);
    return index === failedPart ? new Response(null, { status: 404 }) : new Response(parts[index]);
  });
  await assert.rejects(fetch("index.wasm"), {
    message: `Could not load Godot WebAssembly part ${failedPart + 1}/${parts.length}.`,
  });
}
const networkError = new Error("network unavailable");
await assert.rejects(
  setup(async () => {
    throw networkError;
  })("index.wasm"),
  (error) => error === networkError,
);

// The first bytes must be available while a later part is still downloading.
let finishLastPart;
const streamingFetch = setup(async (resource) => {
  const index = Number(resource.pathname.match(/\.part(\d+)$/)[1]);
  if (index === 0) return new Response(parts[0]);
  return new Response(
    new ReadableStream({
      start(controller) {
        finishLastPart = controller;
      },
    }),
  );
});
const streamedResponse = await streamingFetch("index.wasm");
const reader = streamedResponse.body.getReader();
assert.deepEqual((await reader.read()).value, parts[0]);
finishLastPart.enqueue(parts[1]);
finishLastPart.close();
assert.deepEqual((await reader.read()).value, parts[1]);
assert.equal((await reader.read()).done, true);

// Canceling the combined response releases every in-flight part body.
const canceled = [];
const cancelFetch = setup(
  async (resource) =>
    new Response(
      new ReadableStream({
        cancel() {
          canceled.push(resource.pathname);
        },
      }),
    ),
);
const cancelResponse = await cancelFetch("index.wasm");
await cancelResponse.body.cancel("navigation canceled");
assert.equal(canceled.length, parts.length);

const bodyError = new Error("download interrupted");
const interruptedFetch = setup(
  async () =>
    new Response(
      new ReadableStream({
        start(controller) {
          controller.error(bodyError);
        },
      }),
    ),
);
await assert.rejects(
  (await interruptedFetch("index.wasm")).arrayBuffer(),
  (error) => error === bodyError,
);

console.log("Wasm loader regression tests passed.");

for (const decodedByHost of [false, true]) {
  const fetch = setup(async (resource) => {
    assert.ok(resource.pathname.endsWith(".gz"));
    const index = Number(resource.pathname.match(/\.part(\d+)\.gz$/)[1]);
    return decodedByHost
      ? new Response(parts[index], { headers: { "Content-Encoding": "gzip" } })
      : new Response(gzipSync(parts[index]));
  }, undefined, true);
  assert.deepEqual(new Uint8Array(await (await fetch("index.wasm")).arrayBuffer()),
    new Uint8Array(parts.flatMap((part) => [...part])));
}
const legacyFetch = setup(async (resource) => {
  assert.ok(!resource.pathname.endsWith(".gz"));
  return new Response(parts[Number(resource.pathname.match(/\.part(\d+)$/)[1])]);
}, undefined, true, null);
await (await legacyFetch("index.wasm")).arrayBuffer();
const corruptFetch = setup(async () => new Response("invalid gzip"), undefined, true);
await assert.rejects((await corruptFetch("index.wasm")).arrayBuffer());
console.log("Compressed Wasm loading and legacy fallback tests passed.");
