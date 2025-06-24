//
//  GameSession.swift
//  WordChainLeague
//
//  Created by Saebyeok Jang on 6/25/25.
//

import Foundation

struct GameSession: Codable, Identifiable {
    let id: String
    let gameMode: GameMode
    let players: [String]
    var currentPlayerIndex: Int
    var words: [GameWord]
    var status: GameStatus
    var startTime: Date
    var endTime: Date?
    var winner: String?
    var timeLimit: TimeInterval
    
    init(gameMode: GameMode, players: [String], timeLimit: TimeInterval = 15) {
        self.id = UUID().uuidString
        self.gameMode = gameMode
        self.players = players
        self.currentPlayerIndex = 0
        self.words = []
        self.status = .waiting
        self.startTime = Date()
        self.endTime = nil
        self.winner = nil
        self.timeLimit = timeLimit
    }
    
    var currentPlayer: String {
        players[currentPlayerIndex]
    }
    
    var lastWord: GameWord? {
        words.last
    }
    
    var duration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }
    
    mutating func addWord(_ word: String, by playerID: String) -> Bool {
        guard status == .playing,
              currentPlayer == playerID,
              isValidWord(word) else {
            return false
        }
        
        let gameWord = GameWord(
            word: Word(word),
            playerID: playerID,
            timestamp: Date()
        )
        
        words.append(gameWord)
        nextTurn()
        return true
    }
    
    private func isValidWord(_ wordText: String) -> Bool {
        let word = Word(wordText)
        
        if words.contains(where: { $0.word.text == wordText }) {
            return false
        }
        
        if let lastWord = words.last {
            return word.isValidNext(after: lastWord.word)
        }
        
        return true
    }
    
    mutating func nextTurn() {
        currentPlayerIndex = (currentPlayerIndex + 1) % players.count
    }
    
    mutating func endGame(winner: String?) {
        self.status = .finished
        self.endTime = Date()
        self.winner = winner
    }
    
    mutating func startGame() {
        self.status = .playing
        self.startTime = Date()
    }
}

struct GameWord: Codable, Identifiable {
    let id: UUID
    let word: Word
    let playerID: String
    let timestamp: Date
    
    init(word: Word, playerID: String, timestamp: Date) {
        self.id = UUID()
        self.word = word
        self.playerID = playerID
        self.timestamp = timestamp
    }
    
    enum CodingKeys: String, CodingKey {
        case id, word, playerID, timestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let existingId = try? container.decode(UUID.self, forKey: .id) {
            self.id = existingId
        } else {
            self.id = UUID()
        }
        
        self.word = try container.decode(Word.self, forKey: .word)
        self.playerID = try container.decode(String.self, forKey: .playerID)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
    }
}

enum GameMode: String, Codable, CaseIterable {
    case singlePlayer = "single"
    case multiPlayer = "multi"
    case aiPlayer = "ai"
    
    var displayName: String {
        switch self {
        case .singlePlayer: return "혼자하기"
        case .multiPlayer: return "멀티플레이"
        case .aiPlayer: return "AI 대전"
        }
    }
}

enum GameStatus: String, Codable {
    case waiting = "waiting"
    case playing = "playing"
    case finished = "finished"
    case cancelled = "cancelled"
}
