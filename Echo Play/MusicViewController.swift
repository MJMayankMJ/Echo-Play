//
//  MusicViewController.swift
//  Echo Play
//
//  Created by Mayank Jangid on 3/13/25.
//

import UIKit

class MusicViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var tableView: UITableView!
    
    // eg array of song URLs (replace these URLs with your actual song URLs)
    let songURLs: [URL] = [
        URL(string: "https://example.com/song1.mp3")!,
        URL(string: "https://example.com/song2.mp3")!,
        URL(string: "https://example.com/song3.mp3")!
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    // MARK: - TableView Data Source
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return songURLs.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SongCell", for: indexPath)
        cell.textLabel?.text = nil
        return cell
    }
    
    // MARK: - TableView Delegate
    
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
    
    // MARK: - Floating Button Action
    //    @IBAction func addSongTapped(_ sender: UIButton) {
    //        // Code to add a new song (e.g., show file picker or custom UI)
    //    }

}

