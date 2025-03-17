//
//  AudioPlayerManager.swift
//  Echo Play
//
//  Created by Mayank Jangid on 3/13/25.
//

import Foundation
import AVFoundation
import MediaPlayer
import UIKit

@objc protocol AudioPlayerManagerDelegate: AnyObject {
    @objc optional func audioPlayerManagerDidChangeState(_ manager: AudioPlayerManager)
    @objc optional func audioPlayerManager(_ manager: AudioPlayerManager, didUpdateDuration currentTime: TimeInterval)
    @objc optional func audioPlayerManagerDidComplete(_ manager: AudioPlayerManager)
}

class AudioPlayerManager: NSObject {
    static let shared = AudioPlayerManager()
    weak var delegate: AudioPlayerManagerDelegate?
    
    private var player: AVAudioPlayer?
    private var durationUpdateTimer: Timer?
    
    // Basic properties
    var audioTitle: String = "Unknown title"
    var isPlayerMuted: Bool = false {
        didSet {
            player?.volume = isPlayerMuted ? 0.0 : 1.0
        }
    }
    
    var isPlaying: Bool {
        return player?.isPlaying ?? false
    }
    
    private var loadedTitle: String = "Unknown Title"
    private var loadedArtist: String = "Unknown Artist"
    private var loadedAlbum: String = "Unknown Album"
    private var loadedArtwork: UIImage = UIImage(named: "logo")!
    
    // MARK: - Init
    
    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioSessionInterrupted),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }
    
    @objc private func audioSessionInterrupted(notification: Notification) {
        stop()
    }
    
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay])
            try session.setActive(true, options: [])
        } catch {
            print("Error configuring AVAudioSession: \(error)")
        }
    }
    
    // MARK: - Public Audio Control
    
    func playSound(from audioURL: URL) {
        stop()
        configureAudioSession()
        
        do {
            player = try AVAudioPlayer(contentsOf: audioURL)
            player?.prepareToPlay()
            player?.delegate = self
            player?.play()
            
            Task {
                await loadMetadataAndArtwork(for: audioURL)
                updateNowPlayingInfo()
            }
            
            startDurationUpdateTimer()
            delegate?.audioPlayerManagerDidChangeState?(self)
        } catch {
            print("Error initializing audio player: \(error)")
        }
    }
    
    func play() {
        player?.play()
        delegate?.audioPlayerManagerDidChangeState?(self)
        updateNowPlayingInfo()
    }
    
    func pause() {
        player?.pause()
        delegate?.audioPlayerManagerDidChangeState?(self)
        updateNowPlayingInfo()
    }
    
    func stop() {
        player?.stop()
        player = nil
        stopDurationUpdateTimer()
        delegate?.audioPlayerManagerDidChangeState?(self)
    }
    
    func seek(to time: TimeInterval) {
        player?.currentTime = time
        delegate?.audioPlayerManagerDidChangeState?(self)
    }
    
    func getCurrentTime() -> TimeInterval {
        return player?.currentTime ?? 0
    }
    
    func getDuration() -> TimeInterval {
        return player?.duration ?? 0
    }
    
    // MARK: - Metadata and Artwork (iOS 18+)
    
    // load metadata and generates a thumbnail image from the first frame.
    private func loadMetadataAndArtwork(for url: URL) async {
        let asset = AVURLAsset(url: url)
        
        do {
            // 1. load metadata
            let metadataItems = try await asset.loadMetadata(for: .id3Metadata)
            for item in metadataItems {
                guard let key = item.commonKey else { continue }
                
                switch key {
                case .commonKeyTitle:
                    if let titleValue = try? await item.load(.value) as? String {
                        loadedTitle = titleValue
                        audioTitle = titleValue
                    }
                case .commonKeyArtist:
                    if let artistValue = try? await item.load(.value) as? String {
                        loadedArtist = artistValue
                    }
                case .commonKeyAlbumName:
                    if let albumValue = try? await item.load(.value) as? String {
                        loadedAlbum = albumValue
                    }
                default:
                    break
                }
            }
            
            // 2. Generate a thumbnail image from the first frame
            loadedArtwork = await generateThumbnail(asset: asset)
        } catch {
            print("Error loading metadata: \(error)")
        }
    }
    
    private func generateThumbnail(asset: AVURLAsset) async -> UIImage {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        
        // We'll request a frame at time = 0
        let time = CMTimeMake(value: 0, timescale: 1)
        
        return await withCheckedContinuation { continuation in
            generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) {
                requestedTime, cgImage, actualTime, result, error in
                guard let cgImage = cgImage, error == nil else {
                    // fallback image if we can't generate a thumbnail
                    continuation.resume(returning: UIImage(named: "logo")!)
                    return
                }
                continuation.resume(returning: UIImage(cgImage: cgImage))
            }
        }
    }
    
    // MARK: - Now Playing Info
    
    private func updateNowPlayingInfo() {
        guard let player = player else { return }
        
        var nowPlayingInfo: [String: Any] = [:]
        nowPlayingInfo[MPMediaItemPropertyTitle] = loadedTitle
        nowPlayingInfo[MPMediaItemPropertyArtist] = loadedArtist
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = loadedAlbum
        
        nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(
            boundsSize: loadedArtwork.size,
            requestHandler: { _ in
                return self.loadedArtwork
            }
        )
        
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = player.duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player.isPlaying ? 1.0 : 0.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}

// MARK: - Timer Updates

extension AudioPlayerManager {
    private func startDurationUpdateTimer() {
        stopDurationUpdateTimer()
        durationUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self,
                  let currentTime = self.player?.currentTime,
                  self.isPlaying else { return }
            
            self.delegate?.audioPlayerManager?(self, didUpdateDuration: currentTime)
            self.updateNowPlayingInfo()
        }
    }
    
    private func stopDurationUpdateTimer() {
        durationUpdateTimer?.invalidate()
        durationUpdateTimer = nil
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlayerManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        delegate?.audioPlayerManagerDidComplete?(self)
    }
}
