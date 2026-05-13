const { app, BrowserWindow, ipcMain, shell } = require("electron");
const path = require("node:path");

const DEFAULT_CONFIG = {
  baseUrl: process.env.HERMES_BASE_URL || "http://YOUR_HERMES_HOST:8642/v1",
  apiKey: process.env.HERMES_API_KEY || "",
  model: process.env.HERMES_MODEL || "hermes-agent",
  mode: process.env.HERMES_MODE || "chat",
};

const activeStreams = new Map();

function createWindow() {
  const win = new BrowserWindow({
    width: 1180,
    height: 780,
    minWidth: 940,
    minHeight: 640,
    title: "Hermes Chat",
    backgroundColor: "#f4f1eb",
    titleBarStyle: "hiddenInset",
    trafficLightPosition: { x: 18, y: 18 },
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false,
    },
  });

  win.loadFile(path.join(__dirname, "index.html"));
}

app.whenReady().then(() => {
  createWindow();

  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});

function normalizeBaseUrl(baseUrl) {
  return String(baseUrl || "").trim().replace(/\/+$/, "");
}

function authHeaders(apiKey) {
  const cleanKey = String(apiKey || "").trim();
  return cleanKey
    ? { Authorization: cleanKey.startsWith("Bearer ") ? cleanKey : `Bearer ${cleanKey}` }
    : {};
}

function buildUrl(config, endpoint) {
  const baseUrl = normalizeBaseUrl(config.baseUrl);
  if (!baseUrl) throw new Error("请先填写 Hermes Agent 的云端地址。");

  if (endpoint.startsWith("/health") || endpoint.startsWith("/api/")) {
    return baseUrl.endsWith("/v1")
      ? `${baseUrl.slice(0, -3)}${endpoint}`
      : `${baseUrl}${endpoint}`;
  }

  if (baseUrl.endsWith("/v1") && endpoint.startsWith("/v1/")) {
    return `${baseUrl}${endpoint.slice(3)}`;
  }

  if (!baseUrl.endsWith("/v1") && !endpoint.startsWith("/v1/") && endpoint !== "/health") {
    return `${baseUrl}/v1${endpoint}`;
  }

  return `${baseUrl}${endpoint}`;
}

async function hermesFetch(config, endpoint, options = {}) {
  const response = await fetch(buildUrl(config, endpoint), {
    ...options,
    headers: {
      "Content-Type": "application/json",
      ...authHeaders(config.apiKey),
      ...(options.headers || {}),
    },
  });

  if (!response.ok) {
    let message = `${response.status} ${response.statusText}`;
    try {
      const data = await response.json();
      message = data.detail || data.error?.message || JSON.stringify(data);
    } catch (_) {
      try {
        message = await response.text();
      } catch (_) {
        // Keep the status text.
      }
    }
    throw new Error(message);
  }

  return response;
}

ipcMain.handle("config:defaults", () => DEFAULT_CONFIG);

ipcMain.handle("app:openExternal", async (_event, url) => {
  await shell.openExternal(url);
});

ipcMain.handle("hermes:health", async (_event, config) => {
  const response = await hermesFetch(config, "/health", { method: "GET" });
  return response.json();
});

ipcMain.handle("hermes:healthDetailed", async (_event, config) => {
  const response = await hermesFetch(config, "/health/detailed", { method: "GET" });
  return response.json();
});

ipcMain.handle("hermes:models", async (_event, config) => {
  const response = await hermesFetch(config, "/v1/models", { method: "GET" });
  return response.json();
});

ipcMain.handle("hermes:response", async (_event, payload) => {
  const { config, input, previousResponseId } = payload;
  const response = await hermesFetch(config, "/v1/responses", {
    method: "POST",
    body: JSON.stringify({
      model: config.model || "hermes-agent",
      input,
      previous_response_id: previousResponseId || null,
      instructions: config.instructions || undefined,
      max_tokens: config.maxTokens ? Number(config.maxTokens) : undefined,
      store: true,
      stream: false,
    }),
  });
  return response.json();
});

