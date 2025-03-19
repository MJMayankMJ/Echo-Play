//
//  VideoViewController.swift
//  Echo Play
//
//  Created by Mayank Jangid on 3/17/25.
//

import UIKit
import AVKit

class VideoViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    var videoURLs: [URL] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loadVideosFromDocumentsFolder()
        
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    // MARK: - Load Videos
    
    private func loadVideosFromDocumentsFolder() {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let videoFolder = documentsDirectory.appendingPathComponent("Video")
        
        // Create the folder if it doesn't exist
        if !fileManager.fileExists(atPath: videoFolder.path) {
            do {
                try fileManager.createDirectory(at: videoFolder, withIntermediateDirectories: true)
            } catch {
                print("Error creating Video folder: \(error)")
                return
            }
        }
        
        do {
            let allFiles = try fileManager.contentsOfDirectory(at: videoFolder, includingPropertiesForKeys: nil, options: [])
            let videoExtensions = ["mp4", "mov", "m4v"]
            videoURLs = allFiles.filter { videoExtensions.contains($0.pathExtension.lowercased()) }
            
            if videoURLs.isEmpty {
                let messageLabel = UILabel(frame: CGRect(x: 0,
                                                         y: 0,
                                                         width: tableView.bounds.size.width,
                                                         height: tableView.bounds.size.height))
                messageLabel.text = "No videos added."
                messageLabel.textColor = .gray
                messageLabel.textAlignment = .center
                messageLabel.font = UIFont.systemFont(ofSize: 20)
                messageLabel.numberOfLines = 0
                tableView.backgroundView = messageLabel
            } else {
                tableView.backgroundView = nil
            }
            
            tableView.reloadData()
        } catch {
            print("Error reading Video folder: \(error)")
        }
    }

    // MARK: - Add Video (+ Button)
    
    @IBAction func addVideoButtonTapped(_ sender: UIBarButtonItem) {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.movie], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        
        // iPad ...
        if let popover = picker.popoverPresentationController {
            popover.barButtonItem = sender
        }
        present(picker, animated: true)
    }
}

// MARK: - UIDocumentPickerDelegate

extension VideoViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        // We only allow one selection above, so take the first URL.
        guard let pickedURL = urls.first else { return }
        saveVideoToDocumentsFolder(videoURL: pickedURL)
    }
    
    private func saveVideoToDocumentsFolder(videoURL: URL) {
        let fileManager = FileManager.default
        
        // Path to Documents/Video folder.
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let videoFolder = documentsDirectory.appendingPathComponent("Video")
        
        // Create folder if it doesn't exist.
        if !fileManager.fileExists(atPath: videoFolder.path) {
            do {
                try fileManager.createDirectory(at: videoFolder, withIntermediateDirectories: true)
            } catch {
                print("Error creating Video folder: \(error)")
                return
            }
        }
        
        // Create a unique filename (avoid collisions)
        var destinationURL = videoFolder.appendingPathComponent(videoURL.lastPathComponent)
        var fileIndex = 1
        while fileManager.fileExists(atPath: destinationURL.path) {
            let newName = "\(videoURL.deletingPathExtension().lastPathComponent)_\(fileIndex).\(videoURL.pathExtension)"
            destinationURL = videoFolder.appendingPathComponent(newName)
            fileIndex += 1
        }
        
        do {
            if videoURL.startAccessingSecurityScopedResource() {
                defer { videoURL.stopAccessingSecurityScopedResource() }
                try fileManager.copyItem(at: videoURL, to: destinationURL)
            } else {
                try fileManager.copyItem(at: videoURL, to: destinationURL)
            }
            print("Video copied to: \(destinationURL)")
            // Refresh
            loadVideosFromDocumentsFolder()
        } catch {
            print("Error copying video: \(error)")
        }
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate

extension VideoViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return videoURLs.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "VideoCell", for: indexPath) as? VideoTableViewCell else {
            return UITableViewCell()
        }
        let videoURL = videoURLs[indexPath.row]
        cell.configure(with: videoURL)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let videoURL = videoURLs[indexPath.row]
        
        let player = AVPlayer(url: videoURL)
        let playerVC = AVPlayerViewController()
        playerVC.player = player
        playerVC.allowsPictureInPicturePlayback = true
        playerVC.delegate = self
        
        present(playerVC, animated: true) {
            player.play()
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return tableView.frame.height / 6.0
    }
}

//MARK: - PIP

extension VideoViewController: AVPlayerViewControllerDelegate {
    func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        print("PiP Started")
    }
    
    func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        print("PiP Stopped")
    }
    
    func playerViewControllerShouldAutomaticallyDismissAtPictureInPictureStart(_ playerViewController: AVPlayerViewController) -> Bool {
        return true  // Automatically dismiss when PiP starts
    }
}
