const els = {
  baseUrl: document.querySelector("#baseUrlInput"),
  apiKey: document.querySelector("#apiKeyInput"),
  model: document.querySelector("#modelSelect"),
  instructions: document.querySelector("#instructionsInput"),
  maxTokens: document.querySelector("#maxTokensInput"),
  responseStream: document.querySelector("#responseStreamInput"),
  responseId: document.querySelector("#responseIdInput"),
  getResponse: document.querySelector("#getResponseButton"),
  deleteResponse: document.querySelector("#deleteResponseButton"),
  health: document.querySelector("#healthButton"),
  status: document.querySelector("#connectionStatus"),
  modes: [...document.querySelectorAll(".mode")],
  chatTitle: document.querySelector("#chatTitle"),
  chatArea: document.querySelector("#chatArea"),
  sessionList: document.querySelector("#sessionList"),
  newChat: document.querySelector("#newChatButton"),
  composer: document.querySelector("#composer"),
  input: document.querySelector("#promptInput"),
  send: document.querySelector("#sendButton"),
  stop: document.querySelector("#stopButton"),
  tracePanel: document.querySelector("#tracePanel"),
  traceToggle: document.querySelector("#traceToggle"),
  traceContent: document.querySelector("#traceContent"),
  jobsPanel: document.querySelector("#jobsPanel"),
  jobForm: document.querySelector("#jobForm"),
  jobName: document.querySelector("#jobNameInput"),
  jobSchedule: document.querySelector("#jobScheduleInput"),
  jobPrompt: document.querySelector("#jobPromptInput"),
  refreshJobs: document.querySelector("#refreshJobsButton"),
  jobsList: document.querySelector("#jobsList"),
};

const STORAGE_KEY = "hermes-mac-chat-state";

let state = {
  config: {
    baseUrl: "",
    apiKey: "",
    model: "hermes-agent",
    instructions: "",
    maxTokens: "",
    responseStream: true,
  },
  mode: "chat",
  sessions: [],
  activeSessionId: "",
  activeRequestId: "",
  jobs: [],
  jobsLoaded: false,
};

function createSession(title = "新对话") {
  return {
    id: crypto.randomUUID(),
    title,
    createdAt: Date.now(),
    messages: [],
    trace: [],
    previousResponseId: "",
    hermesSessionId: "",
  };
}

function loadState() {
  try {
    const stored = JSON.parse(localStorage.getItem(STORAGE_KEY) || "{}");
    state = {
      ...state,
      ...stored,
      config: { ...state.config, ...(stored.config || {}) },
    };
  } catch (_) {
    // Start clean if local storage contains invalid JSON.
  }

  if (!state.sessions.length) {
    const session = createSession("Hermes 对话");
    state.sessions = [session];
    state.activeSessionId = session.id;
  }

  if (!["chat", "responses", "runs", "jobs"].includes(state.mode)) {
    state.mode = "chat";
  }
}

function saveState() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify({
    config: state.config,
    mode: state.mode,
    sessions: state.sessions,
    activeSessionId: state.activeSessionId,
  }));
}

function activeSession() {
  return state.sessions.find((session) => session.id === state.activeSessionId) || state.sessions[0];
}

function syncConfigToForm() {
  els.baseUrl.value = state.config.baseUrl;
  els.apiKey.value = state.config.apiKey;
  els.model.value = state.config.model;
  els.instructions.value = state.config.instructions || "";
  els.maxTokens.value = state.config.maxTokens || "";
  els.responseStream.checked = state.config.responseStream !== false;
}

function readConfigFromForm() {
  state.config = {
    ...state.config,
    baseUrl: els.baseUrl.value.trim(),
    apiKey: els.apiKey.value.trim(),
    model: els.model.value,
    instructions: els.instructions.value.trim(),
    maxTokens: els.maxTokens.value.trim(),
    responseStream: els.responseStream.checked,
  };
  saveState();
  return state.config;
}

function setStatus(text, className = "") {
  els.status.className = `connection-status ${className}`.trim();
  els.status.textContent = text;
}

