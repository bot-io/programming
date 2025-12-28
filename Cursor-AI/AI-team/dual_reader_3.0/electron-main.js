const { app, BrowserWindow } = require('electron');
const path = require('path');
const { spawn } = require('child_process');
const http = require('http');

let mainWindow;
let metroProcess;

// Simple React Native app rendered directly
const APP_HTML = `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dual Reader 3.0</title>
    <script crossorigin src="https://unpkg.com/react@18/umd/react.production.min.js"></script>
    <script crossorigin src="https://unpkg.com/react-dom@18/umd/react-dom.production.min.js"></script>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: #000000;
            color: #ffffff;
            height: 100vh;
            overflow: hidden;
        }
        #root {
            width: 100%;
            height: 100%;
            display: flex;
            flex-direction: column;
        }
        .container {
            flex: 1;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            padding: 20px;
        }
        .title {
            font-size: 32px;
            font-weight: bold;
            color: #FFFFFF;
            margin-bottom: 8px;
            text-align: center;
        }
        .subtitle {
            font-size: 18px;
            color: #CCCCCC;
            text-align: center;
        }
    </style>
</head>
<body>
    <div id="root">
        <div class="container">
            <div class="title">Dual Reader 3.0</div>
            <div class="subtitle">Mobile Ebook Reader</div>
        </div>
    </div>
    <script>
        // Simple React app
        const { createElement: h } = React;
        const root = ReactDOM.createRoot(document.getElementById('root'));
        
        function App() {
            return h('div', { className: 'container' },
                h('div', { className: 'title' }, 'Dual Reader 3.0'),
                h('div', { className: 'subtitle' }, 'Mobile Ebook Reader')
            );
        }
        
        root.render(h(App));
    </script>
</body>
</html>
`;

function checkMetro() {
  return new Promise((resolve) => {
    const req = http.get('http://localhost:8081/status', { timeout: 1000 }, (res) => {
      resolve(res.statusCode === 200);
    });
    req.on('error', () => resolve(false));
    req.on('timeout', () => {
      req.destroy();
      resolve(false);
    });
  });
}

async function loadApp() {
  // First try Metro if available
  const metroAvailable = await checkMetro();
  if (metroAvailable) {
    console.log('Metro is available, loading from Metro...');
    try {
      await mainWindow.loadURL('http://localhost:8081/index.bundle?platform=web&dev=true');
      return;
    } catch (err) {
      console.log('Failed to load from Metro, using standalone version');
    }
  }
  
  // Fallback to standalone version
  console.log('Loading standalone app...');
  mainWindow.loadURL(`data:text/html;charset=utf-8,${encodeURIComponent(APP_HTML)}`);
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1400,
    height: 900,
    title: 'Dual Reader 3.0',
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false,
      webSecurity: false
    }
  });

  // Try to start Metro in background (non-blocking)
  console.log('Attempting to start Metro bundler...');
  try {
    metroProcess = spawn('npx', ['react-native', 'start'], {
      cwd: __dirname,
      shell: true,
      stdio: 'ignore',
      detached: true
    });
    metroProcess.unref(); // Don't wait for it
  } catch (err) {
    console.log('Could not start Metro, using standalone version');
  }

  // Load app immediately (standalone version)
  // Will upgrade to Metro version if Metro becomes available
  loadApp();
  
  // Check for Metro every 5 seconds and upgrade if available
  const upgradeInterval = setInterval(async () => {
    const metroAvailable = await checkMetro();
    if (metroAvailable) {
      console.log('Metro is now available, upgrading to Metro version...');
      clearInterval(upgradeInterval);
      try {
        await mainWindow.loadURL('http://localhost:8081/index.bundle?platform=web&dev=true');
      } catch (err) {
        console.log('Could not upgrade to Metro version');
      }
    }
  }, 5000);
  
  mainWindow.on('closed', () => {
    clearInterval(upgradeInterval);
    if (metroProcess) {
      try {
        metroProcess.kill();
      } catch (e) {}
    }
  });
}

app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    if (metroProcess) {
      try {
        metroProcess.kill();
      } catch (e) {}
    }
    app.quit();
  }
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow();
  }
});

