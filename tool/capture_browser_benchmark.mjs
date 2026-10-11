// Run against a locally built benchmark, never a deployed game.
// Usage: node tool/capture_browser_benchmark.mjs <web-root> <output.json> [TERRAIN|GAMEPLAY] [query]
import { createServer } from "node:http";
import { readFile, writeFile, mkdtemp, mkdir } from "node:fs/promises";
import { resolve, dirname, extname, sep } from "node:path";
import { spawn } from "node:child_process";

const root = resolve(process.argv[2] ?? "build/terrain-benchmark-web");
const output = resolve(process.argv[3] ?? ".tmp/browser-performance.json");
const prefix = process.argv[4] ?? "TERRAIN";
if (!["TERRAIN", "GAMEPLAY"].includes(prefix)) {
  throw new Error("Expected TERRAIN or GAMEPLAY as the benchmark prefix.");
}
await readFile(resolve(root, "index.html"));
await mkdir(dirname(output), { recursive: true });
await mkdir(resolve(".tmp"), { recursive: true });
const profile = await mkdtemp(resolve(".tmp/benchmark-chrome-"));
const browserExecutable = process.env.CHROME_EXECUTABLE ??
  (process.platform === "win32"
    ? "C:/Program Files/Google/Chrome/Application/chrome.exe"
    : "google-chrome");
