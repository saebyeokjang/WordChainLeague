//
//  CharacterItem.swift
//  WordChainLeague
//
//  Created by Saebyeok Jang on 6/25/25.
//

import Foundation

struct CharacterItem: Codable, Identifiable {
    let id: String
    let name: String
    let category: ItemCategory
    let rarity: ItemRarity
    let imageName: String
    let price: Int?
    let unlockCondition: UnlockCondition?
    var isOwned: Bool = false
    var purchasedAt: Date?
    
    mutating func purchase() {
        isOwned = true
        purchasedAt = Date()
    }
}

enum ItemCategory: String, Codable, CaseIterable {
    case hat = "모자"
    case clothing = "의상"
    case accessory = "액세서리"
    case background = "배경"
    case effect = "이펙트"
    
    var displayName: String {
        return rawValue
    }
}

enum ItemRarity: String, Codable, CaseIterable {
    case common = "일반"
    case rare = "희귀"
    case epic = "에픽"
    case legendary = "전설"
    
    var color: String {
        switch self {
        case .common: return "#808080"
        case .rare: return "#0080FF"
        case .epic: return "#8000FF"
        case .legendary: return "#FF8000"
        }
    }
}

enum UnlockCondition: Codable {
    case level(Int)
    case achievement(String)
    case purchase
    case event
    
    func isUnlocked(by user: User) -> Bool {
        switch self {
        case .level(let requiredLevel):
            return user.level >= requiredLevel
        case .achievement:
            
            return false
        case .purchase:
            return true
        case .event:
            return false
        }
    }
}
