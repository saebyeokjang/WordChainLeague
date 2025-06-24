//
//  UserManager.swift
//  WordChainLeague
//
//  Created by Saebyeok Jang on 6/25/25.
//

import Foundation
import Combine

class UserManager: ObservableObject {
    @Published var currentUser: User?
    @Published var isLoggedIn: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let userDefaultsKey = "current_user"
    private let userListKey = "user_list"
    
    init() {
        loadCurrentUser()
    }
    
    /// 새 사용자 생성
    func createUser(nickname: String) async -> Result<User, UserError> {
        guard !nickname.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .failure(.invalidNickname("닉네임을 입력해주세요."))
        }
        
        let cleanNickname = nickname.trimmingCharacters(in: .whitespaces)
        
        guard cleanNickname.count >= 2 && cleanNickname.count <= 10 else {
            return .failure(.invalidNickname("닉네임은 2-10글자여야 합니다."))
        }
        
        // 닉네임 중복 체크
        if await isNicknameExists(cleanNickname) {
            return .failure(.nicknameAlreadyExists("이미 사용 중인 닉네임입니다."))
        }
        
        isLoading = true
        
        do {
            let newUser = User(id: UUID().uuidString, nickname: cleanNickname)
            try await saveUser(newUser)
            
            currentUser = newUser
            isLoggedIn = true
            isLoading = false
            
            print("새 사용자 생성: \(cleanNickname)")
            return .success(newUser)
            
        } catch {
            isLoading = false
            let userError = UserError.saveFailed("사용자 생성에 실패했습니다.")
            showError(userError.localizedDescription)
            return .failure(userError)
        }
    }
    
    /// 기존 사용자 로그인
    func loginUser(nickname: String) async -> Result<User, UserError> {
        guard !nickname.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .failure(.invalidNickname("닉네임을 입력해주세요."))
        }
        
        let cleanNickname = nickname.trimmingCharacters(in: .whitespaces)
        isLoading = true
        
        do {
            if let user = try await getUserByNickname(cleanNickname) {
                var updatedUser = user
                updatedUser.lastLoginDate = Date()
                
                try await saveUser(updatedUser)
                
                currentUser = updatedUser
                isLoggedIn = true
                isLoading = false
                
                print("사용자 로그인: \(cleanNickname)")
                return .success(updatedUser)
            } else {
                isLoading = false
                return .failure(.userNotFound("존재하지 않는 닉네임입니다."))
            }
        } catch {
            isLoading = false
            let userError = UserError.loadFailed("로그인에 실패했습니다.")
            showError(userError.localizedDescription)
            return .failure(userError)
        }
    }
    
    /// 사용자 로그아웃
    func logout() {
        currentUser = nil
        isLoggedIn = false
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        print("사용자 로그아웃")
    }
    
    /// 게스트 모드 로그인
    func loginAsGuest() {
        let guestUser = User(id: "guest_\(UUID().uuidString)", nickname: "게스트")
        currentUser = guestUser
        isLoggedIn = true
        print("게스트 모드 로그인")
    }
    
    /// 사용자 정보 업데이트
    func updateUser(_ user: User) {
        Task {
            do {
                try await saveUser(user)
                if currentUser?.id == user.id {
                    currentUser = user
                }
                print("사용자 정보 업데이트: \(user.nickname)")
            } catch {
                showError("사용자 정보 업데이트에 실패했습니다.")
            }
        }
    }
    
    /// 사용자 프로필 업데이트
    func updateProfile(nickname: String? = nil, profileImageURL: String? = nil) async -> Result<User, UserError> {
        guard var user = currentUser else {
            return .failure(.userNotFound("로그인된 사용자가 없습니다."))
        }
        
        if let newNickname = nickname {
            let cleanNickname = newNickname.trimmingCharacters(in: .whitespaces)
            
            guard cleanNickname.count >= 2 && cleanNickname.count <= 10 else {
                return .failure(.invalidNickname("닉네임은 2-10글자여야 합니다."))
            }
            
            // 현재 닉네임과 다른 경우에만 중복 체크
            if cleanNickname != user.nickname {
                if await isNicknameExists(cleanNickname) {
                    return .failure(.nicknameAlreadyExists("이미 사용 중인 닉네임입니다."))
                }
            }
            
            user.nickname = cleanNickname
        }
        
        if let imageURL = profileImageURL {
            user.profileImageURL = imageURL
        }
        
        do {
            try await saveUser(user)
            currentUser = user
            return .success(user)
        } catch {
            return .failure(.saveFailed("프로필 업데이트에 실패했습니다."))
        }
    }
    
    /// 게임 통계 업데이트
    func updateGameStats(
        gamesPlayed: Int = 0,
        wins: Int = 0,
        wordsUsed: Int = 0,
        longestStreak: Int = 0
    ) {
        guard var user = currentUser else { return }
        
        user.totalGames += gamesPlayed
        user.wins += wins
        user.totalWords += wordsUsed
        
        if longestStreak > user.longestStreak {
            user.longestStreak = longestStreak
        }
        
        updateUser(user)
    }
    
    /// 경험치 및 레벨 업데이트
    func updateExperience(_ experience: Int, level: Int) {
        guard var user = currentUser else { return }
        
        user.experience = experience
        user.level = level
        
        updateUser(user)
    }
    
    // MARK: - User Query Methods
    
    /// ID로 사용자 조회
    func getUser(id: String) -> User? {
        if let current = currentUser, current.id == id {
            return current
        }
        
        // 로컬에서 조회
        let users = getAllUsers()
        return users.first { $0.id == id }
    }
    
    /// 닉네임으로 사용자 조회
    func getUserByNickname(_ nickname: String) async throws -> User? {
        let users = getAllUsers()
        return users.first { $0.nickname == nickname }
    }
    
    /// 닉네임 중복 체크
    func isNicknameExists(_ nickname: String) async -> Bool {
        do {
            let user = try await getUserByNickname(nickname)
            return user != nil
        } catch {
            return false
        }
    }
    
    /// 모든 사용자 목록 조회
    func getAllUsers() -> [User] {
        guard let data = UserDefaults.standard.data(forKey: userListKey),
              let users = try? JSONDecoder().decode([User].self, from: data) else {
            return []
        }
        return users
    }
    
    /// 사용자 검색
    func searchUsers(query: String) -> [User] {
        let users = getAllUsers()
        guard !query.isEmpty else { return users }
        
        return users.filter { user in
            user.nickname.localizedCaseInsensitiveContains(query)
        }
    }
    
    /// 사용자 랭킹 조회
    func getUserRanking() -> UserRanking? {
        guard let user = currentUser else { return nil }
        
        let allUsers = getAllUsers().sorted { $0.experience > $1.experience }
        
        if let rank = allUsers.firstIndex(where: { $0.id == user.id }) {
            return UserRanking(
                user: user,
                rank: rank + 1,
                totalUsers: allUsers.count,
                percentile: Double(allUsers.count - rank) / Double(allUsers.count) * 100
            )
        }
        
        return nil
    }
    
    /// 리더보드 조회
    func getLeaderboard(limit: Int = 10) -> [User] {
        return getAllUsers()
            .sorted { $0.experience > $1.experience }
            .prefix(limit)
            .map { $0 }
    }
    
    /// 사용자 상세 통계
    func getUserDetailStats() -> UserDetailStats? {
        guard let user = currentUser else { return nil }
        
        let levelInfo = LevelSystem.getLevelInfo(for: user.experience)
        let ranking = getUserRanking()
        
        return UserDetailStats(
            user: user,
            levelInfo: levelInfo,
            ranking: ranking,
            averageWordsPerGame: user.totalGames > 0 ? Double(user.totalWords) / Double(user.totalGames) : 0,
            playDays: calculatePlayDays(since: user.joinDate),
            averageGamesPerDay: calculateAverageGamesPerDay(user: user)
        )
    }
    
    private func saveUser(_ user: User) async throws {
        // 현재 사용자 저장
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
        
        // 사용자 목록에 추가/업데이트
        var users = getAllUsers()
        
        if let index = users.firstIndex(where: { $0.id == user.id }) {
            users[index] = user
        } else {
            users.append(user)
        }
        
        if let data = try? JSONEncoder().encode(users) {
            UserDefaults.standard.set(data, forKey: userListKey)
        }
    }
    
    private func loadCurrentUser() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let user = try? JSONDecoder().decode(User.self, from: data) else {
            return
        }
        
        currentUser = user
        isLoggedIn = true
        print("저장된 사용자 로드: \(user.nickname)")
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        
        // 5초 후 에러 메시지 자동 제거
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            if self?.errorMessage == message {
                self?.errorMessage = nil
            }
        }
    }
    
    private func calculatePlayDays(since joinDate: Date) -> Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: joinDate, to: Date()).day ?? 0
        return max(1, days)
    }
    
    private func calculateAverageGamesPerDay(user: User) -> Double {
        let playDays = calculatePlayDays(since: user.joinDate)
        return playDays > 0 ? Double(user.totalGames) / Double(playDays) : 0
    }
    
    /// 계정 삭제
    func deleteAccount() async -> Result<Void, UserError> {
        guard let user = currentUser else {
            return .failure(.userNotFound("로그인된 사용자가 없습니다."))
        }
        
        // 사용자 목록에서 제거
        var users = getAllUsers()
        users.removeAll { $0.id == user.id }
        
        do {
            let data = try JSONEncoder().encode(users)
            UserDefaults.standard.set(data, forKey: userListKey)
        } catch {
            return .failure(.deleteFailed("계정 삭제에 실패했습니다."))
        }
        
        // 현재 사용자 정보 제거
        logout()
        
        print("계정 삭제 완료: \(user.nickname)")
        return .success(())
    }
    
    /// 데이터 백업
    func exportUserData() -> String? {
        guard let user = currentUser else { return nil }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        if let data = try? encoder.encode(user),
           let jsonString = String(data: data, encoding: .utf8) {
            return jsonString
        }
        
        return nil
    }
    
    /// 데이터 복원
    func importUserData(_ jsonString: String) async -> Result<User, UserError> {
        guard let data = jsonString.data(using: .utf8),
              let user = try? JSONDecoder().decode(User.self, from: data) else {
            return .failure(.invalidData("잘못된 데이터 형식입니다."))
        }
        
        do {
            try await saveUser(user)
            currentUser = user
            isLoggedIn = true
            
            print("사용자 데이터 복원 완료: \(user.nickname)")
            return .success(user)
            
        } catch {
            return .failure(.saveFailed("데이터 복원에 실패했습니다."))
        }
    }
    
    var isGuest: Bool {
        return currentUser?.id.hasPrefix("guest_") ?? false
    }
    
    var hasError: Bool {
        return errorMessage != nil
    }
    
    var currentUserStats: UserDetailStats? {
        return getUserDetailStats()
    }
}

