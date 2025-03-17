//
//  MusicViewController.swift
//  Echo Play
//
//  Created by Mayank Jangid on 3/13/25.
//

import UIKit
import MediaPlayer

class MusicViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var tableView: UITableView!
    
    // Your list of song URLs
    var songURLs: [URL] = [
        URL(string: "https://www.learningcontainer.com/wp-content/uploads/2020/02/Kalimba.mp3")!,
        URL(string: "https://example.com/song2.mp3")!,
        URL(string: "https://example.com/song3.mp3")!
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    // MARK: - IBAction for adding a song via URL
//    @IBAction func addSongButtonTapped(_ sender: UIBarButtonItem) {
//        let alert = UIAlertController(title: "Add Song",
//                                      message: "Enter the URL of the song",
//                                      preferredStyle: .alert)
//        
//        alert.addTextField { textField in
//            textField.placeholder = "https://example.com/song.mp3"
//        }
//        
//        let addAction = UIAlertAction(title: "Add", style: .default) { [weak self] _ in
//            guard let self = self,
//                  let text = alert.textFields?.first?.text,
//                  let url = URL(string: text) else { return }
//            
//            // Validate file extension
//            let validExtensions = ["mp3", "wav", "m4a"]
//            let fileExtension = url.pathExtension.lowercased()
//            
//            if validExtensions.contains(fileExtension) {
//                self.songURLs.append(url)
//                self.tableView.reloadData()
//            } else {
//                let errorAlert = UIAlertController(title: "Invalid URL",
//                                                   message: "Only .mp3, .wav, or .m4a are allowed.",
//                                                   preferredStyle: .alert)
//                errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
//                self.present(errorAlert, animated: true)
//            }
//        }
//        
//        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
//        alert.addAction(addAction)
//        alert.addAction(cancelAction)
//        present(alert, animated: true)
//    }
    
    // IBAction for the + button using FileManager to pick a downloaded MP3 file
    @IBAction func addSongButtonTapped(_ sender: UIBarButtonItem) {
        // Locate the "Music" folder inside your app's Documents directory
        guard let musicDirectory = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("Music") else { return }
        
        do {
            // Get list of files in the Music folder
            let files = try FileManager.default.contentsOfDirectory(at: musicDirectory, includingPropertiesForKeys: nil, options: [])
            // Filter only for MP3 files
            let mp3Files = files.filter { $0.pathExtension.lowercased() == "mp3" }
            
            if mp3Files.isEmpty {
                let alert = UIAlertController(title: "No Files", message: "No MP3 files found in your Music folder.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
            } else {
                // action sheet listing each MP3 file
                let actionSheet = UIAlertController(title: "Select a Song", message: nil, preferredStyle: .actionSheet)
                for file in mp3Files {
                    let action = UIAlertAction(title: file.lastPathComponent, style: .default) { [weak self] _ in
                        self?.songURLs.append(file)
                        self?.tableView.reloadData()
                    }
                    actionSheet.addAction(action)
                }
                actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                // iPad .....
                if let popover = actionSheet.popoverPresentationController {
                    popover.barButtonItem = sender
                }
                present(actionSheet, animated: true)
            }
        } catch {
            print("Error accessing Music folder: \(error)")
        }
    }

    
//    // MARK: - IBAction for picking a song from the Music Library
//    @IBAction func pickSongFromLibraryButtonTapped(_ sender: UIBarButtonItem) {
//        let mediaPicker = MPMediaPickerController(mediaTypes: .music)
//        mediaPicker.delegate = self
//        mediaPicker.allowsPickingMultipleItems = false
//        present(mediaPicker, animated: true)
//    }
    
    // MARK: - UITableViewDataSource Methods
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return songURLs.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Use your custom cell
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "SongCell", for: indexPath) as? MusicTableViewCell else {
            return UITableViewCell()
        }
        
        let audioURL = songURLs[indexPath.row]
        cell.titleLabel.text = audioURL.lastPathComponent
        cell.iconImageView.image = UIImage(systemName: "music.note")
        cell.durationLabel.text = ""
        return cell
    }
    
    // MARK: - UITableViewDelegate Methods
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let playerVC = storyboard.instantiateViewController(withIdentifier: "PlayerViewController") as? PlayerViewController {
            playerVC.audioURL = songURLs[indexPath.row]
            navigationController?.pushViewController(playerVC, animated: true)
        }
    }

    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return tableView.frame.width / 4.0
    }
}

// MARK: - MPMediaPickerControllerDelegate Methods

extension MusicViewController: MPMediaPickerControllerDelegate {
    func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
        dismiss(animated: true, completion: nil)
        
        if let item = mediaItemCollection.items.first, let assetURL = item.assetURL {
            songURLs.append(assetURL)
            tableView.reloadData()
        } else {
            let alert = UIAlertController(title: "Error", message: "Could not get the selected song.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
    
    func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
        dismiss(animated: true, completion: nil)
    }
}