function renderSessions() {
  els.sessionList.replaceChildren();
  for (const session of state.sessions) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = `session-item ${session.id === state.activeSessionId ? "active" : ""}`;
    button.dataset.sessionId = session.id;
    button.innerHTML = `
      <div class="session-title"></div>
      <div class="session-meta">${session.messages.length} 条消息</div>
    `;
    button.querySelector(".session-title").textContent = session.title;
    button.addEventListener("click", () => {
      state.activeSessionId = session.id;
      saveState();
      render();
    });
    els.sessionList.append(button);
  }
}

function emptyState() {
  const wrapper = document.createElement("div");
  wrapper.className = "empty-state";
  wrapper.innerHTML = `
    <div>
      <h3>连接 Hermes，开始实时对话</h3>
      <p>左侧填入 Hermes API Server 地址和 API_SERVER_KEY，然后像聊天软件一样发送消息。</p>
    </div>
  `;
  return wrapper;
}

function messageNode(message) {
  const row = document.createElement("article");
  row.className = `message ${message.role}${message.error ? " error" : ""}`;

  const avatar = document.createElement("div");
  avatar.className = "avatar";
  avatar.textContent = message.role === "user" ? "你" : "H";

  const bubble = document.createElement("div");
  bubble.className = "bubble";
  bubble.textContent = message.content || "";

  if (message.meta) {
    const meta = document.createElement("div");
    meta.className = "meta-line";
    meta.textContent = message.meta;
    bubble.append(meta);
  }

  row.append(avatar, bubble);
  return row;
}

function renderMessages() {
  const session = activeSession();
  const wasNearBottom = els.chatArea.scrollHeight - els.chatArea.scrollTop - els.chatArea.clientHeight < 120;
  els.chatArea.replaceChildren();

  if (!session.messages.length) {
    els.chatArea.append(emptyState());
  } else {
    for (const message of session.messages) {
      els.chatArea.append(messageNode(message));
    }
    if (wasNearBottom) {
      els.chatArea.scrollTop = els.chatArea.scrollHeight;
    }
  }

  renderTrace();
}

function renderTrace() {
  const session = activeSession();
  els.traceContent.replaceChildren();

  if (!session.trace?.length) {
    const empty = document.createElement("div");
    empty.className = "trace-step";
    empty.textContent = "当前对话还没有状态信息。";
    els.traceContent.append(empty);
    return;
  }

  for (const [index, step] of session.trace.entries()) {
    const item = document.createElement("div");
    item.className = "trace-step";
    const title = step.event || step.role || step.type || step.action || `Event ${index + 1}`;
    item.innerHTML = `<strong></strong><pre></pre>`;
    item.querySelector("strong").textContent = `${index + 1}. ${title}`;
    item.querySelector("pre").textContent = JSON.stringify(step, null, 2);
    els.traceContent.append(item);
  }
}

function normalizeJobs(payload) {
  if (Array.isArray(payload)) return payload;
  if (Array.isArray(payload?.jobs)) return payload.jobs;
  if (Array.isArray(payload?.data)) return payload.data;
  return [];
}

function renderJobs() {
  els.jobsList.replaceChildren();

  if (!state.jobsLoaded) {
    const empty = document.createElement("div");
    empty.className = "trace-step";
    empty.textContent = "点击刷新任务查看 Hermes Cron Jobs。";
    els.jobsList.append(empty);
    return;
  }

  if (!state.jobs.length) {
    const empty = document.createElement("div");
    empty.className = "trace-step";
    empty.textContent = "当前没有定时任务。";
    els.jobsList.append(empty);
    return;
  }

  for (const job of state.jobs) {
    const id = job.job_id || job.id;
    const enabled = job.enabled !== false && job.status !== "paused";
    const card = document.createElement("article");
    card.className = "job-card";
    card.innerHTML = `
      <div>
        <h3></h3>
        <p class="job-meta"></p>
        <p class="job-text"></p>
      </div>
      <div class="job-card-actions">
        <button class="icon-action run" type="button" title="立即执行">运行</button>
        <button class="icon-action pause" type="button" title="${enabled ? "暂停" : "恢复"}"></button>
        <button class="icon-action danger delete" type="button" title="删除">删除</button>
      </div>
    `;
    card.querySelector("h3").textContent = job.name || id || "未命名任务";
    card.querySelector(".job-meta").textContent = [
      job.schedule_display || (typeof job.schedule === "string" ? `Cron ${job.schedule}` : ""),
      job.next_run_at ? `下次 ${job.next_run_at}` : "",
      job.last_status ? `上次 ${job.last_status}` : "",
      enabled ? "启用" : "暂停",
    ].filter(Boolean).join(" · ");
    card.querySelector(".job-text").textContent = job.prompt || "";
    card.querySelector(".pause").textContent = enabled ? "暂停" : "恢复";
    card.querySelector(".run").addEventListener("click", () => runJobAction(id, "run"));
    card.querySelector(".pause").addEventListener("click", () => runJobAction(id, enabled ? "pause" : "resume"));
    card.querySelector(".delete").addEventListener("click", () => runJobAction(id, "delete"));
    els.jobsList.append(card);
  }
}

