# NDI Viewer for macOS

A native SwiftUI macOS application that discovers NDI sources, connects to a selected source, and displays received video.

## Requirements

- macOS 14 or later
- Xcode 16 or later (the project is set to Swift 6)
- The official NDI SDK for Apple/macOS
- An NDI-enabled camera on the same reachable network

## Setup

1. Download and install the official NDI SDK from NDI.
2. In Terminal, change to this project directory and run:

   ```bash
   ./Scripts/configure-ndi.sh
   ```

3. Open `NDIViewer.xcodeproj`.
4. Select your development team under **Signing & Capabilities** if Xcode requests it.
5. Build and run.
6. When macOS asks for Local Network access, click **Allow**.
7. Select the camera's NDI source name and click **Connect**.

## PTZOptics camera setup

- Connect the Mac and camera to the same Ethernet network or to interfaces with working IP routing.
- Enable NDI output in the camera's web interface.
- For initial testing, use NDI Video Monitor from NDI Tools to confirm that the camera itself is transmitting.
- The source may appear under a model/hostname and channel name rather than simply the camera's IP address.

## Architecture

- SwiftUI provides the application UI and source picker.
- `NDIClient.mm` is an Objective-C++ bridge to the official C NDI SDK.
- Source discovery uses the NDI finder API.
- Video reception uses `NDIlib_recv_create_v3` and `NDIlib_recv_capture_v3`.
- Frames are requested as BGRX/BGRA, copied into a `CGImage`, and presented by SwiftUI.

This first implementation favors correctness and simplicity. For prolonged 4K/60 operation, replace the per-frame `CGImage` copy with a Metal texture renderer.

## Troubleshooting

### Header not found

Run `Scripts/configure-ndi.sh`, or edit `Config/NDIConfig.xcconfig` so `NDI_SDK_DIR` points to the folder containing `include/Processing.NDI.Lib.h`.

### Library not loaded

Confirm that the app bundle contains `Contents/Frameworks/libndi.dylib`. The Embed NDI Runtime build phase copies and signs it.

### No sources found

- Confirm macOS Local Network permission under **System Settings > Privacy & Security > Local Network**.
- Confirm the camera stream appears in NDI Video Monitor.
- Check that the Mac and camera are on the same subnet, or configure NDI Discovery Server / extra IP discovery for routed networks.
- Temporarily disable VPN software and restrictive firewalls while testing.

### Architecture mismatch

Use an NDI SDK runtime containing the architecture of the Mac: `arm64` for Apple silicon and `x86_64` for Intel.