const mimeTypes = {
  ".html": "text/html",
  ".js": "application/javascript",
  ".wasm": "application/wasm",
  ".json": "application/json",
  ".png": "image/png",
  ".ttf": "font/ttf",
};
const server = createServer(async (request, response) => {
  try {
    const name = decodeURIComponent(new URL(request.url, "http://localhost").pathname);
    const file = resolve(root, "." + (name === "/" ? "/index.html" : name));
    if (!file.startsWith(root + sep)) {
      response.writeHead(403).end();
      return;
    }
    const data = await readFile(file);
    response.writeHead(200, {
      "content-type": mimeTypes[extname(file)] ?? "application/octet-stream",
      "cache-control": "no-store",
    }).end(data);
  } catch {
    response.writeHead(404).end();
  }
});
await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
const query = new URLSearchParams(process.argv[5] ?? "");
const url = "http://127.0.0.1:" + server.address().port + "/?" + query;
const browser = spawn(browserExecutable, [
  "--headless=new",
  "--no-first-run",
  "--no-default-browser-check",
  "--remote-debugging-port=0",
  "--user-data-dir=" + profile,
  "--window-size=1440,900",
  "--disable-background-timer-throttling",
  "--disable-renderer-backgrounding",
  "about:blank",
], { windowsHide: true, stdio: "ignore" });
let launchError;
browser.on("error", (error) => { launchError = error; });
const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// Runs in the benchmark page. Keep all samples local until measurement ends.
function instrument(prefix) {
  const evidence = { active: false, gaps: [], longTasks: [], periods: [] };
  window.__terrainEvidence = evidence;
  let previous;
  function frame(now) {
    if (evidence.active && previous !== undefined) evidence.gaps.push(now - previous);
    previous = evidence.active ? now : undefined;
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
  new PerformanceObserver((list) => {
    for (const entry of list.getEntries()) {
      if (evidence.periods.some((period) =>
        entry.startTime >= period.start &&
        (period.end === null || entry.startTime < period.end))) {
        evidence.longTasks.push({ start: entry.startTime, duration: entry.duration });
      }
    }
  }).observe({ type: "longtask", buffered: true });
  const log = console.log;
  console.log = function (...args) {
    const text = args.join(" ");
    if (text.startsWith(prefix + "_BENCHMARK_ACTIVE")) {
      evidence.active = true;
      previous = undefined;
      evidence.periods.push({ label: text, start: performance.now(), end: null });
    }
    if (text.startsWith(prefix + "_BENCHMARK_SUMMARY") ||
        text.startsWith(prefix + "_BENCHMARK_ROW")) {
      evidence.active = false;
      const period = evidence.periods.at(-1);
      if (period && period.end === null) period.end = performance.now();
    }
    return log.apply(console, args);
  };
}

let socket;
try {
  let port;
  for (let attempt = 0; attempt < 120; attempt++) {
    if (launchError) throw launchError;
    try {
      port = Number((await readFile(profile + "/DevToolsActivePort", "utf8")).split("\n")[0]);
      break;
    } catch {
      await delay(250);
    }
  }
  if (!port) throw new Error("Chrome did not expose its local debugging port.");
  const targets = await (await fetch("http://127.0.0.1:" + port + "/json")).json();
  const target = targets.find((item) => item.type === "page");
  if (!target) throw new Error("Chrome did not create a benchmark page.");
  socket = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => {
    socket.addEventListener("open", resolve, { once: true });
    socket.addEventListener("error", reject, { once: true });
  });
  let next = 0;
  const pending = new Map();
  const messages = [];
  const rows = [];
  let summary;
  let failure;
  socket.addEventListener("message", (event) => {
    const message = JSON.parse(event.data);
    if (message.id) {
      const item = pending.get(message.id);
      if (!item) return;
      pending.delete(message.id);
      clearTimeout(item.timer);
      if (message.error) item.reject(message.error);
      else item.resolve(message.result);
      return;
    }
    if (message.method === "Runtime.exceptionThrown") messages.push(message.params);
    if (message.method !== "Runtime.consoleAPICalled") return;
    const line = message.params.args.map((arg) => arg.value ?? arg.description ?? "").join(" ");
    if (line.startsWith(prefix + "_BENCHMARK_ACTIVE")) console.log(line);
    if (line.startsWith(prefix + "_BENCHMARK_SUMMARY ")) {
      summary = JSON.parse(line.slice((prefix + "_BENCHMARK_SUMMARY ").length));
    }
    if (line.startsWith(prefix + "_BENCHMARK_ROW ")) {
      rows.push(JSON.parse(line.slice((prefix + "_BENCHMARK_ROW ").length)));
    }
    if (line.startsWith(prefix + "_BENCHMARK_ERROR ")) failure = line;
    if (message.params.type === "error") messages.push(line);
  });
  const rpc = (method, params = {}) => new Promise((resolve, reject) => {
    const id = ++next;
    const timer = setTimeout(() => {
      pending.delete(id);
      reject(new Error("DevTools request timed out: " + method));
    }, 15000);
    pending.set(id, { resolve, reject, timer });
    socket.send(JSON.stringify({ id, method, params }));
  });
  await rpc("Runtime.enable");
  await rpc("Page.enable");
  await rpc("Page.addScriptToEvaluateOnNewDocument", {
    source: "(" + instrument.toString() + ")(" + JSON.stringify(prefix) + ");",
  });
  await rpc("Page.navigate", { url });
  console.log("BROWSER_BENCHMARK_STARTED " + url);
  const deadline = Date.now() + 15 * 60 * 1000;
  while (!summary && !failure && Date.now() < deadline) await delay(1000);
  if (failure) throw new Error(failure);
  if (!summary) throw new Error("Benchmark timed out: " + JSON.stringify(messages));
  // Flutter throttles debugPrint after the summary. Wait for every row instead
  // of truncating long captures when the logging queue has not drained yet.
  const expectedRows = prefix === "TERRAIN" ? summary.transitions : summary.attempts;
  const exportDeadline = Date.now() + 60000;
  while (rows.length < expectedRows && Date.now() < exportDeadline) await delay(100);
  if (rows.length !== expectedRows) {
    throw new Error("Incomplete benchmark export: " + rows.length + "/" + expectedRows);
  }
  // Give the completed Flutter summary a frame before taking its screenshot.
  await delay(250);
  const evidence = (await rpc("Runtime.evaluate", {
    expression: "window.__terrainEvidence",
    returnByValue: true,
  })).result.value;
  const gaps = [...evidence.gaps].sort((a, b) => a - b);
  const frameSummary = {
    frames: gaps.length,
    medianMs: gaps[Math.floor(gaps.length / 2)],
    p95Ms: gaps[Math.ceil(gaps.length * .95) - 1],
    maxMs: gaps.at(-1),
    over50: gaps.filter((value) => value > 50).length,
    over500: gaps.filter((value) => value > 500).length,
    longTasks: evidence.longTasks.length,
  };
  await writeFile(output, JSON.stringify({ summary, rows, frameSummary, evidence, messages }, null, 2));
  const screenshot = await rpc("Page.captureScreenshot", { format: "png" });
  await writeFile(output.replace(/\.json$/, "") + ".png", Buffer.from(screenshot.data, "base64"));
  console.log(JSON.stringify({ summary, frameSummary, messages, output }));
  await rpc("Browser.close");
} finally {
  socket?.close();
  browser.kill();
  server.close();
}
