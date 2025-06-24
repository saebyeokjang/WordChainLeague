//
//  ExperienceManager.swift
//  WordChainLeague
//
//  Created by Saebyeok Jang on 6/25/25.
//

import Foundation
import Combine

class ExperienceManager: ObservableObject {

    @Published var recentLevelUp: LevelUpInfo?

    private var cancellables = Set<AnyCancellable>()

    init() {
        
    }
    
    /// 사용자에게 경험치 추가
    func addExperience(_ amount: Int, to user: inout User) {
        guard amount > 0 else { return }
        
        let previousLevel = user.level
        _ = user.experience
        
        // 경험치 추가
        user.experience += amount
        
        // 레벨 업데이트
        let newLevelInfo = LevelSystem.getLevelInfo(for: user.experience)
        user.level = newLevelInfo.currentLevel
        
        // 레벨업 체크
        if newLevelInfo.currentLevel > previousLevel {
            handleLevelUp(
                user: user,
                previousLevel: previousLevel,
                newLevel: newLevelInfo.currentLevel,
                gainedExp: amount
            )
        }
        
        print("경험치 추가: \(user.nickname) +\(amount) EXP (총 \(user.experience) EXP)")
    }
    
    /// 게임 결과에 따른 경험치 계산 및 지급
    func calculateGameExperience(
        for gameSession: GameSession,
        playerID: String,
        gameResult: GameResult
    ) -> ExperienceBreakdown {
        
        var breakdown = ExperienceBreakdown()
        
        // 1. 게임 완주 경험치
        if gameResult != .forfeit {
            breakdown.gameCompletion = 20
        }
        
        // 2. 단어별 경험치
        let playerWords = gameSession.words.filter { $0.playerID == playerID }
        for gameWord in playerWords {
            breakdown.wordExperience += gameWord.word.experiencePoints
            breakdown.wordCount += 1
        }
        
        // 3. 게임 결과 경험치
        switch gameResult {
        case .victory:
            breakdown.gameResult = 50
        case .defeat:
            breakdown.gameResult = 0
        case .closeDefeat:
            breakdown.gameResult = 15
        case .forfeit:
            breakdown.gameResult = 0
        }
        
        // 4. 보너스 경험치
        breakdown.bonus = calculateBonusExperience(
            gameSession: gameSession,
            playerID: playerID,
            gameResult: gameResult
        )
        
        return breakdown
    }
    
    /// 일일 활동 경험치 지급
    func awardDailyActivityExperience(
        to user: inout User,
        activity: DailyActivity
    ) -> Int {
        let expAmount = activity.experienceReward
        
        // 중복 지급 방지 로직 (UserDefaults 사용)
        let todayKey = "daily_\(activity.rawValue)_\(getTodayString())"
        
        if UserDefaults.standard.bool(forKey: todayKey) {
            return 0
        }
        
        addExperience(expAmount, to: &user)
        UserDefaults.standard.set(true, forKey: todayKey)
        
        print("🎯 일일 활동 보상: \(activity.displayName) +\(expAmount) EXP")
        return expAmount
    }
    
    /// 업적 달성 경험치 지급
    func awardAchievementExperience(
        to user: inout User,
        achievement: Achievement
    ) -> Int {
        guard !achievement.isUnlocked else { return 0 }
        
        let expAmount = achievement.experienceReward
        addExperience(expAmount, to: &user)
        
        print("업적 달성: \(achievement.title) +\(expAmount) EXP")
        return expAmount
    }
    
    /// 다음 레벨까지 필요한 경험치 계산
    func getExperienceToNextLevel(for user: User) -> Int {
        let currentLevelInfo = LevelSystem.getLevelInfo(for: user.experience)
        return currentLevelInfo.expForNextLevel - user.experience
    }
    
    /// 레벨업 진행률 계산 (0.0 ~ 1.0)
    func getLevelProgress(for user: User) -> Double {
        let levelInfo = LevelSystem.getLevelInfo(for: user.experience)
        return levelInfo.progressToNextLevel
    }
    
    /// 경험치 통계 정보
    func getExperienceStats(for user: User) -> ExperienceStats {
        let levelInfo = LevelSystem.getLevelInfo(for: user.experience)
        let expToNext = getExperienceToNextLevel(for: user)
        let progress = getLevelProgress(for: user)
        
        return ExperienceStats(
            currentLevel: user.level,
            currentExperience: user.experience,
            experienceToNextLevel: expToNext,
            levelProgress: progress,
            totalExperienceNeeded: levelInfo.expForNextLevel,
            levelTitle: levelInfo.title,
            isMaxLevel: user.level >= 100
        )
    }
    
