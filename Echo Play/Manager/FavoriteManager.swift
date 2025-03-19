//
//  FavoriteManager.swift
//  Echo Play
//
//  Created by Mayank Jangid on 3/19/25.
//

import Foundation

class FavoriteManager {
    static let shared = FavoriteManager()
    
    private init() {}
    
    private var favoriteSongs = Set<URL>()
    
    func isFavorite(_ songURL: URL) -> Bool {
        return favoriteSongs.contains(songURL)
    }
    
    func toggleFavorite(_ songURL: URL) {
            if isFavorite(songURL) {
                favoriteSongs.remove(songURL)
                print("Removed: \(songURL.lastPathComponent). Total favorites: \(favoriteSongs.count)")
            } else {
                favoriteSongs.insert(songURL)
                print("Added: \(songURL.lastPathComponent). Total favorites: \(favoriteSongs.count)")
            }
        }
    
    func allFavorites() -> [URL] {
        return Array(favoriteSongs)
    }
}
