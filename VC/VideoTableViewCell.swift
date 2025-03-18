//
//  VideoTableViewCell.swift
//  Echo Play
//
//  Created by Mayank Jangid on 3/17/25.
//

import UIKit
import AVFoundation

class VideoTableViewCell: UITableViewCell {
    
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    
    private var currentVideoURL: URL?
    
    func configure(with videoURL: URL) {
        currentVideoURL = videoURL
        titleLabel.text = videoURL.lastPathComponent
        durationLabel.text = "Loading..."
        
        thumbnailImageView.image = UIImage(systemName: "video.fill")
        
        Task {
            let asset = AVURLAsset(url: videoURL)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            let time = CMTimeMake(value: 0, timescale: 1)
            
            // Generate the thumbnail asynchronously using the new API.
            let thumbnail: UIImage? = await withCheckedContinuation { continuation in
                imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { requestedTime, cgImage, actualTime, result, error in
                    if let cgImage = cgImage, error == nil {
                        continuation.resume(returning: UIImage(cgImage: cgImage))
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }
            
            // Load duration asynchronously using async/await.
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
    
    // Formats a duration (in seconds) into a string (mm:ss or hh:mm:ss).
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
