//
//  Achievement.swift
//  WordChainLeague
//
//  Created by Saebyeok Jang on 6/25/25.
//

import Foundation

struct Achievement: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let iconName: String
    let experienceReward: Int
    let condition: AchievementCondition
    var isUnlocked: Bool = false
    var unlockedAt: Date?
    
    mutating func unlock() {
        isUnlocked = true
        unlockedAt = Date()
    }
}

enum AchievementCondition: Codable {
    case firstWin
    case winStreak(count: Int)
    case totalWins(count: Int)
    case totalGames(count: Int)
    case levelReached(level: Int)
    case wordsUsed(count: Int)
    case longWord(length: Int)
    
    func isCompleted(by user: User, gameSession: GameSession? = nil) -> Bool {
        switch self {
        case .firstWin:
            return user.wins >= 1
        case .winStreak(let count):
            return user.longestStreak >= count
        case .totalWins(let count):
            return user.wins >= count
        case .totalGames(let count):
            return user.totalGames >= count
        case .levelReached(let level):
            return user.level >= level
        case .wordsUsed(let count):
            return user.totalWords >= count
        case .longWord(let length):
            guard let session = gameSession else { return false }
            return session.words.contains { $0.word.length >= length }
        }
    }
}
