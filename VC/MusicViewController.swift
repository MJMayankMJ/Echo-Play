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

    var songURLs: [URL] = []

    // Flag that determines if we're showing "all songs" or "favorites"
    var isShowingFavorites: Bool = false {
        didSet {
            if isShowingFavorites {
                title = "Favorites"
                loadFavorites()
            } else {
                title = "Songs"
                loadSongsFromDocumentsFolder()
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self

        // Load songs initially
        createSongsFolder()
        loadSongsFromDocumentsFolder()
    }

    // MARK: - Favorites Button Action
    @IBAction func favoritesButtonTapped(_ sender: UIBarButtonItem) {
        // Toggle the favorites flag.
        isShowingFavorites.toggle()
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

    // MARK: - Load All Songs from "Songs" Folder
    private func loadSongsFromDocumentsFolder() {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let songsFolder = documentsDirectory.appendingPathComponent("Songs")

        do {
            let allFiles = try fileManager.contentsOfDirectory(at: songsFolder, includingPropertiesForKeys: nil, options: [])
            let mp3Files = allFiles.filter { $0.pathExtension.lowercased() == "mp3" }
            songURLs = mp3Files

            if songURLs.isEmpty {
                showEmptyMessage("No music added.")
            } else {
                tableView.backgroundView = nil
            }

            tableView.reloadData()
        } catch {
            print("Error reading Songs folder: \(error)")
        }
    }

    // MARK: - Load Favorites
    private func loadFavorites() {
        songURLs = FavoriteManager.shared.allFavorites()
        print("Loading favorites, count: \(songURLs.count)")
        if songURLs.isEmpty {
            showEmptyMessage("No favorites yet.")
        } else {
            tableView.backgroundView = nil
        }
        tableView.reloadData()
    }

    // Show a center-aligned label if the table is empty
    private func showEmptyMessage(_ message: String) {
        let messageLabel = UILabel(frame: CGRect(x: 0, y: 0,width: tableView.bounds.size.width,height: tableView.bounds.size.height))
        messageLabel.text = message
        messageLabel.textColor = .gray
        messageLabel.textAlignment = .center
        messageLabel.font = UIFont.systemFont(ofSize: 20)
        messageLabel.numberOfLines = 0
        tableView.backgroundView = messageLabel
    }

    // MARK: - Add Song (+ Button)
    @IBAction func addSongButtonTapped(_ sender: UIBarButtonItem) {
        // Prevent adding songs in favorites mode.
        guard !isShowingFavorites else {
            print("Cannot add songs in Favorites mode.")
            return
        }

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.audio], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false

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

        var destinationURL = songsFolder.appendingPathComponent(songURL.lastPathComponent)
        var fileIndex = 1

        while fileManager.fileExists(atPath: destinationURL.path) {
            let newName = "\(songURL.deletingPathExtension().lastPathComponent)_\(fileIndex).\(songURL.pathExtension)"
            destinationURL = songsFolder.appendingPathComponent(newName)
            fileIndex += 1
        }

        do {
            if songURL.startAccessingSecurityScopedResource() {
                defer { songURL.stopAccessingSecurityScopedResource() }
                try fileManager.copyItem(at: songURL, to: destinationURL)
            } else {
                try fileManager.copyItem(at: songURL, to: destinationURL)
            }
            print("Song copied to: \(destinationURL)")
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

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return songURLs.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "SongCell", for: indexPath) as? MusicTableViewCell else {
            return UITableViewCell()
        }

        let audioURL = songURLs[indexPath.row]
        cell.configure(with: audioURL)
        cell.updateStar(isFavorite: FavoriteManager.shared.isFavorite(audioURL))
        cell.delegate = self
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let playerVC = storyboard.instantiateViewController(withIdentifier: "PlayerViewController") as? PlayerViewController {
            playerVC.allSongURLs = songURLs
            playerVC.currentIndex = indexPath.row
            navigationController?.pushViewController(playerVC, animated: true)
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return tableView.frame.width / 4.0
    }
}

// MARK: - Handling Favorite Taps from the cell
extension MusicViewController: MusicTableViewCellDelegate {
    func musicTableViewCell(_ cell: MusicTableViewCell, didTapFavoriteFor url: URL) {
        print("Favorite tapped for: \(url.lastPathComponent)")
        FavoriteManager.shared.toggleFavorite(url)
        print("Total favorites: \(FavoriteManager.shared.allFavorites().count)")

        // If we're in favorites mode, reload favorites so that unfavorited items vanish.
        if isShowingFavorites {
            loadFavorites()
        } else {
            if let indexPath = tableView.indexPath(for: cell) {
                tableView.reloadRows(at: [indexPath], with: .automatic)
            }
        }
    }
}
