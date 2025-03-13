//
//  AudioPlayerManager.swift
//  Echo Play
//
//  Created by Mayank Jangid on 3/13/25.
//

import Foundation
import AVFoundation
import MediaPlayer

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
    
    var audioTitle: String = "Unknown title"
    
    var isPlaying: Bool {
        return player?.isPlaying ?? false
    }
    
    var isPlayerMuted: Bool = false {
        didSet {
            if let player{
                player.volume = isPlayerMuted ? 0.0 : 1.0
            }}}
    
    private override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(audioSessionInterrupted), name: AVAudioSession.interruptionNotification, object: nil)
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
    
    func updateNowPlayingInfo() {
        guard let player = player else { return }
        
        var nowPlayingInfo = [String: Any]()
        
        // Extract metadata from the audio file
        if let audioURL = player.url {
            let asset = AVURLAsset(url: audioURL)
            let metadata = asset.metadata(forFormat: .id3Metadata)
            
            // Extract the title, artist, and album from the metadata
            var title: String?
            var artist: String?
            var album: String?
            
            for item in metadata {
                if let commonKey = item.commonKey {
                    switch commonKey {
                    case .commonKeyTitle:
                        title = item.value as? String
                        audioTitle = item.value as? String ?? "Unknown title"
                    case .commonKeyArtist:
                        artist = item.value as? String
                    case .commonKeyAlbumName:
                        album = item.value as? String
                    case .commonKeyArtwork:
                        break
                    default:
                        break
                    }
                }
            }
            
            // Fallback to default values if metadata is not available
            nowPlayingInfo[MPMediaItemPropertyTitle] = title ?? "Unknown Title"
            nowPlayingInfo[MPMediaItemPropertyArtist] = artist ?? "Unknown Artist"
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = album ?? "Unknown Album"
        }

       
        nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: getThumbnail(from: player.url!).size) { _ in self.getThumbnail(from: player.url!) }
        
        // Set the duration and current playback time
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = player.duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player.isPlaying ? 1.0 : 0.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    func getThumbnail(from audioURL: URL) -> UIImage {
        let asset = AVURLAsset(url: audioURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        var image: UIImage?
        
        // Generate the image from the first frame (or any specific time)
        do {
            let cgImage = try imageGenerator.copyCGImage(at: CMTimeMake(value: 0, timescale: 1), actualTime: nil)
            image = UIImage(cgImage: cgImage)
        } catch {
//            print("Error generating thumbnail: \(error)")
        }
        
        return image ?? UIImage(named: "logo")!
    }
    
    func playSound(from audioURL: URL, extension ext: String = "mp3"){
        self.stop()
        
        configureAudioSession()
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try? AVAudioPlayer(contentsOf: audioURL)
            player?.prepareToPlay()
            player?.delegate = self
            player?.play()
            startDurationUpdateTimer()
            delegate?.audioPlayerManagerDidChangeState?(self)
            
            updateNowPlayingInfo()
        }
        catch let error{
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
        print(player?.duration ?? 0)
        return player?.duration ?? 0
    }
}

extension AudioPlayerManager {
    private func startDurationUpdateTimer() {
        stopDurationUpdateTimer()
        
        durationUpdateTimer = Timer.scheduledTimer(
            withTimeInterval: 0.01,
            repeats: true,
            block: { [weak self] _ in
                guard let self = self, let currentTime = self.player?.currentTime, isPlaying else { return }
                self.delegate?.audioPlayerManager?(self, didUpdateDuration: currentTime)
                self.updateNowPlayingInfo()
            }
        )
    }
    
    private func stopDurationUpdateTimer() {
        durationUpdateTimer?.invalidate()
        durationUpdateTimer = nil
    }
}

extension AudioPlayerManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        delegate?.audioPlayerManagerDidComplete?(self)
    }
}
