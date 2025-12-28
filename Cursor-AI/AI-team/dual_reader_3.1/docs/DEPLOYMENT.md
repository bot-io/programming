# Web Build and Deployment Guide

Complete guide for building and deploying Dual Reader 3.1 web app to various hosting platforms.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Building the Web App](#building-the-web-app)
3. [Local Testing](#local-testing)
4. [Deployment Platforms](#deployment-platforms)
   - [GitHub Pages](#github-pages)
   - [Netlify](#netlify)
   - [Vercel](#vercel)
   - [Firebase Hosting](#firebase-hosting)
   - [Custom Server](#custom-server)
5. [PWA Verification](#pwa-verification)
6. [Troubleshooting](#troubleshooting)

## Prerequisites

- Flutter SDK (latest stable version)
- Git (for version control)
- Node.js (for some deployment platforms)
- Account on your chosen hosting platform

## Building the Web App

### Quick Build

**Windows (PowerShell):**
```powershell
.\web\build_web.ps1
```

**Linux/macOS:**
```bash
./web/build_web.sh
```

### Build Options

**Windows:**
```powershell
# Debug build
.\web\build_web.ps1 -Release:$false

# Build with analysis
.\web\build_web.ps1 -Analyze

# Build with tests
.\web\build_web.ps1 -Test

# Custom base href (for subdirectory deployment)
.\web\build_web.ps1 -BaseHref "/dual-reader/"
```

**Linux/macOS:**
```bash
# Debug build
./web/build_web.sh --debug

# Build with analysis
./web/build_web.sh --analyze

# Build with tests
./web/build_web.sh --test

# Custom base href
./web/build_web.sh --base-href "/dual-reader/"
```

### Manual Build

```bash
# Get dependencies
flutter pub get

# Build for production
flutter build web --release \
  --base-href / \
  --tree-shake-icons \
  --web-renderer canvaskit

# Build output is in: build/web/
```

### Build Optimizations

The build script automatically applies these optimizations:

- **Tree-shaking**: Removes unused code and icons
- **CanvasKit renderer**: Better performance and compatibility
- **Minification**: Reduces JavaScript bundle size
- **Code splitting**: Improves initial load time

## Local Testing

### Test Build Locally

1. **Start a local server:**

   **Python 3:**
   ```bash
   cd build/web
   python3 -m http.server 8000
   ```

   **Python 2:**
   ```bash
   cd build/web
   python -m SimpleHTTPServer 8000
   ```

   **Node.js (http-server):**
   ```bash
   npm install -g http-server
   cd build/web
   http-server -p 8000
   ```

2. **Open in browser:**
   ```
   http://localhost:8000
   ```

3. **Test PWA features:**
   - Open Chrome DevTools (F12)
   - Go to Application tab
   - Check Service Worker status
   - Test "Add to Home Screen"
   - Test offline functionality

### Verify PWA Installation

1. Open the app in Chrome/Edge
2. Look for install prompt or use browser menu
3. Click "Install" or "Add to Home Screen"
4. Verify app opens in standalone mode
5. Test offline functionality

## Deployment Platforms

### GitHub Pages

#### Setup

1. **Enable GitHub Pages:**
   - Go to repository Settings → Pages
   - Select source branch (usually `gh-pages` or `main`)
   - Select folder: `/ (root)` or `/docs`

2. **Configure base href:**
   ```bash
   # If deploying to root
   flutter build web --release --base-href / --tree-shake-icons --web-renderer canvaskit

   # If deploying to subdirectory (e.g., /dual-reader/)
   flutter build web --release --base-href /dual-reader/ --tree-shake-icons --web-renderer canvaskit
   ```

3. **Deploy using GitHub Actions:**
   - The workflow is already configured in `.github/workflows/deploy-web.yml`
   - Push to `master` or `main` branch to trigger deployment
   - Or manually trigger from Actions tab

4. **Manual Deployment:**
   ```bash
   # Build the app
   flutter build web --release --base-href / --tree-shake-icons --web-renderer canvaskit

   # Copy build/web/* to gh-pages branch or docs/ folder
   git checkout gh-pages
   cp -r build/web/* .
   git add .
   git commit -m "Deploy web app"
   git push origin gh-pages
   ```

#### Custom Domain

1. Add `CNAME` file to repository root:
   ```
   yourdomain.com
   ```

2. Configure DNS:
   - Add CNAME record pointing to `username.github.io`

#### Notes

- GitHub Pages requires HTTPS (automatic)
- Service workers work on GitHub Pages
- Custom 404 page is included (`web/404.html`)

### Netlify

#### Setup

1. **Connect Repository:**
   - Sign in to Netlify
   - Click "New site from Git"
   - Connect your repository

2. **Configure Build Settings:**
   - Build command: `flutter build web --release --base-href / --tree-shake-icons --web-renderer canvaskit`
   - Publish directory: `build/web`
   - Or use `netlify.toml` (already configured)

3. **Environment Variables (optional):**
   ```
   FLUTTER_VERSION=stable
   FLUTTER_WEB_USE_SKIA=true
   ```

4. **Deploy:**
   - Netlify will automatically build and deploy on push
   - Or use Netlify CLI:
     ```bash
     npm install -g netlify-cli
     netlify deploy --prod --dir=build/web
     ```

#### Configuration

The `netlify.toml` file is already configured with:
- Build settings
- Redirects for SPA routing
- Headers for PWA (service worker, manifest)
- Security headers
- Caching strategies

#### Custom Domain

1. Go to Site settings → Domain management
2. Add custom domain
3. Follow DNS configuration instructions

### Vercel

#### Setup

1. **Install Vercel CLI:**
   ```bash
   npm install -g vercel
   ```

2. **Deploy:**
   ```bash
   # Build first
   flutter build web --release --base-href / --tree-shake-icons --web-renderer canvaskit

   # Deploy
   cd build/web
   vercel --prod
   ```

3. **Connect Repository (for auto-deploy):**
   - Sign in to Vercel
   - Import your repository
   - Configure:
     - Framework Preset: Other
     - Build Command: `flutter build web --release --base-href / --tree-shake-icons --web-renderer canvaskit`
     - Output Directory: `build/web`
     - Install Command: `flutter pub get`

#### Configuration

The `vercel.json` file is already configured with:
- Build settings
- Headers for PWA
- Security headers
- Rewrites for SPA routing

#### Custom Domain

1. Go to Project Settings → Domains
2. Add your domain
3. Configure DNS as instructed

### Firebase Hosting

#### Setup

1. **Install Firebase CLI:**
   ```bash
   npm install -g firebase-tools
   ```

2. **Login:**
   ```bash
   firebase login
   ```

3. **Initialize Firebase:**
   ```bash
   firebase init hosting
   ```
   - Select existing project or create new
   - Public directory: `build/web`
   - Configure as single-page app: Yes
   - Set up automatic builds: Yes (optional)

4. **Create `firebase.json`:**
   ```json
   {
     "hosting": {
       "public": "build/web",
       "ignore": [
         "firebase.json",
         "**/.*",
         "**/node_modules/**"
       ],
       "rewrites": [
         {
           "source": "**",
           "destination": "/index.html"
         }
       ],
       "headers": [
         {
           "source": "/service-worker.js",
           "headers": [
             {
               "key": "Cache-Control",
               "value": "no-cache, no-store, must-revalidate"
             },
             {
               "key": "Service-Worker-Allowed",
               "value": "/"
             }
           ]
         },
         {
           "source": "/flutter_service_worker.js",
           "headers": [
             {
               "key": "Cache-Control",
               "value": "no-cache, no-store, must-revalidate"
             },
             {
               "key": "Service-Worker-Allowed",
               "value": "/"
             }
           ]
         },
         {
           "source": "/manifest.json",
           "headers": [
             {
               "key": "Cache-Control",
               "value": "no-cache, no-store, must-revalidate"
             },
             {
               "key": "Content-Type",
               "value": "application/manifest+json"
             }
           ]
         }
       ]
     }
   }
   ```

5. **Build and Deploy:**
   ```bash
   flutter build web --release --base-href / --tree-shake-icons --web-renderer canvaskit
   firebase deploy --only hosting
   ```

### Custom Server

#### Apache

1. **Copy files to web root:**
   ```bash
   cp -r build/web/* /var/www/html/
   ```

2. **Configure `.htaccess`:**
   - The `web/.htaccess` file is already configured
   - Copy it to your web root

3. **Enable mod_rewrite:**
   ```bash
   sudo a2enmod rewrite
   sudo systemctl restart apache2
   ```

#### Nginx

1. **Copy files to web root:**
   ```bash
   cp -r build/web/* /var/www/html/
   ```

2. **Configure Nginx:**
   ```nginx
   server {
       listen 80;
       server_name yourdomain.com;
       root /var/www/html;
       index index.html;

       # SPA routing
       location / {
           try_files $uri $uri/ /index.html;
       }

       # Service Worker - no cache
       location ~* (service-worker\.js|flutter_service_worker\.js)$ {
           add_header Cache-Control "no-cache, no-store, must-revalidate";
           add_header Service-Worker-Allowed "/";
       }

       # Manifest - no cache
       location ~* manifest\.json$ {
           add_header Cache-Control "no-cache, no-store, must-revalidate";
           add_header Content-Type "application/manifest+json";
       }

       # Security headers
       add_header X-Content-Type-Options "nosniff";
       add_header X-XSS-Protection "1; mode=block";
       add_header X-Frame-Options "SAMEORIGIN";
       add_header Referrer-Policy "strict-origin-when-cross-origin";

       # Cache static assets
       location ~* \.(png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
           expires 1y;
           add_header Cache-Control "public, immutable";
       }

       # Gzip compression
       gzip on;
       gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
   }
   ```

3. **Enable HTTPS (required for PWA):**
   ```bash
   sudo certbot --nginx -d yourdomain.com
   ```

## PWA Verification

### Checklist

- [ ] App installs as PWA
- [ ] Service worker registers successfully
- [ ] App works offline
- [ ] Manifest.json is valid
- [ ] Icons display correctly
- [ ] App opens in standalone mode
- [ ] Shortcuts work (if configured)

### Testing Tools

1. **Chrome DevTools:**
   - Application → Service Workers
   - Application → Manifest
   - Lighthouse → PWA audit

2. **Online Validators:**
   - [Web Manifest Validator](https://manifest-validator.appspot.com/)
   - [PWA Builder](https://www.pwabuilder.com/)

3. **Lighthouse:**
   ```bash
   # Install Lighthouse CLI
   npm install -g lighthouse

   # Run audit
   lighthouse https://your-app-url.com --view
   ```

### Common Issues

**Service Worker Not Registering:**
- Ensure HTTPS is enabled
- Check service worker file exists
- Verify Service-Worker-Allowed header

**PWA Not Installable:**
- Verify manifest.json is valid
- Check all required icons exist
- Ensure start_url is correct
- Verify HTTPS is enabled

**Offline Not Working:**
- Check service worker is active
- Verify caching strategy
- Test in Incognito mode (clear cache)

## Troubleshooting

### Build Fails

**Error: Flutter not found**
```bash
# Add Flutter to PATH
export PATH="$PATH:/path/to/flutter/bin"
```

**Error: Dependencies not found**
```bash
flutter pub get
```

**Error: Build timeout**
- Increase build timeout in CI/CD settings
- Check for large assets that need optimization

### Deployment Fails

**Error: 404 on routes**
- Verify SPA routing is configured
- Check base-href matches deployment path
- Ensure redirects/rewrites are set up

**Error: Service Worker not working**
- Verify HTTPS is enabled
- Check Service-Worker-Allowed header
- Ensure service worker file is accessible

**Error: Assets not loading**
- Check base-href configuration
- Verify asset paths in index.html
- Ensure CORS headers are correct

### Performance Issues

**Large Bundle Size:**
- Enable tree-shaking: `--tree-shake-icons`
- Use code splitting
- Optimize images
- Remove unused dependencies

**Slow Initial Load:**
- Enable compression (gzip/brotli)
- Use CDN for assets
- Implement lazy loading
- Optimize service worker caching

## Additional Resources

- [Flutter Web Documentation](https://docs.flutter.dev/platform-integration/web)
- [PWA Best Practices](https://web.dev/pwa-checklist/)
- [Service Worker API](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API)
- [Web App Manifest](https://developer.mozilla.org/en-US/docs/Web/Manifest)

## Support

For issues or questions:
1. Check [Troubleshooting](#troubleshooting) section
2. Review platform-specific documentation
3. Open an issue on GitHub
