const readline = require('readline');

/**
 * Reads the request stream line-by-line using an async generator
 */
async function* lineStream(req) {
    const rl = readline.createInterface({
        input: req,
        terminal: false
    });

    for await (const line of rl) {
        if (line.trim()) {
            yield line;
        }
    }
}

/**
 * Logs progress to console
 */
function progress(count, startTime, contentLength, bytesRead, every = 1000) {
    if (count % every !== 0) return;

    const elapsed = (Date.now() - startTime) / 1000;
    const rate = elapsed > 0 ? (count / elapsed).toFixed(0) : 0;
    let msg = `Inserted ${count} docs (${rate} docs/sec)`;

    if (contentLength && bytesRead) {
        const pct = bytesRead / contentLength;
        const remaining = pct > 0 ? (elapsed / pct - elapsed).toFixed(0) : 0;
        msg += ` | ${(pct * 100).toFixed(1)}% done, ~${remaining}s remaining`;
    }

    console.log(msg);
}

module.exports = { lineStream, progress };
