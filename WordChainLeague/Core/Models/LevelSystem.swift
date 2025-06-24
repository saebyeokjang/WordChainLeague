//
//  LevelSystem.swift
//  WordChainLeague
//
//  Created by Saebyeok Jang on 6/25/25.
//

import Foundation

struct LevelInfo {
    let currentLevel: Int
    let currentExp: Int
    let expForCurrentLevel: Int
    let expForNextLevel: Int
    let progressToNextLevel: Double
    let title: String
}

struct LevelSystem {
    private static let levelTable: [Int: Int] = [
        1: 0, 2: 100, 3: 230, 4: 390, 5: 590,
        6: 830, 7: 1110, 8: 1430, 9: 1790, 10: 2190,
        11: 2640, 15: 4940, 20: 8940, 25: 14190, 30: 20690,
        35: 28440, 40: 37440, 45: 47840, 50: 59740, 55: 73140,
        60: 88340, 65: 105540, 70: 124740, 75: 146240, 80: 170240,
        85: 196740, 90: 225740, 95: 258740, 100: 296740
    ]
    
    static func getLevelInfo(for experience: Int) -> LevelInfo {
        let currentLevel = getLevelFromExp(experience)
        let expForCurrentLevel = getTotalExpForLevel(currentLevel)
        let expForNextLevel = getTotalExpForLevel(currentLevel + 1)
        let progressExp = experience - expForCurrentLevel
        let neededExp = expForNextLevel - expForCurrentLevel
        let progress = neededExp > 0 ? Double(progressExp) / Double(neededExp) : 1.0
        
        return LevelInfo(
            currentLevel: currentLevel,
            currentExp: experience,
            expForCurrentLevel: expForCurrentLevel,
            expForNextLevel: expForNextLevel,
            progressToNextLevel: max(0, min(1, progress)),
            title: getTitleForLevel(currentLevel)
        )
    }
    
    private static func getLevelFromExp(_ exp: Int) -> Int {
        for level in stride(from: 100, through: 1, by: -1) {
            if exp >= getTotalExpForLevel(level) {
                return level
            }
        }
        return 1
    }
    
    private static func getTotalExpForLevel(_ level: Int) -> Int {
        let targetLevel = min(level, 100)
        
        if let exactValue = levelTable[targetLevel] {
            return exactValue
        }
        
        return interpolateExp(for: targetLevel)
    }
    
    private static func interpolateExp(for level: Int) -> Int {
        let targetLevel = min(level, 100)
        
        if let exactValue = levelTable[targetLevel] {
            return exactValue
        }
        
        let keys = levelTable.keys.sorted()
        
        guard let lowerKey = keys.last(where: { $0 <= targetLevel }),
              let upperKey = keys.first(where: { $0 > targetLevel }) else {
            return levelTable[100] ?? 296740
        }
        
        let lowerExp = levelTable[lowerKey]!
        let upperExp = levelTable[upperKey]!
        let ratio = Double(targetLevel - lowerKey) / Double(upperKey - lowerKey)
        
        return lowerExp + Int(Double(upperExp - lowerExp) * ratio)
    }
    
    private static func getTitleForLevel(_ level: Int) -> String {
        switch level {
        case 1...5: return "새싹"
        case 6...15: return "초보자"
        case 16...30: return "견습생"
        case 31...50: return "숙련자"
        case 51...70: return "전문가"
        case 71...85: return "대가"
        case 86...100: return "마스터"
        default: return "최고 마스터"
        }
    }
}
