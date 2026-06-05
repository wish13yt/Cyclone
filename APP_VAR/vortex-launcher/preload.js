const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('vortexAPI', {
  getCredentials: () => ipcRenderer.invoke('get-credentials'),
  launchGame: (mode) => ipcRenderer.invoke('launch-game', mode),
  killGame: () => ipcRenderer.invoke('kill-game'),
  getGameStatus: () => ipcRenderer.invoke('get-game-status'),
  selectFile: () => ipcRenderer.invoke('select-file'),
  clearSession: () => ipcRenderer.invoke('clear-session'),
  getPaths: () => ipcRenderer.invoke('get-paths'),
  onGameExited: (callback) => {
    ipcRenderer.on('game-exited', (_, code) => callback(code));
  },
  onGameErrored: (callback) => {
    ipcRenderer.on('game-errored', (_, msg) => callback(msg));
  },
});
