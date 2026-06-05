const webview = document.getElementById('webview');
const loginPanel = document.getElementById('login-panel');
const launchPanel = document.getElementById('launch-panel');
const savedAccounts = document.getElementById('saved-accounts');
const loginUsername = document.getElementById('login-username');
const loginPassword = document.getElementById('login-password');
const gameStatus = document.getElementById('game-status');
const statusText = document.getElementById('status-text');
const btnBack = document.getElementById('btn-back');
const btnForward = document.getElementById('btn-forward');
const urlBar = document.getElementById('url-bar');

let credentials = [];
let gameRunning = false;

// ── Load saved credentials ────────────────────────
async function loadCredentials() {
  credentials = await window.vortexAPI.getCredentials();
  savedAccounts.innerHTML = '';
  for (const cred of credentials) {
    const opt = document.createElement('option');
    opt.value = `${cred.username}|${cred.password}`;
    opt.textContent = cred.username;
    savedAccounts.appendChild(opt);
  }
}

// ── Status ────────────────────────────────────────
function setStatus(msg) {
  statusText.textContent = msg;
}

// ── Panel Toggles ─────────────────────────────────
function hideAllPanels() {
  loginPanel.classList.add('hidden');
  launchPanel.classList.add('hidden');
}

document.getElementById('btn-login-toggle').addEventListener('click', () => {
  if (!loginPanel.classList.contains('hidden')) {
    hideAllPanels();
    return;
  }
  hideAllPanels();
  loginPanel.classList.remove('hidden');
});

document.getElementById('btn-launch-toggle').addEventListener('click', () => {
  if (!launchPanel.classList.contains('hidden')) {
    hideAllPanels();
    return;
  }
  hideAllPanels();
  launchPanel.classList.remove('hidden');
});

document.querySelectorAll('.panel-close').forEach(btn => {
  btn.addEventListener('click', hideAllPanels);
});

// ── Login: Fill Selected Account ──────────────────
document.getElementById('btn-fill-creds').addEventListener('click', () => {
  const selected = savedAccounts.value;
  if (!selected) return;
  const [user, pass] = selected.split('|');
  loginUsername.value = user;
  loginPassword.value = pass;
});

// ── Login: Submit with auto-logout ────────────────
async function doLogoutThenLogin(username, password) {
  setStatus(`Logging out...`);
  await window.vortexAPI.clearSession();

  webview.loadURL('https://playvortex.io/');

  await new Promise((resolve) => {
    webview.addEventListener('did-finish-load', resolve, { once: true });
  });

  const filled = await webview.executeJavaScript(`
    (() => {
      const u = document.getElementById('username');
      const p = document.getElementById('password');
      const f = document.getElementById('form');
      if (!u || !p) return 'no_form';
      u.value = ${JSON.stringify(username)};
      p.value = ${JSON.stringify(password)};
      f.dispatchEvent(new Event('submit', { cancelable: true }));
      return 'submitted';
    })();
  `);

  if (filled === 'no_form') {
    setStatus('Login form not found — page may not be ready, fill manually');
  } else {
    setStatus(`Logging in as ${username}...`);
    hideAllPanels();
  }
}

loginUsername.addEventListener('keydown', (e) => {
  if (e.key === 'Enter') document.getElementById('btn-login-submit').click();
});
loginPassword.addEventListener('keydown', (e) => {
  if (e.key === 'Enter') document.getElementById('btn-login-submit').click();
});

document.getElementById('btn-login-submit').addEventListener('click', async () => {
  const user = loginUsername.value.trim();
  const pass = loginPassword.value.trim();
  if (!user || !pass) {
    setStatus('Enter username and password');
    return;
  }
  doLogoutThenLogin(user, pass);
});

// ── Launch Panel ──────────────────────────────────
async function refreshGameStatus() {
  const st = await window.vortexAPI.getGameStatus();
  gameRunning = st.running;
  gameStatus.textContent = st.running ? '▶ Running' : 'Not running';
  gameStatus.className = st.running ? 'running' : '';
  document.getElementById('btn-launch-game').classList.toggle('hidden', st.running);
  document.getElementById('btn-kill-game').classList.toggle('hidden', !st.running);
}

document.getElementById('btn-launch-game').addEventListener('click', async () => {
  const mode = document.querySelector('input[name="launch-mode"]:checked').value;
  setStatus(`Launching ${mode}...`);
  const result = await window.vortexAPI.launchGame(mode);
  if (result.success) {
    await refreshGameStatus();
    setStatus(`${mode} started`);
  } else {
    setStatus(`Failed: ${result.reason}`);
  }
});

document.getElementById('btn-kill-game').addEventListener('click', async () => {
  const result = await window.vortexAPI.killGame();
  if (result.success) {
    await refreshGameStatus();
    setStatus('Game stopped');
  }
});

window.vortexAPI.onGameExited((code) => {
  gameRunning = false;
  gameStatus.textContent = `Exited (code ${code})`;
  gameStatus.className = '';
  document.getElementById('btn-launch-game').classList.remove('hidden');
  document.getElementById('btn-kill-game').classList.add('hidden');
  setStatus(`Game exited with code ${code}`);
});

window.vortexAPI.onGameErrored((msg) => {
  setStatus(`Error: ${msg}`);
});

// ── Webview Navigation ────────────────────────────
function updateNavButtons() {
  try {
    btnBack.disabled = !webview.canGoBack();
    btnForward.disabled = !webview.canGoForward();
  } catch {}
}

let navTimer = null;
webview.addEventListener('did-navigate', (e) => {
  urlBar.value = e.url;
  clearTimeout(navTimer);
  navTimer = setTimeout(updateNavButtons, 100);
});

webview.addEventListener('did-navigate-in-page', (e) => {
  urlBar.value = e.url;
  clearTimeout(navTimer);
  navTimer = setTimeout(updateNavButtons, 100);
});

webview.addEventListener('did-start-loading', () => {
  document.getElementById('btn-refresh').textContent = '✕';
});

webview.addEventListener('did-stop-loading', () => {
  document.getElementById('btn-refresh').textContent = '↻';
  updateNavButtons();
});

webview.addEventListener('page-title-updated', (e) => {
  document.title = `Vortex — ${e.title}`;
});

btnBack.addEventListener('click', () => {
  if (webview.canGoBack()) webview.goBack();
});

btnForward.addEventListener('click', () => {
  if (webview.canGoForward()) webview.goForward();
});

document.getElementById('btn-refresh').addEventListener('click', () => {
  webview.reload();
});

urlBar.addEventListener('keydown', (e) => {
  if (e.key === 'Enter') {
    let url = urlBar.value.trim();
    if (url && !url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://' + url;
    }
    if (url) webview.loadURL(url);
  }
});

// Keyboard shortcuts
document.addEventListener('keydown', (e) => {
  if (e.ctrlKey && e.key === 'l') {
    e.preventDefault();
    urlBar.select();
  }
  if (e.key === 'Escape') {
    hideAllPanels();
  }
});

// ── Init ──────────────────────────────────────────
loadCredentials();
refreshGameStatus();
setStatus('Ready');
