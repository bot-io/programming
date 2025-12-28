## Configuration Summary

### 1. iOS minimum deployment target: 12.0
- Podfile: `platform :ios, '12.0'`
- Xcode project: `IPHONEOS_DEPLOYMENT_TARGET = 12.0` in Debug, Release, and Profile

### 2. Info.plist permissions

File access:
- `NSDocumentsFolderUsageDescription` — access documents folder for ebook import
- `NSDownloadsFolderUsageDescription` — access downloads folder for ebook import
- `UIFileSharingEnabled` — file sharing enabled
- `LSSupportsOpeningDocumentsInPlace` — open documents in place
- `UISupportsDocumentBrowser` — document browser support

Network:
- `NSAppTransportSecurity` — configured with:
  - `NSAllowsArbitraryLoads = false` (security best practice)
  - `NSAllowsLocalNetworking = true` (for local network access if needed)
  - Exception domains for translation APIs (libretranslate.com, mymemory.translated.net) with HTTPS-only

### 3. Build configuration

Simulator support:
- Debug configuration allows simulator builds (no `SUPPORTED_PLATFORMS` restriction)

Device deployment:
- Release and Profile configurations set `SUPPORTED_PLATFORMS = iphoneos`
- `TARGETED_DEVICE_FAMILY = "1,2"` (iPhone and iPad)

## Acceptance criteria met

- iOS minimum deployment target set to 12.0
- Required permissions added to Info.plist (file access, network)
- iOS app builds and runs on simulator (Debug configuration)
- Build configuration supports device deployment (Release/Profile configurations)

The iOS platform settings are configured and ready for building and deployment. The app can:
- Build and run on iOS Simulator (Debug)
- Build for physical devices (Release/Profile)
- Access files from Documents and Downloads folders
- Make secure network requests to translation APIs
- Support both iPhone and iPad devices