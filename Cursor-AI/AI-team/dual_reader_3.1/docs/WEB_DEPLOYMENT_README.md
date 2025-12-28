# Web Build and Deployment - README

## Overview

This document provides an overview of the web build and deployment setup for Dual Reader 3.1.

## Quick Start

### Build the Web App

**Linux/Mac:**
```bash
./scripts/build_web.sh
```

**Windows:**
```powershell
.\scripts\build_web.ps1
```

### Deploy to Platform

**GitHub Pages:**
```bash
./scripts/deploy_github_pages.sh
```

**Netlify:**
```bash
./scripts/deploy_netlify.sh --production
```

**Vercel:**
```bash
./scripts/deploy_vercel.sh --production
```

## What's Included

### ✅ Optimized Build Configuration

- Production-optimized builds with tree-shaking
- CanvasKit renderer for better performance
- Icon tree-shaking to reduce bundle size
- Configurable base href for different deployment paths

### ✅ PWA Support

- Complete PWA manifest with all required fields
- Service worker for offline support
- Installable as Progressive Web App
- Works offline after first visit

### ✅ Deployment Scripts

- Build scripts for Linux/Mac and Windows
- Deployment scripts for GitHub Pages, Netlify, and Vercel
- Automated verification and error handling
- Dry-run mode for testing

### ✅ Documentation

- Complete deployment guide
- Quick reference guide
- Acceptance criteria verification
- Troubleshooting guide

### ✅ Automation

- GitHub Actions workflow for automated deployment
- Automated builds on push
- Manual deployment option

## File Structure

```
.
├── web/
│   ├── index.html              # Main HTML file with PWA support
│   ├── manifest.json           # PWA manifest
│   ├── service-worker.js       # Reference service worker
│   ├── vercel.json            # Vercel configuration
│   ├── _headers               # Netlify headers
│   └── icons/                 # PWA icons
├── netlify.toml               # Netlify configuration
├── scripts/
│   ├── build_web.sh/.ps1     # Build scripts
│   ├── deploy_github_pages.sh/.ps1
│   ├── deploy_netlify.sh/.ps1
│   └── deploy_vercel.sh/.ps1
├── .github/workflows/
│   └── deploy-web.yml         # GitHub Actions workflow
└── docs/
    ├── WEB_DEPLOYMENT_GUIDE.md
    ├── WEB_DEPLOYMENT_QUICK_REFERENCE.md
    ├── WEB_BUILD_ACCEPTANCE_CRITERIA.md
    └── WEB_DEPLOYMENT_README.md (this file)
```

## Prerequisites

- Flutter SDK (latest stable)
- Git (for GitHub Pages)
- Node.js (for Netlify/Vercel CLI)
- Platform-specific CLI tools (optional, scripts handle installation)

## Build Output

After building, the output is in `build/web/`:

```
build/web/
├── index.html
├── manifest.json
├── flutter.js
├── main.dart.js
├── flutter_service_worker.js
├── icons/
├── assets/
└── canvaskit/
```

## Testing Locally

```bash
# Build the app
./scripts/build_web.sh

# Start local server
cd build/web
python3 -m http.server 8000

# Open in browser
# http://localhost:8000
```

## Deployment Platforms

### GitHub Pages

- **Free** for public repositories
- **Automatic HTTPS**
- **Custom domain support**
- **GitHub Actions integration**

### Netlify

- **Free tier available**
- **Automatic HTTPS**
- **Custom domain support**
- **Continuous deployment**
- **Form handling and serverless functions**

### Vercel

- **Free tier available**
- **Automatic HTTPS**
- **Custom domain support**
- **Continuous deployment**
- **Edge network**

## PWA Features

- ✅ Installable on desktop and mobile
- ✅ Works offline
- ✅ App-like experience
- ✅ Fast loading
- ✅ Responsive design

## Support

For detailed information, see:
- [Complete Deployment Guide](WEB_DEPLOYMENT_GUIDE.md)
- [Quick Reference](WEB_DEPLOYMENT_QUICK_REFERENCE.md)
- [Acceptance Criteria](WEB_BUILD_ACCEPTANCE_CRITERIA.md)

## License

See main project LICENSE file.