function renderMode() {
  for (const button of els.modes) {
    button.classList.toggle("active", button.dataset.mode === state.mode);
  }

  const titleByMode = {
    chat: "Hermes 实时消息",
    responses: "Hermes 会话保持",
    runs: "Hermes Runs",
    jobs: "Hermes 定时任务",
  };
  els.chatTitle.textContent = titleByMode[state.mode];
  els.chatArea.classList.toggle("hidden", state.mode === "jobs");
  els.jobsPanel.classList.toggle("hidden", state.mode !== "jobs");
  els.composer.classList.toggle("hidden", state.mode === "jobs");
}

function render() {
  renderMode();
  renderSessions();
  renderMessages();
  renderJobs();
}

function pushMessage(message) {
  const session = activeSession();
  session.messages.push({
    id: crypto.randomUUID(),
    createdAt: Date.now(),
    ...message,
  });

  if (message.role === "user" && session.messages.filter((m) => m.role === "user").length === 1) {
    session.title = message.content.slice(0, 26) || "新对话";
  }

  saveState();
  render();
}

function updateLastAssistant(delta) {
  const session = activeSession();
  const last = [...session.messages].reverse().find((message) => message.role === "assistant");
  if (!last) return;
  last.content += delta;
  saveState();
  renderMessages();
}

function setLastAssistant(content, meta) {
  const session = activeSession();
  const last = [...session.messages].reverse().find((message) => message.role === "assistant");
  if (!last) return;
  last.content = content;
  if (meta) last.meta = meta;
  saveState();
  renderMessages();
}

function setBusy(isBusy) {
  els.send.disabled = isBusy;
  els.stop.classList.toggle("hidden", !isBusy);
  els.input.disabled = isBusy;
}

function textMessagesForChat() {
  const messages = activeSession()
    .messages
    .filter((message) => !message.error)
    .map((message) => ({
      role: message.role === "assistant" ? "assistant" : "user",
      content: message.content,
    }));
  const config = readConfigFromForm();
  if (config.instructions) {
    return [{ role: "system", content: config.instructions }, ...messages];
  }
  return messages;
}

async function sendChat(question) {
  const requestId = crypto.randomUUID();
  state.activeRequestId = requestId;

  pushMessage({ role: "user", content: question });
  pushMessage({ role: "assistant", content: "" });
  setBusy(true);

  await window.hermes.streamChat({
    requestId,
    config: readConfigFromForm(),
    messages: textMessagesForChat().slice(0, -1),
    sessionId: activeSession().hermesSessionId || activeSession().id,
  });
}

function extractResponseText(result) {
  if (typeof result === "string") return result;
  if (result.output_text) return result.output_text;
  if (result.answer) return result.answer;
  if (result.message?.content) return result.message.content;
  if (Array.isArray(result.output)) {
    return result.output
      .flatMap((item) => item.content || item.text || [])
      .map((part) => typeof part === "string" ? part : part.text || part.content || "")
      .join("");
  }
  if (result.choices?.[0]?.message?.content) return result.choices[0].message.content;
  return JSON.stringify(result, null, 2);
}

function formatResponseResult(result) {
  const answer = extractResponseText(result);
  const status = result.status ? `状态：${result.status}` : "";
  const id = result.id ? `id：${result.id}` : "";
  return { answer, meta: [status, id].filter(Boolean).join(" · ") };
}

