//
//  MusicViewController.swift
//  Echo Play
//
//  Created by Mayank Jangid on 3/13/25.
//

import UIKit
import UniformTypeIdentifiers
import MediaPlayer

class MusicViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    // Array to hold URLs of songs stored in Documents/Songs
    var songURLs: [URL] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        
        // Create the Songs folder (if needed) and load any saved songs.
        createSongsFolder()
        loadSongsFromDocumentsFolder()
    }
    
    // MARK: - Create "Songs" Folder at App Launch
    private func createSongsFolder() {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let songsFolder = documentsDirectory.appendingPathComponent("Songs")
        
        if !fileManager.fileExists(atPath: songsFolder.path) {
            do {
                try fileManager.createDirectory(at: songsFolder, withIntermediateDirectories: true, attributes: nil)
                print("Songs folder created.")
            } catch {
                print("Error creating Songs folder: \(error)")
            }
        }
    }
    
    // MARK: - Load MP3 Files from "Songs" Folder
    private func loadSongsFromDocumentsFolder() {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let songsFolder = documentsDirectory.appendingPathComponent("Songs")
        
        do {
            let allFiles = try fileManager.contentsOfDirectory(at: songsFolder, includingPropertiesForKeys: nil, options: [])
            let mp3Files = allFiles.filter { $0.pathExtension.lowercased() == "mp3" }
            songURLs = mp3Files
            tableView.reloadData()
        } catch {
            print("Error reading Songs folder: \(error)")
        }
    }
    
    // MARK: - IBAction for Adding a Song (+ Button)
    @IBAction func addSongButtonTapped(_ sender: UIBarButtonItem) {
        // Present a document picker to select an audio file.
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.audio], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        
        // For iPad: present from the bar button.
        if let popover = picker.popoverPresentationController {
            popover.barButtonItem = sender
        }
        present(picker, animated: true)
    }
    
    // MARK: - Save Song to "Songs" Folder
    private func saveSongToDocumentsFolder(songURL: URL) {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let songsFolder = documentsDirectory.appendingPathComponent("Songs")
        
        // (The Songs folder should already exist from createSongsFolder())
        var destinationURL = songsFolder.appendingPathComponent(songURL.lastPathComponent)
        var fileIndex = 1
        
        // Avoid collisions by appending a counter if needed.
        while fileManager.fileExists(atPath: destinationURL.path) {
            let newName = "\(songURL.deletingPathExtension().lastPathComponent)_\(fileIndex).\(songURL.pathExtension)"
            destinationURL = songsFolder.appendingPathComponent(newName)
            fileIndex += 1
        }
        
        do {
            // If the file is security-scoped (e.g., from iCloud), wrap in startAccessingSecurityScopedResource.
            if songURL.startAccessingSecurityScopedResource() {
                defer { songURL.stopAccessingSecurityScopedResource() }
                try fileManager.copyItem(at: songURL, to: destinationURL)
            } else {
                try fileManager.copyItem(at: songURL, to: destinationURL)
            }
            print("Song copied to: \(destinationURL)")
            // Refresh the table view after saving.
            loadSongsFromDocumentsFolder()
        } catch {
            print("Error copying song: \(error)")
        }
    }
}

// MARK: - UIDocumentPickerDelegate
extension MusicViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let pickedURL = urls.first else { return }
        saveSongToDocumentsFolder(songURL: pickedURL)
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate
extension MusicViewController: UITableViewDataSource, UITableViewDelegate {
    
    // Return the number of songs.
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return songURLs.count
    }
    
    // Dequeue and configure the custom MusicTableViewCell.
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "SongCell", for: indexPath) as? MusicTableViewCell else {
            return UITableViewCell()
        }
        let audioURL = songURLs[indexPath.row]
        cell.configure(with: audioURL)
        return cell
    }
    
    // When a song is selected, instantiate and push a PlayerViewController to play the song.
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let playerVC = storyboard.instantiateViewController(withIdentifier: "PlayerViewController") as? PlayerViewController {
            playerVC.audioURL = songURLs[indexPath.row]
            navigationController?.pushViewController(playerVC, animated: true)
        }
    }
    
    // Set the cell height (for example, 1/4 of the table view's width)
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return tableView.frame.width / 4.0
    }
}
