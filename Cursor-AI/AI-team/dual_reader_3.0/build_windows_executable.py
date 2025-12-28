"""Build a working Windows executable for the Dual Reader app"""
import os
import sys
import subprocess
import json
import shutil

def main():
    project_dir = os.path.abspath(os.path.dirname(__file__))
    use_shell = os.name == 'nt'
    
    print("=== Building Windows Executable ===")
    print(f"Project directory: {project_dir}")
    
    # Option 1: Try Electron (simplest for cross-platform desktop)
    print("\n[Option 1] Setting up Electron wrapper...")
    
    # Install Electron and related packages
    electron_packages = [
        'electron@latest',
        'electron-builder@latest',
        'electron-packager@latest'
    ]
    
    print("Installing Electron packages...")
    for pkg in electron_packages:
        result = subprocess.run(
            ['npm', 'install', '--save-dev', pkg],
            cwd=project_dir,
            capture_output=True,
            timeout=300,
            text=True,
            shell=use_shell
        )
        if result.returncode != 0:
            print(f"Warning: Failed to install {pkg}: {result.stderr[:200]}")
    
    # Create Electron main process file
    electron_main = os.path.join(project_dir, 'electron-main.js')
    with open(electron_main, 'w', encoding='utf-8') as f:
        f.write("""const { app, BrowserWindow } = require('electron');
const path = require('path');
const { spawn } = require('child_process');

let mainWindow;
let metroProcess;

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

  // Start Metro bundler
  console.log('Starting Metro bundler...');
  metroProcess = spawn('npx', ['react-native', 'start', '--reset-cache'], {
    cwd: __dirname,
    shell: true,
    stdio: 'inherit'
  });

  // Wait for Metro to be ready, then load
  setTimeout(() => {
    const url = 'http://localhost:8081/index.bundle?platform=web&dev=true';
    console.log('Loading app from:', url);
    mainWindow.loadURL(url).catch(err => {
      console.error('Failed to load:', err);
      mainWindow.loadFile('index.html');
    });
  }, 8000);
  
  mainWindow.on('closed', () => {
    if (metroProcess) {
      metroProcess.kill();
    }
  });
}

app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    if (metroProcess) {
      metroProcess.kill();
    }
    app.quit();
  }
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow();
  }
});
""")
    print("Created: electron-main.js")
    
    # Update package.json
    package_json = os.path.join(project_dir, 'package.json')
    with open(package_json, 'r', encoding='utf-8') as f:
        package_data = json.load(f)
    
    if 'main' not in package_data:
        package_data['main'] = 'electron-main.js'
    
    if 'scripts' not in package_data:
        package_data['scripts'] = {}
    
    package_data['scripts']['electron'] = 'electron .'
    package_data['scripts']['electron:build'] = 'electron-builder'
    package_data['scripts']['electron:pack'] = 'electron-packager . DualReader --platform=win32 --arch=x64 --out=dist'
    
    # Add build configuration
    package_data['build'] = {
        'appId': 'com.dualreader.app',
        'productName': 'Dual Reader',
        'directories': {
            'output': 'dist'
        },
        'files': [
            '**/*',
            '!node_modules/**/*',
            '!dist/**/*'
        ],
        'win': {
            'target': ['nsis', 'portable'],
            'icon': 'assets/icon.ico'
        }
    }
    
    with open(package_json, 'w', encoding='utf-8') as f:
        json.dump(package_data, f, indent=2)
    print("Updated package.json")
    
    # Create a simple HTML wrapper as fallback
    html_wrapper = os.path.join(project_dir, 'index.html')
    with open(html_wrapper, 'w', encoding='utf-8') as f:
        f.write("""<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Dual Reader</title>
    <style>
        body {
            margin: 0;
            padding: 20px;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #1a1a1a;
            color: #fff;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        h1 { color: #4a9eff; }
        .info { background: #2a2a2a; padding: 20px; border-radius: 8px; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Dual Reader 3.0</h1>
        <div class="info">
            <h2>Windows Desktop App</h2>
            <p>To run the app:</p>
            <ol>
                <li>Open terminal in this directory</li>
                <li>Run: <code>npm start</code> (starts Metro bundler)</li>
                <li>Run: <code>npm run electron</code> (starts Electron app)</li>
            </ol>
            <p>Or build executable:</p>
            <ul>
                <li><code>npm run electron:pack</code> - Creates portable app in dist/</li>
                <li><code>npm run electron:build</code> - Creates installer</li>
            </ul>
        </div>
    </div>
</body>
</html>
""")
    print(f"Created: index.html")
    
    # Try to build Electron app
    print("\n[Building] Creating Electron executable...")
    build_result = subprocess.run(
        ['npm', 'run', 'electron:pack'],
        cwd=project_dir,
        capture_output=True,
        timeout=600,
        text=True,
        shell=use_shell
    )
    
    if build_result.returncode == 0:
        print("[SUCCESS] Electron executable created in dist/")
        dist_dir = os.path.join(project_dir, 'dist')
        if os.path.exists(dist_dir):
            exe_files = []
            for root, dirs, files in os.walk(dist_dir):
                for file in files:
                    if file.endswith('.exe'):
                        exe_files.append(os.path.join(root, file))
            if exe_files:
                print(f"\n[SUCCESS] Found {len(exe_files)} executable(s):")
                for exe in exe_files:
                    print(f"  - {exe}")
    else:
        print(f"[INFO] Electron build output: {build_result.stdout[:500]}")
        print(f"[INFO] You can still run the app with: npm run electron")
    
    print("\n=== Build Complete ===")
    print("\nTo run the app:")
    print("  1. npm start  (in one terminal)")
    print("  2. npm run electron  (in another terminal)")
    print("\nOr use the executable in dist/ directory if build succeeded")

if __name__ == "__main__":
    main()

