# Deploy ScalePod AI to GitHub Pages

## Quick Deploy (5 minutes)

### Step 1: Create GitHub Repo

Go to https://github.com/new and create a new repo:
- **Name:** `scalepod-ai` (or `scalepod.ai`)
- **Visibility:** Public (required for free GitHub Pages)
- **DO NOT** initialize with README, .gitignore, or license

### Step 2: Push from your terminal

Open PowerShell/Terminal in this folder (`scalepod-ai/website-deploy/`) and run:

```powershell
cd C:\Users\Owner\Documents\EtsyAutomation\scalepod-ai\website-deploy

# Initialize fresh git repo (if .git folder has issues, delete it first)
rmdir /s /q .git
git init -b main
git add -A
git commit -m "Initial deploy: ScalePod AI landing page"

# Replace YOUR_USERNAME with your GitHub username
git remote add origin https://github.com/YOUR_USERNAME/scalepod-ai.git
git push -u origin main
```

### Step 3: Enable GitHub Pages

1. Go to your repo → **Settings** → **Pages**
2. Under **Source**, select **Deploy from a branch**
3. Branch: `main`, folder: `/ (root)`
4. Click **Save**

Your site will be live at `https://YOUR_USERNAME.github.io/scalepod-ai/` within 1-2 minutes.

### Step 4: Connect Custom Domain (scalepod.ai)

#### In GitHub:
1. Still on **Settings** → **Pages**
2. Under **Custom domain**, type: `scalepod.ai`
3. Click **Save**
4. Check **Enforce HTTPS** (may take a few minutes to become available)

#### At your domain registrar (GoDaddy):
Go to DNS settings for scalepod.ai and add these records:

**A Records** (point to GitHub Pages IPs):
| Type | Name | Value |
|------|------|-------|
| A | @ | 185.199.108.153 |
| A | @ | 185.199.109.153 |
| A | @ | 185.199.110.153 |
| A | @ | 185.199.111.153 |

**CNAME Record** (for www subdomain):
| Type | Name | Value |
|------|------|-------|
| CNAME | www | YOUR_USERNAME.github.io |

DNS propagation takes 5-30 minutes. After that, https://scalepod.ai will be live.

### Step 5: Verify

- [ ] https://scalepod.ai loads the landing page
- [ ] https://www.scalepod.ai redirects to scalepod.ai
- [ ] HTTPS lock icon shows (green padlock)
- [ ] https://scalepod.ai/privacy.html loads
- [ ] https://scalepod.ai/terms.html loads
- [ ] Hero image loads correctly
- [ ] All showcase images load

## Files in this deploy

```
website-deploy/
├── CNAME              ← Custom domain config (scalepod.ai)
├── .nojekyll          ← Skip Jekyll processing
├── index.html         ← Landing page (49KB)
├── privacy.html       ← Privacy policy (19KB)
├── terms.html         ← Terms of service (10KB)
└── images/
    ├── hero-mirror.jpg           ← Hero image (196KB)
    └── showcase/
        ├── fox-lifestyle.jpg     ← 77KB
        ├── fox-closeup.jpg       ← 90KB
        ├── fox-detail.jpg        ← 108KB
        ├── serpent-lifestyle.jpg  ← 128KB
        ├── serpent-closeup.jpg    ← 91KB
        ├── serpent-back.jpg       ← 851KB
        ├── owl-lifestyle.jpg      ← 120KB
        ├── owl-closeup.jpg        ← 91KB
        └── owl-detail.jpg         ← 91KB

Total: ~2MB (fast loading, no build step needed)
```

## Updating the site later

```powershell
cd C:\Users\Owner\Documents\EtsyAutomation\scalepod-ai\website-deploy
# Make your changes, then:
git add -A
git commit -m "Update: description of changes"
git push
```

GitHub Pages auto-deploys on push — changes go live in ~60 seconds.