    /// 경험치 시뮬레이션 (테스트용)
    func simulateExperience(currentExp: Int, addedExp: Int) -> ExperienceSimulation {
        let beforeLevel = LevelSystem.getLevelInfo(for: currentExp)
        let afterLevel = LevelSystem.getLevelInfo(for: currentExp + addedExp)
        
        let levelUps = afterLevel.currentLevel - beforeLevel.currentLevel
        
        return ExperienceSimulation(
            beforeLevel: beforeLevel.currentLevel,
            afterLevel: afterLevel.currentLevel,
            levelUpsGained: levelUps,
            totalExperience: currentExp + addedExp,
            experienceGained: addedExp
        )
    }
    
    // MARK: - Private Methods
    
    private func handleLevelUp(
        user: User,
        previousLevel: Int,
        newLevel: Int,
        gainedExp: Int
    ) {
        let levelUpInfo = LevelUpInfo(
            playerName: user.nickname,
            previousLevel: previousLevel,
            newLevel: newLevel,
            newTitle: LevelSystem.getLevelInfo(for: user.experience).title,
            experienceGained: gainedExp,
            timestamp: Date()
        )
        
        // UI에 레벨업 알림 표시
        recentLevelUp = levelUpInfo
        
        // 3초 후 레벨업 알림 제거
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            if self?.recentLevelUp?.timestamp == levelUpInfo.timestamp {
                self?.recentLevelUp = nil
            }
        }
        
        // 레벨업 보상 지급
        awardLevelUpRewards(user: user, newLevel: newLevel)
        
        print("레벨업! \(user.nickname): Lv.\(previousLevel) → Lv.\(newLevel)")
    }
    
    private func calculateBonusExperience(
        gameSession: GameSession,
        playerID: String,
        gameResult: GameResult
    ) -> Int {
        var bonus = 0
        
        // 첫 게임 보너스 (하루 중 첫 게임)
        let firstGameKey = "first_game_\(getTodayString())_\(playerID)"
        if !UserDefaults.standard.bool(forKey: firstGameKey) {
            UserDefaults.standard.set(true, forKey: firstGameKey)
            bonus += 20
        }
        
        // 5게임 달성 보너스
        let fiveGamesKey = "five_games_\(getTodayString())_\(playerID)"
        if !UserDefaults.standard.bool(forKey: fiveGamesKey) {
            let todayGames = getTodayGameCount(for: playerID)
            if todayGames >= 5 {
                UserDefaults.standard.set(true, forKey: fiveGamesKey)
                bonus += 30
            }
        }
        
        // 긴 게임 보너스 (10개 이상 단어 사용)
        if gameSession.words.count >= 10 {
            bonus += 10
        }
        
        // 완벽한 게임 보너스 (모든 단어가 3글자 이상)
        let playerWords = gameSession.words.filter { $0.playerID == playerID }
        if playerWords.allSatisfy({ $0.word.length >= 3 }) && playerWords.count >= 3 {
            bonus += 15
        }
        
        return bonus
    }
    
    private func awardLevelUpRewards(user: User, newLevel: Int) {
        // 레벨업 보상 로직 (아이템, 칭호 등)
        // 이후 ItemManager, AchievementManager와 연동
        
        // 특별 레벨 보상
        switch newLevel {
        case 5:
            print("레벨 5 보상: 첫 번째 모자 획득!")
        case 10:
            print("레벨 10 보상: 특별 뱃지 획득!")
        case 20:
            print("레벨 20 보상: 희귀 의상 획득!")
        case 50:
            print("레벨 50 보상: 전설 아이템 획득!")
        default:
            if newLevel % 10 == 0 {
                print("레벨 \(newLevel) 보상: 특별 아이템 획득!")
            }
        }
    }
    
    private func getTodayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    private func getTodayGameCount(for playerID: String) -> Int {
        // 실제로는 UserManager나 데이터베이스에서 가져와야 함
        // 지금은 임시로 UserDefaults 사용
        let key = "game_count_\(getTodayString())_\(playerID)"
        return UserDefaults.standard.integer(forKey: key)
    }
    
    var hasRecentLevelUp: Bool {
        return recentLevelUp != nil
    }
}

struct ExperienceBreakdown {
    var gameCompletion: Int = 0
    var wordExperience: Int = 0
    var wordCount: Int = 0
    var gameResult: Int = 0
    var bonus: Int = 0
    
