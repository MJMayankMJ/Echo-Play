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
    // Which song index is currently playing
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
        
        // Start playing the selected track
        if let url = audioURL {
            AudioPlayerManager.shared.playSound(from: url)
        } else {
            // ... fallback
        }
        
        updateUI()
        updateThumbnail()
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
    
    private func playCurrentIndex() {
        if let url = audioURL {
            AudioPlayerManager.shared.playSound(from: url)
        }
        // Reset slider
        slider.value = 0
        currentTimeLabel.text = "00:00"
        updateUI()
        updateThumbnail()
    }
    
    // MARK: - UI Updates
    
    private func updateUI() {
        // Update the max slider value to the new track’s duration
        let duration = AudioPlayerManager.shared.getDuration()
        slider.maximumValue = Float(duration)
        totalTimeLabel.text = formatTime(duration)
        
        // Update the title label to the manager’s audioTitle
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
