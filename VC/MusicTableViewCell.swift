//
//  MusicTableViewCell.swift
//  Echo Play
//
//  Created by Mayank Jangid on 3/13/25.
//

import UIKit
import AVFoundation

protocol MusicTableViewCellDelegate: AnyObject {
    func musicTableViewCell(_ cell: MusicTableViewCell, didTapFavoriteFor url: URL)
}

class MusicTableViewCell: UITableViewCell {
    
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var starButton: UIButton!
    
    weak var delegate: MusicTableViewCellDelegate?
    
    private var currentAudioURL: URL?
    
    func configure(with audioURL: URL) {
        currentAudioURL = audioURL
        titleLabel.text = audioURL.lastPathComponent
        durationLabel.text = "Loading..."
        
        // Asynchronously load artwork and duration
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
            
            await MainActor.run {
                if self.currentAudioURL == audioURL {
                    self.iconImageView.image = artwork ?? UIImage(systemName: "music.note")
                    self.durationLabel.text = durationText
                }
            }
        }
    }
    
    func updateStar(isFavorite: Bool) {
        let starImage = isFavorite ? UIImage(systemName: "star.fill") : UIImage(systemName: "star")
        starButton.setImage(starImage, for: .normal)
    }
    
    @IBAction func starButtonTapped(_ sender: UIButton) {
        print("Star button tapped")
        guard let url = currentAudioURL else { return }
        delegate?.musicTableViewCell(self, didTapFavoriteFor: url)
    }
    
    // Asynchronously extracts artwork from the asset's ID3 metadata
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