async function sendResponse(question) {
  const session = activeSession();
  const config = readConfigFromForm();

  if (config.responseStream) {
    const requestId = crypto.randomUUID();
    state.activeRequestId = requestId;
    pushMessage({ role: "user", content: question });
    pushMessage({ role: "assistant", content: "" });
    setBusy(true);
    await window.hermes.streamResponse({
      requestId,
      config,
      input: question,
      previousResponseId: session.previousResponseId,
    });
    return;
  }

  pushMessage({ role: "user", content: question });
  pushMessage({ role: "assistant", content: "正在等待 Hermes 回复..." });
  setBusy(true);

  try {
    const result = await window.hermes.sendResponse({
      config,
      input: question,
      previousResponseId: session.previousResponseId,
    });
    const formatted = formatResponseResult(result);
    setLastAssistant(formatted.answer, formatted.meta);
    session.previousResponseId = result.id || session.previousResponseId;
    session.trace = result.output || result.events || [];
    saveState();
    renderTrace();
  } catch (error) {
    setLastAssistant(`连接或执行失败：${error.message || error}`);
    activeSession().messages.at(-1).error = true;
    saveState();
    renderMessages();
  } finally {
    setBusy(false);
    state.activeRequestId = "";
  }
}

async function sendRun(question) {
  const requestId = crypto.randomUUID();
  state.activeRequestId = requestId;
  pushMessage({ role: "user", content: question });
  pushMessage({ role: "assistant", content: "" });
  activeSession().trace = [];
  setBusy(true);

  await window.hermes.startRun({
    requestId,
    config: readConfigFromForm(),
    input: question,
  });
}

async function sendPrompt(question) {
  if (state.mode === "runs") {
    await sendRun(question);
  } else if (state.mode === "responses") {
    await sendResponse(question);
  } else if (state.mode === "chat") {
    await sendChat(question);
  }
}

function autoGrow() {
  els.input.style.height = "auto";
  els.input.style.height = `${Math.min(220, els.input.scrollHeight)}px`;
}

async function init() {
  loadState();
  const defaults = await window.hermes.defaults();
  state.config = {
    ...state.config,
    baseUrl: state.config.baseUrl || defaults.baseUrl,
    apiKey: state.config.apiKey || defaults.apiKey,
    model: state.config.model || defaults.model,
  };
  syncConfigToForm();
  render();
  saveState();
}

els.composer.addEventListener("submit", async (event) => {
  event.preventDefault();
  const question = els.input.value.trim();
  if (!question || els.send.disabled) return;
  els.input.value = "";
  autoGrow();
  await sendPrompt(question);
});

els.input.addEventListener("input", autoGrow);
els.input.addEventListener("keydown", (event) => {
  if (event.key === "Enter" && (event.metaKey || event.ctrlKey)) {
    event.preventDefault();
    els.composer.requestSubmit();
  }
});

els.stop.addEventListener("click", async () => {
  if (state.activeRequestId) {
    await window.hermes.abort(state.activeRequestId);
  }
  setBusy(false);
});

els.newChat.addEventListener("click", () => {
  const session = createSession();
  state.sessions.unshift(session);
  state.activeSessionId = session.id;
  saveState();
  render();
  els.input.focus();
});

async function refreshJobs() {
  try {
    const result = await window.hermes.listJobs({ config: readConfigFromForm() });
    state.jobs = normalizeJobs(result);
    state.jobsLoaded = true;
    renderJobs();
  } catch (error) {
    state.jobsLoaded = true;
    state.jobs = [];
    renderJobs();
    setStatus(`任务列表失败：${error.message || error}`, "error");
  }
}

async function runJobAction(jobId, action) {
  if (!jobId) return;
  if (action === "delete" && !window.confirm("确定删除这个定时任务吗？")) return;
  try {
    await window.hermes.jobAction({
      config: readConfigFromForm(),
      jobId,
      action,
    });
    await refreshJobs();
  } catch (error) {
    setStatus(`任务操作失败：${error.message || error}`, "error");
  }
}

for (const input of [els.baseUrl, els.apiKey, els.model, els.instructions, els.maxTokens, els.responseStream]) {
  input.addEventListener("change", readConfigFromForm);
}

