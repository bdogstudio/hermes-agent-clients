const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("hermes", {
  defaults: () => ipcRenderer.invoke("config:defaults"),
  health: (config) => ipcRenderer.invoke("hermes:health", config),
  healthDetailed: (config) => ipcRenderer.invoke("hermes:healthDetailed", config),
  models: (config) => ipcRenderer.invoke("hermes:models", config),
  sendResponse: (payload) => ipcRenderer.invoke("hermes:response", payload),
  streamResponse: (payload) => ipcRenderer.invoke("hermes:streamResponse", payload),
  getResponse: (payload) => ipcRenderer.invoke("hermes:getResponse", payload),
  deleteResponse: (payload) => ipcRenderer.invoke("hermes:deleteResponse", payload),
  startRun: (payload) => ipcRenderer.invoke("hermes:startRun", payload),
  listJobs: (payload) => ipcRenderer.invoke("hermes:jobs", payload),
  createJob: (payload) => ipcRenderer.invoke("hermes:createJob", payload),
  jobAction: (payload) => ipcRenderer.invoke("hermes:jobAction", payload),
  streamChat: (payload) => ipcRenderer.invoke("hermes:streamChat", payload),
  abort: (requestId) => ipcRenderer.invoke("hermes:abort", requestId),
  openExternal: (url) => ipcRenderer.invoke("app:openExternal", url),
  onStreamEvent: (callback) => {
    const listener = (_event, data) => callback(data);
    ipcRenderer.on("hermes:streamEvent", listener);
    return () => ipcRenderer.removeListener("hermes:streamEvent", listener);
  },
});