enum UserError: LocalizedError {
    case invalidNickname(String)
    case nicknameAlreadyExists(String)
    case userNotFound(String)
    case saveFailed(String)
    case loadFailed(String)
    case deleteFailed(String)
    case invalidData(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidNickname(let message),
                .nicknameAlreadyExists(let message),
                .userNotFound(let message),
                .saveFailed(let message),
                .loadFailed(let message),
                .deleteFailed(let message),
                .invalidData(let message):
            return message
        }
    }
}

struct UserRanking {
    let user: User
    let rank: Int
    let totalUsers: Int
    let percentile: Double
    
    var rankingText: String {
        return "\(rank)위 / \(totalUsers)명"
    }
    
    var percentileText: String {
        return "상위 \(String(format: "%.1f", 100 - percentile))%"
    }
}

struct UserDetailStats {
    let user: User
    let levelInfo: LevelInfo
    let ranking: UserRanking?
    let averageWordsPerGame: Double
    let playDays: Int
    let averageGamesPerDay: Double
    
    var formattedAverageWords: String {
        return String(format: "%.1f", averageWordsPerGame)
    }
    
    var formattedAverageGames: String {
        return String(format: "%.1f", averageGamesPerDay)
    }
}

extension UserManager {
    
    /// 개발/테스트용 샘플 사용자
    static func createSampleUsers() -> [User] {
        return [
            User(id: "sample1", nickname: "끝말잇기왕"),
            User(id: "sample2", nickname: "단어수집가"),
            User(id: "sample3", nickname: "말잇기마스터")
        ].map { user in
            var sampleUser = user
            sampleUser.experience = Int.random(in: 1000...50000)
            sampleUser.totalGames = Int.random(in: 10...500)
            sampleUser.wins = Int.random(in: 5...sampleUser.totalGames)
            sampleUser.totalWords = Int.random(in: 100...2000)
            return sampleUser
        }
    }
    
    /// 사용자 활동 상태 확인
    func getUserActivityStatus() -> UserActivityStatus {
        guard let user = currentUser else { return .inactive }
        
        let daysSinceLastLogin = Calendar.current.dateComponents([.day], from: user.lastLoginDate, to: Date()).day ?? 0
        
        switch daysSinceLastLogin {
        case 0:
            return .active
        case 1...7:
            return .recentlyActive
        case 8...30:
            return .inactive
        default:
            return .dormant
        }
    }
}

enum UserActivityStatus: String, CaseIterable {
    case active = "활발"
    case recentlyActive = "최근 활동"
    case inactive = "비활성"
    case dormant = "휴면"
    
    var color: String {
        switch self {
        case .active: return "#00FF00"
        case .recentlyActive: return "#FFFF00"
        case .inactive: return "#FF8000"
        case .dormant: return "#FF0000"
        }
    }
}