for (const button of els.modes) {
  button.addEventListener("click", () => {
    state.mode = button.dataset.mode;
    saveState();
    renderMode();
    if (state.mode === "jobs" && !state.jobsLoaded) refreshJobs();
  });
}

els.health.addEventListener("click", async () => {
  setStatus("正在检查连接...", "warn");
  try {
    const config = readConfigFromForm();
    const health = await window.hermes.health(config);
    const detailed = await window.hermes.healthDetailed(config).catch(() => null);
    let models = null;
    try {
      models = await window.hermes.models(config);
    } catch (_) {
      models = null;
    }
    const modelNames = Array.isArray(models?.data)
      ? models.data.map((model) => model.id).join(", ")
      : "Hermes API Server";
    const platforms = detailed?.platforms
      ? Object.entries(detailed.platforms)
          .map(([name, value]) => `${name}:${typeof value === "string" ? value : value.state || "unknown"}`)
          .join(" ")
      : "";
    setStatus(`已连接：${health.status || "ok"} · ${modelNames}${platforms ? ` · ${platforms}` : ""}`, health.status === "degraded" ? "warn" : "ok");
  } catch (error) {
    setStatus(`连接失败：${error.message || error}`, "error");
  }
});

els.getResponse.addEventListener("click", async () => {
  const responseId = els.responseId.value.trim();
  if (!responseId) return;
  try {
    const result = await window.hermes.getResponse({
      config: readConfigFromForm(),
      responseId,
    });
    pushMessage({ role: "assistant", content: extractResponseText(result), meta: `读取响应：${responseId}` });
    activeSession().trace = result.output || [result];
    renderTrace();
  } catch (error) {
    setStatus(`读取响应失败：${error.message || error}`, "error");
  }
});

els.deleteResponse.addEventListener("click", async () => {
  const responseId = els.responseId.value.trim();
  if (!responseId) return;
  try {
    await window.hermes.deleteResponse({
      config: readConfigFromForm(),
      responseId,
    });
    setStatus(`已删除响应：${responseId}`, "ok");
  } catch (error) {
    setStatus(`删除响应失败：${error.message || error}`, "error");
  }
});

els.refreshJobs.addEventListener("click", refreshJobs);

els.jobForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  const prompt = els.jobPrompt.value.trim();
  const schedule = els.jobSchedule.value.trim();
  const name = els.jobName.value.trim();
  if (!prompt || !schedule) return;

  try {
    await window.hermes.createJob({
      config: readConfigFromForm(),
      job: { name, schedule, prompt },
    });
    els.jobPrompt.value = "";
    els.jobSchedule.value = "";
    els.jobName.value = "";
    await refreshJobs();
  } catch (error) {
    setStatus(`创建任务失败：${error.message || error}`, "error");
  }
});

els.traceToggle.addEventListener("click", () => {
  els.tracePanel.classList.toggle("collapsed");
});

window.hermes.onStreamEvent((event) => {
  if (event.requestId !== state.activeRequestId) return;

  if (event.type === "delta") {
    updateLastAssistant(event.delta);
  }

  if (event.type === "usage") {
    const usage = event.usage;
    setLastAssistant(activeSession().messages.at(-1).content, `Tokens：${usage.prompt_tokens || 0}+${usage.completion_tokens || 0}`);
  }

  if (event.type === "session") {
    activeSession().hermesSessionId = event.sessionId;
    saveState();
  }

  if (event.type === "response_id") {
    activeSession().previousResponseId = event.id;
    saveState();
  }

  if (event.type === "run") {
    const session = activeSession();
    session.trace.push({ event: "run.created", data: event.run });
    saveState();
    renderTrace();
  }

  if (event.type === "progress") {
    const session = activeSession();
    session.trace.push({
      event: event.eventName,
      data: event.data,
    });
    saveState();
    renderTrace();
  }

  if (event.type === "done" || event.type === "aborted") {
    setBusy(false);
    state.activeRequestId = "";
  }

  if (event.type === "error") {
    const session = activeSession();
    const last = session.messages.at(-1);
    if (last) {
      last.content = `连接或执行失败：${event.error}`;
      last.error = true;
    }
    saveState();
    renderMessages();
    setBusy(false);
    state.activeRequestId = "";
  }
});

init();
