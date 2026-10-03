(() => {
  const nativeFetch = window.fetch.bind(window);
  const wasmParts = window.GODOT_WASM_PARTS ?? {};
  const useGzip = window.GODOT_WASM_GZIP && typeof DecompressionStream !== "undefined";

  window.fetch = async (resource, options) => {
    const requestedUrl = new URL(
      resource instanceof Request ? resource.url : resource,
      document.baseURI,
    );
    const partCount = wasmParts[requestedUrl.pathname.split("/").pop()];

    if (!partCount) {
      return nativeFetch(resource, options);
    }

    const partResponses = await Promise.all(
      Array.from({ length: partCount }, async (_, index) => {
        const partUrl = new URL(requestedUrl);
        partUrl.pathname += `.part${index}`;
        if (useGzip) partUrl.pathname += ".gz";
        const request = resource instanceof Request ? new Request(partUrl, resource) : partUrl;
        const response = await nativeFetch(request, options);
        if (!response.ok) {
          throw new Error(`Could not load Godot WebAssembly part ${index + 1}/${partCount}.`);
        }
        // A host may already decode Content-Encoding: gzip. Otherwise decode
        // the .gz payload ourselves, including on a plain static local server.
        if (useGzip && response.headers.get("Content-Encoding") !== "gzip") {
          return new Response(response.body.pipeThrough(new DecompressionStream("gzip")));
        }
        return response;
      }),
    );

    // Fetch parts in parallel, but deliver their bytes in file order. This lets
    // Godot track download progress and compile while the bodies are arriving,
    // without copying the whole runtime into ArrayBuffers and a Blob first.
    const readers = partResponses.map((response) => response.body.getReader());
    let partIndex = 0;
    const stream = new ReadableStream({
      async pull(controller) {
        try {
          while (partIndex < readers.length) {
            const { done, value } = await readers[partIndex].read();
            if (!done) {
              controller.enqueue(value);
              return;
            }
            partIndex += 1;
          }
          controller.close();
        } catch (error) {
          controller.error(error);
          await Promise.allSettled(readers.map((reader) => reader.cancel(error)));
        }
      },
      async cancel(reason) {
        await Promise.allSettled(readers.map((reader) => reader.cancel(reason)));
      },
    });
    return new Response(stream, {
      headers: { "Content-Type": "application/wasm" },
    });
  };
})();
