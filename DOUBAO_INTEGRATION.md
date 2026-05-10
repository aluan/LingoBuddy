# Doubao SDK Integration - Configuration Guide

## Overview

The Doubao SDK has been successfully integrated into LingoBuddy. The iOS app now connects directly to Doubao's cloud service for voice interactions, while the backend handles data persistence via REST APIs.

## What Changed

### iOS App
- ✅ Added CocoaPods with `SpeechEngineToB` SDK (v0.0.14.6)
- ✅ Created Objective-C bridging header for SDK access
- ✅ Implemented `DoubaoVoiceClient` wrapping the SDK
- ✅ Created `VoiceSessionService` for backend REST API calls
- ✅ Updated `SpeakView` to use new voice client
- ✅ Added `DoubaoConfig.swift` for credential management (pure Swift, no Objective-C needed!)

### Backend
- ✅ Removed WebSocket voice proxy (`voice-realtime.server.ts` → backed up)
- ✅ Removed GLM configuration (`glm-session-config.ts` → backed up)
- ✅ Added REST endpoints for voice sessions
- ✅ Updated environment variables (removed GLM-specific vars)
- ✅ Updated documentation

## Required Configuration

### Step 1: Credentials are Already Configured! ✅

Your Doubao credentials are already set up in `LingoBuddyApp/Config/DoubaoConfig.swift`:

```swift
struct DoubaoConfig {
    static let appId = "3726144181"
    static let appKey = "PlgvMymc7f3tQnJ6"
    static let token = "ii5GD5xL8FbOzqkNuFTyhmrhkKbNXV7Q"
    static let resourceId = "volc.speech.dialog"
    static let address = "wss://openspeech.bytedance.com"
    static let uri = "/api/v3/realtime/dialogue"
    static let botName = "Astra"
    static let backendBaseURL = "http://localhost:3000"
}
```

**Note:** This file is in `.gitignore` to protect your credentials. A template file (`DoubaoConfig.swift.template`) is provided for other developers.

### Step 2: Update Backend URL for Device Testing (Optional)

When testing on a physical device, update the `backendBaseURL` in `DoubaoConfig.swift`:

```swift
static let backendBaseURL = "http://192.168.3.17:3000"  // Use your Mac's local IP
```

The Doubao SDK uses an AEC (Acoustic Echo Cancellation) model for better audio quality. 

**Option A: If you have the aec.model file**
1. Add `aec.model` to your Xcode project
2. Ensure it's included in the app bundle (check "Target Membership")

**Option B: If you don't have the file**
The SDK may work without it, but audio quality might be reduced. Check Volcengine documentation for obtaining the AEC model.

### Step 3: Configure Xcode Project

**Important:** You must now use the `.xcworkspace` file instead of `.xcodeproj`:

```bash
open LingoBuddy.xcworkspace
```

**Configure Bridging Header:**
1. Open Xcode project settings
2. Go to Build Settings → Swift Compiler - General
3. Set "Objective-C Bridging Header" to: `LingoBuddyApp/LingoBuddy-Bridging-Header.h`

### Step 4: Update Backend URL for Device Testing

When testing on a physical device, update the backend URL in Info.plist:

```xml
<key>BackendBaseURL</key>
<string>http://192.168.3.17:3000</string>  <!-- Use your Mac's local IP -->
```

## Testing

### 1. Start Backend
```bash
cd backend
npm run start:dev
```

Expected output:
```
LingoBuddy API listening on http://0.0.0.0:3000
LAN API reachable at http://192.168.x.x:3000
```

### 2. Run iOS App
```bash
open LingoBuddy.xcworkspace
```

Then build and run in Xcode (⌘R)

### 3. Test Voice Flow
1. Tap "Start Talking" on home screen
2. Tap "Start Call" button
3. Grant microphone permission if prompted
4. Speak in English
5. Listen to Astra's response
6. Tap "End Call" when done

### 4. Verify Data Persistence
Check that conversations are saved in MongoDB:
```bash
mongosh lingobuddy
db.conversations.find().pretty()
db.messages.find().pretty()
```

## Troubleshooting

### "Failed to create speech engine"
- Verify all credentials in Info.plist are correct
- Check that you're using the `.xcworkspace` file
- Ensure bridging header is configured correctly

### "Microphone permission denied"
- Check Info.plist has `NSMicrophoneUsageDescription`
- Reset permissions: Settings → Privacy → Microphone → LingoBuddy

### "Failed to start session"
- Verify backend is running on port 3000
- Check `BackendBaseURL` in Info.plist matches your backend
- For device testing, use your Mac's local IP address

### "AEC model not found"
- Add `aec.model` file to Xcode project
- Or continue without it (reduced audio quality)

### Backend errors
- Ensure MongoDB is running: `docker compose up -d mongodb`
- Ensure Redis is running: `docker compose up -d redis`
- Check backend logs for specific errors

## Architecture

### Before (WebSocket)
```
iOS App → WebSocket → Backend → GLM API
         ← WebSocket ←         ← 
```

### After (Direct + REST)
```
iOS App → Doubao SDK → Doubao Cloud
        ↓ REST API ↓
        Backend (MongoDB/Redis)
```

## API Endpoints

The backend now provides REST endpoints for voice sessions:

- `POST /voice/sessions/start` - Start a new voice session
- `POST /voice/sessions/:id/transcript` - Save user/assistant transcript
- `POST /voice/sessions/:id/reward` - Grant stars for speaking
- `POST /voice/sessions/:id/end` - End session and save conversation

## Files Modified

### Created
- `Podfile` - CocoaPods configuration
- `LingoBuddyApp/LingoBuddy-Bridging-Header.h` - Objective-C bridge
- `LingoBuddyApp/Services/DoubaoVoiceClient.swift` - Voice client wrapper
- `LingoBuddyApp/Services/VoiceSessionService.swift` - REST API client
- `backend/src/voice/voice-session.controller.ts` - REST endpoints
- `backend/src/voice/voice-session.service.ts` - Session management

### Modified
- `LingoBuddyApp/Views/SpeakView.swift` - Uses DoubaoVoiceClient
- `LingoBuddyApp/Info.plist` - Added Doubao configuration
- `backend/src/app.module.ts` - Replaced WebSocket with REST
- `backend/src/main.ts` - Removed WebSocket server
- `backend/.env.example` - Removed GLM variables
- `backend/README.md` - Updated documentation

### Backed Up (Not Deleted)
- `backend/src/voice/voice-realtime.server.ts.backup` - Old WebSocket server
- `backend/src/voice/glm-session-config.ts.backup` - Old GLM config

## Next Steps

1. **Get Doubao Credentials**: Obtain from Volcengine console
2. **Update Info.plist**: Add your credentials
3. **Test in Simulator**: Verify basic functionality
4. **Test on Device**: Verify with real microphone/speaker
5. **Production**: Consider using Keychain for credential storage

## Support

- Doubao SDK Documentation: https://www.volcengine.com/docs/6561/1597646
- Reference Implementation: `/Users/aluan/Desktop/SpeechDemoIOS/SpeechDemo/DialogViewController.m`
