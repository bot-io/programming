# Dual Reader — Open Questions

<!-- Add questions here when ambiguity is encountered. User should answer and then items can proceed. -->

## DR-007: Play Store Launch Preparation — Blocked Items

**Date:** 2026-06-11
**Status:** Needs user input to unblock

Technical items are done (splash screen ✅, adaptive icon ✅, ProGuard rules ✅, 356 tests green). The following need your input:

### 1. Privacy Policy URL (AC 3)
- Need a privacy policy page hosted at a public URL
- The URL will be linked in the app (Settings → About) and in Play Console
- **Question:** Where should the privacy policy be hosted? (GitHub Pages, a dedicated domain, etc.)
- Also: what data does the app collect? (Currently: no analytics, no personal data — only EPUB files you import and translation cache stored locally)

### 2. Content Rating Questionnaire (AC 4)
- Requires Play Console access to fill out the IARC questionnaire
- **Question:** Do you have Play Console access set up?

### 3. Play Store Listing — Creative Assets (AC 5)
- Need: app description, 2–8 screenshots (phone), optional tablet screenshots, feature graphic (1024×500)
- **Question:** Want to create these yourself or should I draft description text and you handle screenshots?

### 4. Release Signing Keystore (AC 6)
- Currently using debug keystore for builds
- Need to generate a release keystore and back it up securely
- **Question:** Should I generate the keystore via command line and store the passwords for you, or do you prefer to do this manually?
- ⚠️ **Critical:** The keystore password and key password must be saved securely — losing the keystore means you can never update the app on Play Store

### Previous Open Questions
*(None from previous sessions)*
