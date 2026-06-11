# Dual Reader — Open Questions

<!-- Add questions here when ambiguity is encountered. User should answer and then items can proceed. -->

## DR-007: Play Store Launch — Needs User Input

Splash screen is implemented. The following items need your input to proceed:

1. **Privacy Policy URL** — Do you have a privacy policy hosted? The app needs a URL to link in Settings and Play Console. If not, I can generate a basic one.

2. **Content Rating** — This is done in the Play Console questionnaire. No code needed, but you'll need to fill it out when submitting.

3. **Play Store Listing Assets** — Need:
   - App description (short + full)
   - Screenshots (phone 16:9 or 18:9, tablet if targeting)
   - Feature graphic (1024×500 PNG)
   - Do you want to provide these, or should I draft placeholder text?

4. **Release Keystore** — The build currently signs with debug keystore. For Play Store you need a release keystore. Should I:
   - (a) Generate a release keystore using `keytool` (you'll need to securely back it up)
   - (b) Use App signing by Google Play (Google manages the key)

5. **R8/ProGuard Verification** — Should I do a release build and verify R8 rules work? This would confirm no obfuscation crashes.
