//
//  PlayerViewController.swift
//  Echo Play
//
//  Created by Mayank Jangid on 3/13/25.
//

import UIKit

class PlayerViewController: UIViewController {
    
    // MARK: - Outlets
    @IBOutlet weak var slider: UISlider!
    @IBOutlet weak var currentTimeLabel: UILabel!
    @IBOutlet weak var totalTimeLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var noteImageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        AudioPlayerManager.shared.delegate = self
        
        // initialize UI
        slider.minimumValue = 0
        slider.value = 0
        
        let duration = AudioPlayerManager.shared.getDuration()
        slider.maximumValue = Float(duration)
        totalTimeLabel.text = formatTime(duration)
        
        titleLabel.text = AudioPlayerManager.shared.audioTitle
        
        // Example: load an MP3 from your app bundle
        if let audioURL = Bundle.main.url(forResource: "YourPoisonNCS", withExtension: "mp3") {
            AudioPlayerManager.shared.playSound(from: audioURL)
        }
    }
    
    @IBAction func sliderValueChanged(_ sender: UISlider) {
        AudioPlayerManager.shared.seek(to: TimeInterval(sender.value))
    }
    
    @IBAction func playPauseTapped(_ sender: UIButton) {
        if AudioPlayerManager.shared.isPlaying {
            AudioPlayerManager.shared.pause()
        } else {
            AudioPlayerManager.shared.play()
        }
    }
    
    @IBAction func prevTapped(_ sender: UIButton) {
        AudioPlayerManager.shared.stop()
    }
    
    @IBAction func nextTapped(_ sender: UIButton) {
        AudioPlayerManager.shared.stop()
    }
    
    // MARK: - Helpers
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - AudioPlayerManagerDelegate

extension PlayerViewController: AudioPlayerManagerDelegate {
    
    func audioPlayerManagerDidChangeState(_ manager: AudioPlayerManager) {
        titleLabel.text = manager.audioTitle
    }
    
    // Called frequently to update current playback time
    func audioPlayerManager(_ manager: AudioPlayerManager, didUpdateDuration currentTime: TimeInterval) {
        slider.value = Float(currentTime)
        currentTimeLabel.text = formatTime(currentTime)
        
        let total = manager.getDuration()
        totalTimeLabel.text = formatTime(total)
    }
    
    func audioPlayerManagerDidComplete(_ manager: AudioPlayerManager) {
        slider.value = 0
        currentTimeLabel.text = "00:00"
    }
}
