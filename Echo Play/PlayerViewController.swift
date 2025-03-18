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
    
    var audioURL: URL?
    
    // MARK: - Outlets
    @IBOutlet weak var slider: UISlider!
    @IBOutlet weak var currentTimeLabel: UILabel!
    @IBOutlet weak var totalTimeLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var thumbnailImageView: UIImageView!  // Displays extracted artwork
    @IBOutlet weak var playPauseButton: UIButton!
    
    // Flag to check if the user is dragging the slider
    var isSliderDragging = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        AudioPlayerManager.shared.delegate = self
        
        slider.minimumValue = 0
        slider.value = 0
        
        let duration = AudioPlayerManager.shared.getDuration()
        slider.maximumValue = Float(duration)
        totalTimeLabel.text = formatTime(duration)
        titleLabel.text = AudioPlayerManager.shared.audioTitle
        
        if let url = audioURL {
            AudioPlayerManager.shared.playSound(from: url)
        } else if let bundledURL = Bundle.main.url(forResource: "YourPoisonNCS", withExtension: "mp3") {
            AudioPlayerManager.shared.playSound(from: bundledURL)
        }
        
        updatePlayPauseButton()
        updateThumbnail()
    }
    
    // Called when the user begins touching/dragging the slider.
    @IBAction func sliderTouchDown(_ sender: UISlider) {
        isSliderDragging = true
    }
    
    // Called when the user finishes dragging the slider.
    @IBAction func sliderTouchUp(_ sender: UISlider) {
        isSliderDragging = false
        AudioPlayerManager.shared.seek(to: TimeInterval(sender.value))
    }
    
    @IBAction func playPauseTapped(_ sender: UIButton) {
        if AudioPlayerManager.shared.isPlaying {
            AudioPlayerManager.shared.pause()
        } else {
            AudioPlayerManager.shared.play()
        }
        updatePlayPauseButton()
    }
    
    @IBAction func prevTapped(_ sender: UIButton) {
        AudioPlayerManager.shared.stop()
    }
    
    @IBAction func nextTapped(_ sender: UIButton) {
        AudioPlayerManager.shared.stop()
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
    
    // Asynchronously updates the thumbnail image using the new async load(.dataValue) API.
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
    
    /// Asynchronously extracts artwork from the asset's ID3 metadata using the new async API.
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

extension PlayerViewController: AudioPlayerManagerDelegate {
    func audioPlayerManagerDidChangeState(_ manager: AudioPlayerManager) {
        titleLabel.text = manager.audioTitle
        updatePlayPauseButton()
    }
    
    func audioPlayerManager(_ manager: AudioPlayerManager, didUpdateDuration currentTime: TimeInterval) {
        // Only update the slider if the user isn't dragging it.
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
