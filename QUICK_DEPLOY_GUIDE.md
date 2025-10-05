# 🚀 Quick Deploy Guide - Attendo Web App

## Every Time You Want to Deploy an Update

### **Step 1: Update Version (30 seconds)**

**File 1:** `web/index.html` (line 99-100)
```javascript
const APP_VERSION = '1.0.1'; // ← Change this!
const AUTO_UPDATE_ENABLED = true; // ← Enable for updates (false for dev)
```

**File 2:** `web/service-worker.js` (line 2)
```javascript
const CACHE_VERSION = 'v1.0.1'; // ← Match the version!
```

---

### **Step 2: Build (2-3 minutes)**
```bash
flutter build web --release
```

---

### **Step 3: Deploy (1-2 minutes)**
```bash
firebase deploy --only hosting
```

---

### **Step 4: Verify (30 seconds)**
1. Open your web app URL in browser
2. Open Console (F12)
3. Look for: `✅ v1.0.1 - Latest version`

---

## ✅ That's It!

Students will **automatically** get the new version when they open the app!

- No manual refresh needed
- Cache cleared automatically
- Always shows latest version

---

## 🎯 Version Numbering

- **1.0.0** → **1.0.1** = Bug fixes
- **1.0.1** → **1.1.0** = New features
- **1.1.0** → **2.0.0** = Major changes

---

## 🐛 If Something Goes Wrong

### Students seeing old version?
```bash
# Hard refresh
Ctrl+Shift+R (Windows/Linux)
Cmd+Shift+R (Mac)
```

### Need to rollback?
1. Change version back to previous
2. Run `flutter build web --release`
3. Run `firebase deploy --only hosting`

---

## 📞 Quick Commands

```bash
# Test locally before deploying
flutter run -d chrome

# Clean build (if issues)
flutter clean
flutter pub get
flutter build web --release

# Deploy
firebase deploy --only hosting

# Check deployment
firebase hosting:channel:list
```

---

**Remember**: Always update BOTH version numbers (index.html AND service-worker.js)!
