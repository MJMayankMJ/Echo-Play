//
//  PlayerViewController.swift
//  Echo Play
//
//  Created by Mayank Jangid on 3/13/25.
//

import UIKit
import AVFoundation
import AVKit

class PlayerViewController: UIViewController {
    
    var allSongURLs: [URL] = []
    var currentIndex: Int = 0
    
    var audioURL: URL? {
        guard currentIndex < allSongURLs.count else { return nil }
        return allSongURLs[currentIndex]
    }
    
    // MARK: - Outlets
    @IBOutlet weak var slider: UISlider!
    @IBOutlet weak var currentTimeLabel: UILabel!
    @IBOutlet weak var totalTimeLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var playPauseButton: UIButton!
    
    var isSliderDragging = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        AudioPlayerManager.shared.delegate = self
        
        slider.minimumValue = 0
        slider.value = 0
        
        // Add observers for remote command notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNextTrackNotification),
            name: .didRequestNextTrack,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePreviousTrackNotification),
            name: .didRequestPreviousTrack,
            object: nil
        )
        
        // Start playing the selected track
        if audioURL != nil {
            playCurrentIndex()
        }
        
        updateUI()
        updateThumbnail()
    }
    
    @objc private func handleNextTrackNotification() {
        // Make sure there is a next track available
        if currentIndex < allSongURLs.count - 1 {
            currentIndex += 1
            playCurrentIndex()
        }
    }
    
    @objc private func handlePreviousTrackNotification() {
        // Make sure there is a previous track available
        if currentIndex > 0 {
            currentIndex -= 1
            playCurrentIndex()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Slider Interaction
    @IBAction func sliderTouchDown(_ sender: UISlider) {
        isSliderDragging = true
    }
    
    @IBAction func sliderTouchUp(_ sender: UISlider) {
        isSliderDragging = false
        AudioPlayerManager.shared.seek(to: TimeInterval(sender.value))
    }
    
    // MARK: - Playback Controls
    @IBAction func playPauseTapped(_ sender: UIButton) {
        if AudioPlayerManager.shared.isPlaying {
            AudioPlayerManager.shared.pause()
        } else {
            AudioPlayerManager.shared.play()
        }
        updatePlayPauseButton()
    }
    
    @IBAction func prevTapped(_ sender: UIButton) {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        playCurrentIndex()
    }
    
    @IBAction func nextTapped(_ sender: UIButton) {
        guard currentIndex < allSongURLs.count - 1 else { return }
        currentIndex += 1
        playCurrentIndex()
    }
    
    // MARK: - Play Current Track + Update Title
    private func playCurrentIndex() {
        guard let url = audioURL else { return }
        
        // Start playing
        AudioPlayerManager.shared.playSound(from: url)
        
        // Asynchronously extract the title from ID3 metadata and update the manager
        Task {
            let asset = AVURLAsset(url: url)
            if let trackTitle = await extractTitle(from: asset) {
                AudioPlayerManager.shared.audioTitle = trackTitle
            } else {
                AudioPlayerManager.shared.audioTitle = "Unknown Title"
            }
            
            // Update lock screen / notification center
            AudioPlayerManager.shared.updateNowPlayingInfo()
            
            // Update the in-app UI on the main thread
            await MainActor.run {
                self.titleLabel.text = AudioPlayerManager.shared.audioTitle
            }
        }
        
        // Reset slider and labels
        slider.value = 0
        currentTimeLabel.text = "00:00"
        
        // Update other UI
        updateUI()
        updateThumbnail()
    }
    
    // MARK: - Extract Title via Async ID3
    private func extractTitle(from asset: AVURLAsset) async -> String? {
        do {
            let metadataItems = try await asset.loadMetadata(for: .id3Metadata)
            for item in metadataItems {
                if let key = item.commonKey, key == .commonKeyTitle {
                    if let titleValue = try await item.load(.stringValue)  {
                        return titleValue
                    }
                }
            }
        } catch {
            print("Error extracting title: \(error)")
        }
        return nil
    }
    
    // MARK: - UI Updates
    private func updateUI() {
        let duration = AudioPlayerManager.shared.getDuration()
        slider.maximumValue = Float(duration)
        totalTimeLabel.text = formatTime(duration)
        
        // Use the manager’s audioTitle
        titleLabel.text = AudioPlayerManager.shared.audioTitle
        updatePlayPauseButton()
    }
    
    private func updatePlayPauseButton() {
        let imageName = AudioPlayerManager.shared.isPlaying ? "pause.fill" : "play.fill"
        playPauseButton.setImage(UIImage(systemName: imageName), for: .normal)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Thumbnail Artwork
    private func updateThumbnail() {
        guard let url = audioURL else {
            thumbnailImageView.image = UIImage(systemName: "music.note")
            return
        }
        let asset = AVURLAsset(url: url)
        Task {
            if let artwork = await extractArtwork(from: asset) {
                await MainActor.run {
                    self.thumbnailImageView.image = artwork
                }
            } else {
                await MainActor.run {
                    self.thumbnailImageView.image = UIImage(systemName: "music.note")
                }
            }
        }
    }
    
    private func extractArtwork(from asset: AVAsset) async -> UIImage? {
        do {
            let metadataItems = try await asset.loadMetadata(for: .id3Metadata)
            for item in metadataItems {
                if let key = item.commonKey, key == .commonKeyArtwork {
                    if let data = try await item.load(.dataValue),
                       let image = UIImage(data: data) {
                        return image
                    }
                }
            }
        } catch {
            print("Error extracting artwork: \(error)")
        }
        return nil
    }
}

// MARK: - AudioPlayerManagerDelegate
extension PlayerViewController: AudioPlayerManagerDelegate {
    func audioPlayerManagerDidChangeState(_ manager: AudioPlayerManager) {
        // Update the in-app title label from the manager’s audioTitle
        titleLabel.text = manager.audioTitle
        updatePlayPauseButton()
    }
    
    func audioPlayerManager(_ manager: AudioPlayerManager, didUpdateDuration currentTime: TimeInterval) {
        // Only update the slider if the user isn't dragging it
        if !isSliderDragging {
            slider.value = Float(currentTime)
        }
        currentTimeLabel.text = formatTime(currentTime)
        
        let total = manager.getDuration()
        totalTimeLabel.text = formatTime(total)
    }
    
    func audioPlayerManagerDidComplete(_ manager: AudioPlayerManager) {
        slider.value = 0
        currentTimeLabel.text = "00:00"
    }
}
