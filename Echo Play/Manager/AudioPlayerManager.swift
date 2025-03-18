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
    
    // Loaded metadata (will be updated if needed elsewhere)
    private var loadedTitle: String = "Unknown Title"
    private var loadedArtist: String = "Unknown Artist"
    private var loadedAlbum: String = "Unknown Album"
    private var loadedArtwork: UIImage = UIImage(systemName: "music.note.list")!
    
    // MARK: - Init
    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioSessionInterrupted),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        setupRemoteCommands()
        UIApplication.shared.beginReceivingRemoteControlEvents()
    }
    
    // MARK: - Remote Commands
    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget(self, action: #selector(handlePlayCommand(_:)))
        commandCenter.pauseCommand.addTarget(self, action: #selector(handlePauseCommand(_:)))
        commandCenter.nextTrackCommand.addTarget(self, action: #selector(handleNextTrackCommand(_:)))
        commandCenter.previousTrackCommand.addTarget(self, action: #selector(handlePreviousTrackCommand(_:)))
        commandCenter.changePlaybackPositionCommand.addTarget(self, action: #selector(handleChangePlaybackPositionCommand(_:)))
    }
    
    @objc private func handlePlayCommand(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        play()
        return .success
    }
    
    @objc private func handlePauseCommand(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        pause()
        return .success
    }
    
    @objc private func handleNextTrackCommand(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        NotificationCenter.default.post(name: .didRequestNextTrack, object: nil)
        return .success
    }
    
    @objc private func handlePreviousTrackCommand(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        NotificationCenter.default.post(name: .didRequestPreviousTrack, object: nil)
        return .success
    }
    
    @objc private func handleChangePlaybackPositionCommand(_ event: MPChangePlaybackPositionCommandEvent) -> MPRemoteCommandHandlerStatus {
        let newTime = event.positionTime
        seek(to: newTime)
        return .success
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
            
            // Removed metadata/artwork loading here as the view controller (or cell) now handles it.
            updateNowPlayingInfo()
            
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
        updateNowPlayingInfo()
    }
    
    func getCurrentTime() -> TimeInterval {
        return player?.currentTime ?? 0
    }
    
    func getDuration() -> TimeInterval {
        return player?.duration ?? 0
    }
    
    // MARK: - Now Playing Info
//    func updateNowPlayingInfo() {
//        guard let player = player else { return }
//        
//        var nowPlayingInfo: [String: Any] = [:]
//        nowPlayingInfo[MPMediaItemPropertyTitle] = loadedTitle
//        nowPlayingInfo[MPMediaItemPropertyArtist] = loadedArtist
//        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = loadedAlbum
//        nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: loadedArtwork.size) { _ in
//            return self.loadedArtwork
//        }
//        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = player.duration
//        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime
//        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player.isPlaying ? 1.0 : 0.0
//        
//        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
//    }
    func updateNowPlayingInfo() {
        guard let player = player else { return }
        
        var nowPlayingInfo: [String: Any] = [:]
        
        // 1) Use `audioTitle` here
        nowPlayingInfo[MPMediaItemPropertyTitle] = audioTitle
        
        nowPlayingInfo[MPMediaItemPropertyArtist] = loadedArtist
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = loadedAlbum
        nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: loadedArtwork.size) { _ in
            return self.loadedArtwork
        }
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
            guard let self = self, let _ = self.player, self.isPlaying else { return }
            self.delegate?.audioPlayerManager?(self, didUpdateDuration: self.player!.currentTime)
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

// MARK: - Notification Names
extension Notification.Name {
    static let didRequestNextTrack = Notification.Name("didRequestNextTrack")
    static let didRequestPreviousTrack = Notification.Name("didRequestPreviousTrack")
}
