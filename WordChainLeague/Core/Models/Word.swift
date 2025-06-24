//
//  Word.swift
//  WordChainLeague
//
//  Created by Saebyeok Jang on 6/25/25.
//

import Foundation

struct Word: Codable, Identifiable, Hashable {
    let id: UUID
    let text: String
    let firstChar: String
    let lastChar: String
    let length: Int
    let difficulty: WordDifficulty
    
    init(_ text: String) {
        self.id = UUID()
        self.text = text
        self.firstChar = String(text.first ?? " ")
        self.lastChar = String(text.last ?? " ")
        self.length = text.count
        self.difficulty = WordDifficulty.from(length: text.count)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, text, firstChar, lastChar, length, difficulty
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let existingId = try? container.decode(UUID.self, forKey: .id) {
            self.id = existingId
        } else {
            self.id = UUID()
        }
        
        self.text = try container.decode(String.self, forKey: .text)
        self.firstChar = try container.decode(String.self, forKey: .firstChar)
        self.lastChar = try container.decode(String.self, forKey: .lastChar)
        self.length = try container.decode(Int.self, forKey: .length)
        self.difficulty = try container.decode(WordDifficulty.self, forKey: .difficulty)
    }
    
    func isValidNext(after previousWord: Word) -> Bool {
        return previousWord.lastChar == self.firstChar
    }
    
    var firstCharacter: Character {
        firstChar.first ?? " "
    }
    
    var lastCharacter: Character {
        lastChar.first ?? " "
    }
    
    var experiencePoints: Int {
        switch difficulty {
        case .basic: return 5
        case .medium: return 8
        case .long: return 12
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(text)
    }
    
    static func == (lhs: Word, rhs: Word) -> Bool {
        return lhs.text == rhs.text
    }
}

enum WordDifficulty: String, Codable, CaseIterable {
    case basic = "기본"
    case medium = "중급"
    case long = "고급"
    
    static func from(length: Int) -> WordDifficulty {
        switch length {
        case 2...3: return .basic
        case 4...5: return .medium
        default: return .long
        }
    }
}
