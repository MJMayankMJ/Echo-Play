//
//  VideoTableViewCell.swift
//  Echo Play
//
//  Created by Mayank Jangid on 3/17/25.
//

import UIKit
import AVFoundation

class VideoTableViewCell: UITableViewCell {
    
    @IBOutlet weak var thumbnailImageView: UIImageView!  // Renamed for clarity
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    
    // Keep track of the video URL to prevent stale async updates
    private var currentVideoURL: URL?
    
    func configure(with videoURL: URL) {
        currentVideoURL = videoURL
        titleLabel.text = videoURL.lastPathComponent
        durationLabel.text = "Loading..."
        thumbnailImageView.image = UIImage(systemName: "video") // placeholder while loading
        
        // Generate thumbnail and duration asynchronously
        Task {
            let asset = AVURLAsset(url: videoURL)
            // Generate thumbnail from first frame
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            let time = CMTimeMake(value: 0, timescale: 1)
            var thumbnail: UIImage?
            do {
                let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                thumbnail = UIImage(cgImage: cgImage)
            } catch {
                print("Error generating thumbnail: \(error)")
            }
            
            // Load duration asynchronously using new async/await API
            do {
                let cmDuration = try await asset.load(.duration)
                let durationInSeconds = CMTimeGetSeconds(cmDuration)
                await MainActor.run {
                    if self.currentVideoURL == videoURL {
                        self.durationLabel.text = self.formatTime(durationInSeconds)
                        if let thumb = thumbnail {
                            self.thumbnailImageView.image = thumb
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    if self.currentVideoURL == videoURL {
                        self.durationLabel.text = "Error"
                    }
                }
                print("Error loading duration: \(error)")
            }
        }
    }
    
    /// Formats seconds into a time string (mm:ss or hh:mm:ss)
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
