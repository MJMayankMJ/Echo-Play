# Echo Play

This project is a simple iOS Music Player App that demonstrates how to use AVFoundation and MediaPlayer frameworks to play audio, update now playing information, and handle remote commands (e.g., Next/Previous track on the lock screen).
![Echo Play](https://github.com/user-attachments/assets/332304f9-905f-4a24-9feb-076d8dbba0d2)

## Features

- **Playback Controls:** Play, pause, next, and previous track functionality.
- **Remote Commands:** Integration with `MPRemoteCommandCenter` for lock screen/notification controls.
- **Now Playing Info:** Updates now playing information (title, artist, album, artwork) on the lock screen.
- **Async Metadata Extraction:** Uses iOS 16+ async/await APIs for extracting ID3 metadata (title and artwork).
- **User Interface:** Includes a slider for tracking playback, title label, thumbnail image view, and play/pause button.

## Requirements

- iOS 16.0+
- Xcode 14+
- Swift 5+

**Note:** In this project my fill attention was to learn these new things but the code is quite re used and is not properly maintained in any form of arch. ; But you would find the comments quite helpful
