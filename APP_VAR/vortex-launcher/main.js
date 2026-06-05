const { app, BrowserWindow, ipcMain, dialog } = require('electron');
const path = require('path');
const fs = require('fs');
const { spawn } = require('child_process');

const VORTEX_DIR = path.resolve(__dirname, '..', '..');
const CREDENTIALS_FILE = path.join(VORTEX_DIR, 'config', 'usernamesandpasswords');
const VORTEX_EXE = path.join(VORTEX_DIR, 'bin', 'Vortex.exe');
const STUDIO_DIR = path.join(VORTEX_DIR, 'studio_ide_project');
const STUDIO_BIN = path.join(STUDIO_DIR, 'target', 'release', 'vortex-studio');
const STUDIO_SH = path.join(VORTEX_DIR, 'bin', 'vortex-studio.sh');
const RECEIVER_EXE = path.join(VORTEX_DIR, 'bin', 'receiver.exe');

let mainWindow = null;
let gameProcess = null;

function checkExists(file) {
  try {
    return fs.statSync(file).isFile();
  } catch {
    return false;
  }
}

function parseCredentials() {
  try {
    const raw = fs.readFileSync(CREDENTIALS_FILE, 'utf-8');
    const creds = [];
    for (const line of raw.split('\n')) {
      const trimmed = line.trim();
      if (!trimmed || trimmed === 'username password') continue;
      const parts = trimmed.split(/\s+/);
      if (parts.length >= 2) {
        creds.push({ username: parts[0], password: parts.slice(1).join(' ') });
      }
    }
    return creds;
  } catch {
    return [];
  }
}

function killGameProcess() {
  if (gameProcess) {
    try { gameProcess.kill(); } catch {}
    gameProcess = null;
  }
}

function launchExe(program, args, opts) {
  killGameProcess();
  gameProcess = spawn(program, args, {
    cwd: VORTEX_DIR,
    stdio: 'pipe',
    env: { ...process.env },
    ...opts,
  });

  if (gameProcess) {
    gameProcess.stdout?.on('data', d => console.log(`[game] ${d}`));
    gameProcess.stderr?.on('data', d => console.error(`[game] ${d}`));
    gameProcess.on('error', (err) => {
      console.error(`[game] spawn error: ${err.message}`);
      gameProcess = null;
      if (mainWindow) {
        mainWindow.webContents.send('game-errored', err.message);
      }
    });
    gameProcess.on('exit', (code) => {
      console.log(`Game exited with code ${code}`);
      gameProcess = null;
      if (mainWindow) {
        mainWindow.webContents.send('game-exited', code);
      }
    });
  }
  return gameProcess != null;
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1280,
    height: 800,
    minWidth: 900,
    minHeight: 600,
    title: 'Vortex Launcher',
    icon: path.join(VORTEX_DIR, 'assets', 'icon.ico'),
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      webviewTag: true,
    },
  });

  mainWindow.loadFile(path.join(__dirname, 'renderer', 'index.html'));

  mainWindow.on('closed', () => {
    mainWindow = null;
    killGameProcess();
  });
}

// ── IPC Handlers ──────────────────────────────────

ipcMain.handle('get-credentials', () => parseCredentials());

ipcMain.handle('clear-session', async () => {
  if (!mainWindow) return { success: false, reason: 'No window' };
  try {
    const contents = mainWindow.webContents;
    const webviewContents = contents.getAllWebContents().find(
      wc => wc.getURL().startsWith('https://playvortex.io')
    ) || contents;
    const session = webviewContents.session;
    await session.clearStorageData({
      storages: ['cookies', 'localstorage', 'sessionstorage', 'cachestorage', 'indexeddb'],
    });
    return { success: true };
  } catch (err) {
    return { success: false, reason: err.message };
  }
});

ipcMain.handle('launch-game', (_, mode) => {
  if (mode === 'wine') {
    if (!checkExists(VORTEX_EXE)) {
      return { success: false, reason: `Vortex.exe not found at ${VORTEX_EXE}` };
    }
    const ok = launchExe('wine', [VORTEX_EXE]);
    return { success: ok, reason: ok ? null : 'Failed to spawn wine' };
  }

  if (mode === 'native') {
    if (checkExists(STUDIO_BIN)) {
      const ok = launchExe(STUDIO_BIN, [], { cwd: STUDIO_DIR });
      return { success: ok, reason: ok ? null : 'Failed to spawn vortex-studio' };
    }
    if (checkExists(STUDIO_SH)) {
      const ok = launchExe('bash', [STUDIO_SH], { cwd: STUDIO_DIR });
      return { success: ok, reason: ok ? null : 'Failed to spawn vortex-studio.sh' };
    }
    return { success: false, reason: 'No native build found (checked binary and .sh)' };
  }

  if (mode === 'receiver') {
    if (!checkExists(RECEIVER_EXE)) {
      return { success: false, reason: `receiver.exe not found at ${RECEIVER_EXE}` };
    }
    const ok = launchExe('wine', [RECEIVER_EXE]);
    return { success: ok, reason: ok ? null : 'Failed to spawn receiver.exe' };
  }

  return { success: false, reason: `Unknown launch mode: ${mode}` };
});

ipcMain.handle('kill-game', () => {
  if (gameProcess) {
    killGameProcess();
    return { success: true };
  }
  return { success: false, reason: 'No game running' };
});

ipcMain.handle('get-game-status', () => {
  return { running: gameProcess !== null };
});

ipcMain.handle('select-file', async () => {
  const result = await dialog.showOpenDialog(mainWindow, {
    properties: ['openFile'],
    filters: [{ name: 'Executables', extensions: ['exe', 'sh'] }],
  });
  if (!result.canceled && result.filePaths.length > 0) {
    return result.filePaths[0];
  }
  return null;
});

ipcMain.handle('get-paths', () => ({
  vortexDir: VORTEX_DIR,
  credsFile: CREDENTIALS_FILE,
  vortexExe: VORTEX_EXE,
  studioBin: STUDIO_BIN,
  receiverExe: RECEIVER_EXE,
  appSearchDir: path.join(VORTEX_DIR, 'appsearch'),
}));

app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
  killGameProcess();
  if (process.platform !== 'darwin') app.quit();
});

app.on('activate', () => {
  if (!mainWindow) createWindow();
});
