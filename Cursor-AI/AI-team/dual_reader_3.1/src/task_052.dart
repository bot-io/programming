**Deploy to GitHub Pages:**
```bash
./scripts/deploy_github_pages.sh
```

**Deploy to Netlify:**
```bash
netlify login  # First time
./scripts/deploy_netlify.sh
```

**Deploy to Vercel:**
```bash
vercel login  # First time
./scripts/deploy_vercel.sh
```

**Verify Build:**
```bash
./scripts/verify_web_build.sh