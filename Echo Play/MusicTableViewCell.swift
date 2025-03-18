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
    
    // Track the current audio URL to avoid stale async updates.
    private var currentAudioURL: URL?
    
    func configure(with audioURL: URL) {
        currentAudioURL = audioURL
        titleLabel.text = audioURL.lastPathComponent
        durationLabel.text = "Loading..."
        
        // Asynchronously load artwork from the audio file's metadata.
        Task {
            let asset = AVURLAsset(url: audioURL)
            let artwork = await extractArtwork(from: asset)
            await MainActor.run {
                if self.currentAudioURL == audioURL {
                    self.iconImageView.image = artwork ?? UIImage(systemName: "music.note")
                }
            }
        }
        
        // Optionally, you could also load duration asynchronously (if desired)
        // and update durationLabel.
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
            print("Error loading artwork: \(error)")
        }
        return nil
    }
}