function parseSseBlock(block) {
  let eventName = "message";
  const dataLines = [];

  for (const line of block.split(/\r?\n/)) {
    if (line.startsWith("event:")) eventName = line.slice(6).trim();
    if (line.startsWith("data:")) dataLines.push(line.slice(5).trim());
  }

  const raw = dataLines.join("\n");
  if (!raw) return null;
  if (raw === "[DONE]") return { eventName, data: "[DONE]", raw };

  try {
    return { eventName, data: JSON.parse(raw), raw };
  } catch (_) {
    return { eventName, data: raw, raw };
  }
}

async function readSse(response, onEvent) {
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;

    buffer += decoder.decode(value, { stream: true });
    const blocks = buffer.split(/\r?\n\r?\n/);
    buffer = blocks.pop() || "";

    for (const block of blocks) {
      const parsed = parseSseBlock(block);
      if (parsed) onEvent(parsed);
    }
  }

  const parsed = parseSseBlock(buffer);
  if (parsed) onEvent(parsed);
}

function extractDelta(data) {
  if (typeof data === "string") return data;
  return data.choices?.[0]?.delta?.content
    || data.choices?.[0]?.message?.content
    || data.delta
    || data.text
    || data.output_text
    || data.response?.output_text?.delta
    || data.item?.content?.[0]?.text
    || "";
}

function streamEventToRenderer(sender, requestId, eventName, data, raw) {
  if (data === "[DONE]") {
    sender.send("hermes:streamEvent", { requestId, type: "done" });
    return;
  }

  if (eventName && eventName !== "message") {
    sender.send("hermes:streamEvent", { requestId, type: "progress", eventName, data, raw });
  }

  const delta = extractDelta(data);
  if (delta) {
    sender.send("hermes:streamEvent", { requestId, type: "delta", delta });
  }

  if (data?.usage) {
    sender.send("hermes:streamEvent", { requestId, type: "usage", usage: data.usage });
  }

  if (data?.id && (data.object === "response" || data.object === "chat.completion")) {
    sender.send("hermes:streamEvent", { requestId, type: "response_id", id: data.id });
  }
}

ipcMain.handle("hermes:streamChat", async (event, payload) => {
  const { requestId, config, messages, sessionId } = payload;
  const controller = new AbortController();
  activeStreams.set(requestId, { controller, config });

  try {
    const response = await hermesFetch(config, "/v1/chat/completions", {
      method: "POST",
      signal: controller.signal,
      headers: {
        ...(sessionId ? { "X-Hermes-Session-Id": sessionId } : {}),
        "Idempotency-Key": requestId,
      },
      body: JSON.stringify({
        model: config.model || "hermes-agent",
        stream: true,
        max_tokens: config.maxTokens ? Number(config.maxTokens) : undefined,
        messages,
      }),
    });

    const hermesSessionId = response.headers.get("x-hermes-session-id");
    if (hermesSessionId) {
      event.sender.send("hermes:streamEvent", { requestId, type: "session", sessionId: hermesSessionId });
    }

    await readSse(response, ({ eventName, data, raw }) => {
      streamEventToRenderer(event.sender, requestId, eventName, data, raw);
    });

    event.sender.send("hermes:streamEvent", { requestId, type: "done" });
    return { ok: true };
  } catch (error) {
    if (error.name === "AbortError") {
      event.sender.send("hermes:streamEvent", { requestId, type: "aborted" });
      return { ok: false, aborted: true };
    }
    event.sender.send("hermes:streamEvent", {
      requestId,
      type: "error",
      error: error.message || String(error),
    });
    return { ok: false, error: error.message || String(error) };
  } finally {
    activeStreams.delete(requestId);
  }
});

