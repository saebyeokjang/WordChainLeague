//
//  User.swift
//  WordChainLeague
//
//  Created by Saebyeok Jang on 6/25/25.
//

import Foundation

struct User: Codable, Identifiable {
    let id: String
    var nickname: String
    var profileImageURL: String?
    var level: Int
    var experience: Int
    var totalGames: Int
    var wins: Int
    var totalWords: Int
    var longestStreak: Int
    var joinDate: Date
    var lastLoginDate: Date
    
    var winRate: Double {
        totalGames == 0 ? 0 : Double(wins) / Double(totalGames) * 100
    }
    
    var levelInfo: LevelInfo {
        LevelSystem.getLevelInfo(for: experience)
    }
    
    init(id: String, nickname: String) {
        self.id = id
        self.nickname = nickname
        self.profileImageURL = nil
        self.level = 1
        self.experience = 0
        self.totalGames = 0
        self.wins = 0
        self.totalWords = 0
        self.longestStreak = 0
        self.joinDate = Date()
        self.lastLoginDate = Date()
    }
}
