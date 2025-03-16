//
//  MusicViewController.swift
//  Echo Play
//
//  Created by Mayank Jangid on 3/13/25.
//

import UIKit

class MusicViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var tableView: UITableView!
    
    var songURLs: [URL] = [
        URL(string: "https://example.com/song1.mp3")!,
        URL(string: "https://example.com/song2.mp3")!,
        URL(string: "https://example.com/song3.mp3")!
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    // MARK: + button
    
    @IBAction func addSongButtonTapped(_ sender: UIBarButtonItem) {
        let alert = UIAlertController(title: "Add Song",
                                      message: "Enter the URL of the song",
                                      preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "https://example.com/song.mp3"
        }
        
        let addAction = UIAlertAction(title: "Add", style: .default) { [weak self] _ in
            guard let self = self,
                  let text = alert.textFields?.first?.text,
                  let url = URL(string: text) else {
                return
            }
            
            // validatn
            let validExtensions = ["mp3", "wav", "m4a", "mp4"]
            let fileExtension = url.pathExtension.lowercased()
            
            if validExtensions.contains(fileExtension) {
                self.songURLs.append(url)
                self.tableView.reloadData()
            } else {
                let errorAlert = UIAlertController(title: "Invalid URL",
                                                   message: "Only .mp3, .mp4, .wav, or .m4a are allowed.",
                                                   preferredStyle: .alert)
                errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(errorAlert, animated: true)
            }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alert.addAction(addAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    // MARK: - Data Source
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return songURLs.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Use your custom cell
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "SongCell", for: indexPath) as? MusicTableViewCell else {
            return UITableViewCell()
        }
        
        let audioURL = songURLs[indexPath.row]
        
        // using the URL's last path component for the title
        cell.titleLabel.text = audioURL.lastPathComponent
        
        // default image, or use your own asset
        cell.iconImageView.image = UIImage(systemName: "music.note")
        
        // fill durationLabel if you have a way to get the duration, otherwise leave blank
        cell.durationLabel.text = ""
        
        return cell
    }
    
    // MARK: - Delegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let playerVC = storyboard.instantiateViewController(withIdentifier: "PlayerViewController") as? PlayerViewController {
            
            let audioURL = songURLs[indexPath.row]
            AudioPlayerManager.shared.playSound(from: audioURL)
            
            navigationController?.pushViewController(playerVC, animated: true)
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return tableView.frame.width / 4.0
    }
}
