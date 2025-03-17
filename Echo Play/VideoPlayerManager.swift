//
//  VideoPlayerManager.swift
//  Echo Play
//
//  Created by Mayank Jangid on 3/17/25.
//

import Foundation
import AVKit

@objc protocol VideoPlayerManagerDelegate: AnyObject {
    @objc optional func videoPlayerManagerDidChangeState(_ manager: VideoPlayerManager)
    @objc optional func videoPlayerManager(_ manager: VideoPlayerManager, didUpdateTime currentTime: TimeInterval)
    @objc optional func videoPlayerManagerDidComplete(_ manager: VideoPlayerManager)
}

class VideoPlayerManager: NSObject {
    
    static let shared = VideoPlayerManager()
    weak var delegate: VideoPlayerManagerDelegate?
    
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserverToken: Any?
    
    var isPlaying: Bool {
        return player?.timeControlStatus == .playing
    }
    
    // MARK: - Play Video in AVPlayerViewController
    func playVideo(from url: URL, on presentingViewController: UIViewController) {
        // clean up previous player if needed
        stop()
        
        let item = AVPlayerItem(url: url)
        playerItem = item
        
        // Observe completion
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinish(_:)),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )
        
        // Observe time updates
        player = AVPlayer(playerItem: item)
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: CMTimeMake(value: 1, timescale: 2),
                                                            queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.delegate?.videoPlayerManager?(self, didUpdateTime: time.seconds)
        }
        
        // Present an AVPlayerViewController
        let playerVC = AVPlayerViewController()
        playerVC.player = player
        
        presentingViewController.present(playerVC, animated: true) {
            self.player?.play()
            self.delegate?.videoPlayerManagerDidChangeState?(self)
        }
    }
    
    // MARK: - Control
    
    func pause() {
        player?.pause()
        delegate?.videoPlayerManagerDidChangeState?(self)
    }
    
    func resume() {
        player?.play()
        delegate?.videoPlayerManagerDidChangeState?(self)
    }
    
    func stop() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        NotificationCenter.default.removeObserver(self)
        
        player?.pause()
        player = nil
        playerItem = nil
        
        delegate?.videoPlayerManagerDidChangeState?(self)
    }
    
    // MARK: - Helpers
    
    @objc private func playerDidFinish(_ notification: Notification) {
        delegate?.videoPlayerManagerDidComplete?(self)
    }
    
    func getCurrentTime() -> TimeInterval {
        return player?.currentTime().seconds ?? 0
    }
    
    func getDuration() -> TimeInterval {
        return playerItem?.duration.seconds ?? 0
    }
}