ipcMain.handle("hermes:streamResponse", async (event, payload) => {
  const { requestId, config, input, previousResponseId } = payload;
  const controller = new AbortController();
  activeStreams.set(requestId, { controller, config });

  try {
    const response = await hermesFetch(config, "/v1/responses", {
      method: "POST",
      signal: controller.signal,
      body: JSON.stringify({
        model: config.model || "hermes-agent",
        input,
        previous_response_id: previousResponseId || null,
        instructions: config.instructions || undefined,
        max_tokens: config.maxTokens ? Number(config.maxTokens) : undefined,
        store: true,
        stream: true,
      }),
    });

    await readSse(response, ({ eventName, data, raw }) => {
      streamEventToRenderer(event.sender, requestId, eventName, data, raw);
    });

    event.sender.send("hermes:streamEvent", { requestId, type: "done" });
    return { ok: true };
  } catch (error) {
    if (error.name === "AbortError") {
      event.sender.send("hermes:streamEvent", { requestId, type: "aborted" });
      return { ok: false, aborted: true };
    }
    event.sender.send("hermes:streamEvent", {
      requestId,
      type: "error",
      error: error.message || String(error),
    });
    return { ok: false, error: error.message || String(error) };
  } finally {
    activeStreams.delete(requestId);
  }
});

ipcMain.handle("hermes:getResponse", async (_event, payload) => {
  const { config, responseId } = payload;
  const response = await hermesFetch(config, `/v1/responses/${encodeURIComponent(responseId)}`, { method: "GET" });
  return response.json();
});

ipcMain.handle("hermes:deleteResponse", async (_event, payload) => {
  const { config, responseId } = payload;
  const response = await hermesFetch(config, `/v1/responses/${encodeURIComponent(responseId)}`, { method: "DELETE" });
  return response.json();
});

ipcMain.handle("hermes:startRun", async (event, payload) => {
  const { requestId, config, input } = payload;
  const controller = new AbortController();
  activeStreams.set(requestId, { controller, config });

  try {
    const response = await hermesFetch(config, "/v1/runs", {
      method: "POST",
      signal: controller.signal,
      body: JSON.stringify({
        model: config.model || "hermes-agent",
        input,
        instructions: config.instructions || undefined,
      }),
    });
    const run = await response.json();
    const runId = run.id || run.run_id;
    event.sender.send("hermes:streamEvent", { requestId, type: "run", run });
    if (!runId) throw new Error(`Hermes 没有返回 run_id：${JSON.stringify(run)}`);

    const events = await hermesFetch(config, `/v1/runs/${encodeURIComponent(runId)}/events`, {
      method: "GET",
      signal: controller.signal,
      headers: { Accept: "text/event-stream" },
    });

    await readSse(events, ({ eventName, data, raw }) => {
      streamEventToRenderer(event.sender, requestId, eventName, data, raw);
    });
    event.sender.send("hermes:streamEvent", { requestId, type: "done" });
    return { ok: true, runId };
  } catch (error) {
    if (error.name === "AbortError") {
      event.sender.send("hermes:streamEvent", { requestId, type: "aborted" });
      return { ok: false, aborted: true };
    }
    event.sender.send("hermes:streamEvent", {
      requestId,
      type: "error",
      error: error.message || String(error),
    });
    return { ok: false, error: error.message || String(error) };
  } finally {
    activeStreams.delete(requestId);
  }
});

ipcMain.handle("hermes:jobs", async (_event, payload) => {
  const { config } = payload;
  const response = await hermesFetch(config, "/api/jobs", { method: "GET" });
  return response.json();
});

ipcMain.handle("hermes:createJob", async (_event, payload) => {
  const { config, job } = payload;
  const response = await hermesFetch(config, "/api/jobs", {
    method: "POST",
    body: JSON.stringify(job),
  });
  return response.json();
});

ipcMain.handle("hermes:jobAction", async (_event, payload) => {
  const { config, jobId, action, patch } = payload;
  const endpoint = action === "update" || action === "delete"
    ? `/api/jobs/${encodeURIComponent(jobId)}`
    : `/api/jobs/${encodeURIComponent(jobId)}/${action}`;
  const response = await hermesFetch(config, endpoint, {
    method: action === "delete" ? "DELETE" : action === "update" ? "PATCH" : "POST",
    body: action === "update" ? JSON.stringify(patch || {}) : undefined,
  });
  return response.json();
});

ipcMain.handle("hermes:abort", (_event, requestId) => {
  const active = activeStreams.get(requestId);
  if (active?.controller) active.controller.abort();
  activeStreams.delete(requestId);
  return { ok: true };
});
