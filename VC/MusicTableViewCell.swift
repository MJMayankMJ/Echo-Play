//
//  MusicTableViewCell.swift
//  Echo Play
//
//  Created by Mayank Jangid on 3/13/25.
//

import UIKit
import AVFoundation

class MusicTableViewCell: UITableViewCell {
    
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    
    private var currentAudioURL: URL?
    
    func configure(with audioURL: URL) {
        currentAudioURL = audioURL
        titleLabel.text = audioURL.lastPathComponent
        durationLabel.text = "Loading..."
        
        // Asynchronously load artwork and duration from the audio file's metadata.
        Task {
            let asset = AVURLAsset(url: audioURL)
            
            // 1. Extract artwork
            let artwork = await extractArtwork(from: asset)
            
            // 2. Load duration
            var durationText = "00:00"
            do {
                let cmDuration = try await asset.load(.duration)
                let durationInSeconds = CMTimeGetSeconds(cmDuration)
                durationText = formatTime(durationInSeconds)
            } catch {
                print("Error loading duration: \(error)")
            }
            
            // Update UI on the main thread if the cell is still displaying this audioURL (it is from gpt as i still dont get this new ios thing but better than depricated version of mine i guess
            await MainActor.run {
                if self.currentAudioURL == audioURL {
                    self.iconImageView.image = artwork ?? UIImage(systemName: "music.note")
                    self.durationLabel.text = durationText
                }
            }
        }
    }
    
    // Asynchronously extracts artwork from the asset's ID3 metadata using the new async API.
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
            print("Error loading artwork: \(error)")
        }
        return nil
    }
    
    // Formats seconds into a time string (mm:ss or hh:mm:ss).
    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN else { return "00:00" }
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
}