    var totalExperience: Int {
        return gameCompletion + wordExperience + gameResult + bonus
    }
    
    var description: String {
        var parts: [String] = []
        
        if gameCompletion > 0 {
            parts.append("게임 완주: +\(gameCompletion)")
        }
        if wordExperience > 0 {
            parts.append("단어 \(wordCount)개: +\(wordExperience)")
        }
        if gameResult > 0 {
            parts.append("게임 결과: +\(gameResult)")
        }
        if bonus > 0 {
            parts.append("보너스: +\(bonus)")
        }
        
        return parts.joined(separator: ", ")
    }
}

struct LevelUpInfo {
    let playerName: String
    let previousLevel: Int
    let newLevel: Int
    let newTitle: String
    let experienceGained: Int
    let timestamp: Date
    
    var levelUpMessage: String {
        return "🎉 \(playerName)님이 레벨 \(newLevel)에 도달했습니다!"
    }
    
    var titleMessage: String {
        return "새로운 칭호: \(newTitle)"
    }
}

struct ExperienceStats {
    let currentLevel: Int
    let currentExperience: Int
    let experienceToNextLevel: Int
    let levelProgress: Double
    let totalExperienceNeeded: Int
    let levelTitle: String
    let isMaxLevel: Bool
}

struct ExperienceSimulation {
    let beforeLevel: Int
    let afterLevel: Int
    let levelUpsGained: Int
    let totalExperience: Int
    let experienceGained: Int
    
    var willLevelUp: Bool {
        return levelUpsGained > 0
    }
}

enum GameResult {
    case victory
    case defeat
    case closeDefeat
    case forfeit
}

enum DailyActivity: String, CaseIterable {
    case firstGame = "first_game"
    case fiveGames = "five_games"
    case dailyMission = "daily_mission"
    case weeklyRanking = "weekly_ranking"
    
    var displayName: String {
        switch self {
        case .firstGame: return "첫 게임"
        case .fiveGames: return "5게임 달성"
        case .dailyMission: return "일일 미션 완료"
        case .weeklyRanking: return "주간 랭킹 10위 내"
        }
    }
    
    var experienceReward: Int {
        switch self {
        case .firstGame: return 20
        case .fiveGames: return 30
        case .dailyMission: return 50
        case .weeklyRanking: return 100
        }
    }
    
    var description: String {
        switch self {
        case .firstGame: return "하루 중 첫 번째 게임 플레이"
        case .fiveGames: return "하루에 5게임 플레이"
        case .dailyMission: return "일일 미션 모두 완료"
        case .weeklyRanking: return "주간 랭킹 10위 내 달성"
        }
    }
}

extension ExperienceManager {
    
    /// 경험치 배수 이벤트 (더블 EXP 등)
    func applyExperienceMultiplier(_ multiplier: Double, to amount: Int) -> Int {
        return Int(Double(amount) * multiplier)
    }
    
    /// 경험치 부스터 아이템 적용
    func applyExperienceBooster(_ boosterType: ExperienceBooster, to amount: Int) -> Int {
        switch boosterType {
        case .small:
            return Int(Double(amount) * 1.2) // 20% 증가
        case .medium:
            return Int(Double(amount) * 1.5) // 50% 증가
        case .large:
            return Int(Double(amount) * 2.0) // 100% 증가
        }
    }
    
    /// 레벨별 경험치 요구량 정보
    func getLevelRequirements(for level: Int) -> LevelRequirement {
        let levelInfo = LevelSystem.getLevelInfo(for: LevelSystem.getTotalExpForLevel(level))
        
        return LevelRequirement(
            level: level,
            totalExperienceNeeded: levelInfo.expForCurrentLevel,
            experienceFromPreviousLevel: level > 1 ?
                LevelSystem.getTotalExpForLevel(level) - LevelSystem.getTotalExpForLevel(level - 1) : 0,
            title: levelInfo.title
        )
    }
}

enum ExperienceBooster: String, CaseIterable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    
    var displayName: String {
        switch self {
        case .small: return "소형 경험치 부스터"
        case .medium: return "중형 경험치 부스터"
        case .large: return "대형 경험치 부스터"
        }
    }
    
    var multiplier: Double {
        switch self {
        case .small: return 1.2
        case .medium: return 1.5
        case .large: return 2.0
        }
    }
}

struct LevelRequirement {
    let level: Int
    let totalExperienceNeeded: Int
    let experienceFromPreviousLevel: Int
    let title: String
}
