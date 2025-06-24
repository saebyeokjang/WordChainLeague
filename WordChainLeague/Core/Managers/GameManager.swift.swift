//
//  GameManager.swift.swift
//  WordChainLeague
//
//  Created by Saebyeok Jang on 6/25/25.
//

import Foundation
import Combine

@MainActor
class GameManager: ObservableObject {
    @Published var currentSession: GameSession?
    @Published var gameState: GameState = .idle
    @Published var timeRemaining: TimeInterval = 15.0
    @Published var currentInput: String = ""
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false

    private let wordDictionary: WordDictionaryManager
    private let experienceManager: ExperienceManager
    private let userManager: UserManager
    private var timer: Timer?

    private var cancellables = Set<AnyCancellable>()
    
    init(
        wordDictionary: WordDictionaryManager? = nil,
        experienceManager: ExperienceManager? = nil,
        userManager: UserManager? = nil
    ) {
        self.wordDictionary = wordDictionary ?? WordDictionaryManager()
        self.experienceManager = experienceManager ?? ExperienceManager()
        self.userManager = userManager ?? UserManager()
    }
    
    /// 새 게임 시작
    func startGame(mode: GameMode, players: [String], timeLimit: TimeInterval = 15.0) {
        stopTimer()
        
        let session = GameSession(
            gameMode: mode,
            players: players,
            timeLimit: timeLimit
        )
        
        currentSession = session
        gameState = .waitingForPlayer
        timeRemaining = timeLimit
        clearInput()
        
        // 게임 시작
        var updatedSession = session
        updatedSession.startGame()
        currentSession = updatedSession
        gameState = .playing
        
        startTimer()
        
        print("게임 시작: \(mode.displayName), 플레이어: \(players.count)명")
    }
    
    /// 단어 제출
    func submitWord() {
        guard var session = currentSession,
              gameState == .playing,
              !currentInput.trimmingCharacters(in: .whitespaces).isEmpty else {
            return
        }
        
        let word = currentInput.trimmingCharacters(in: .whitespaces)
        let currentPlayer = session.currentPlayer
        
        // 단어 유효성 검사
        let validationResult = validateWord(word, in: session)
        
        switch validationResult {
        case .valid:
            // 단어 추가 성공
            if session.addWord(word, by: currentPlayer) {
                currentSession = session
                clearInput()
                resetTimer()
                
                // AI 턴인지 확인
                if session.gameMode == .aiPlayer && session.players.count > 1 {
                    handleAITurn()
                }
                
                print("단어 제출 성공: \(word)")
            } else {
                showError("단어 추가에 실패했습니다.")
            }
            
        case .invalid(let reason):
            showError(reason)
            print("단어 제출 실패: \(word) - \(reason)")
        }
    }
    
    /// 게임 종료
    func endGame(winner: String? = nil, reason: GameEndReason = .timeUp) {
        guard var session = currentSession else { return }
        
        stopTimer()
        session.endGame(winner: winner)
        currentSession = session
        gameState = .finished
        
        // 경험치 계산 및 지급
        calculateAndAwardExperience(session: session, endReason: reason)
        
        print("게임 종료: \(reason), 승자: \(winner ?? "없음")")
    }
    
    /// 게임 포기
    func forfeitGame() {
        guard let session = currentSession else { return }
        
        let currentPlayer = session.currentPlayer
        let otherPlayers = session.players.filter { $0 != currentPlayer }
        let winner = otherPlayers.first
        
        endGame(winner: winner, reason: .forfeit)
    }
    
    // MARK: - Word Validation
    
    private func validateWord(_ word: String, in session: GameSession) -> WordValidationResult {
        // 기본 검증
        guard word.count >= 2 else {
            return .invalid("2글자 이상 입력해주세요.")
        }
        
        // 한글 검증
        guard word.allSatisfy({ $0.isKorean }) else {
            return .invalid("한글만 입력 가능합니다.")
        }
        
        // 사전 검증
        guard wordDictionary.isValidWord(word) else {
            return .invalid("사전에 없는 단어입니다.")
        }
        
        // 중복 검증
        if session.words.contains(where: { $0.word.text == word }) {
            return .invalid("이미 사용된 단어입니다.")
        }
        
        // 연결 검증
        if let lastWord = session.lastWord {
            let newWord = Word(word)
            if !newWord.isValidNext(after: lastWord.word) {
                return .invalid("'\(lastWord.word.lastChar)'로 시작하는 단어를 입력하세요.")
            }
        }
        
        return .valid
    }
    
    private func startTimer() {
        guard currentSession != nil else { return }
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateTimer()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func resetTimer() {
        guard let session = currentSession else { return }
        timeRemaining = session.timeLimit
    }
    
    private func updateTimer() {
        timeRemaining -= 0.1
        
        if timeRemaining <= 0 {
            handleTimeUp()
        }
    }
    
    private func handleTimeUp() {
        guard let session = currentSession else { return }
        
        let currentPlayer = session.currentPlayer
        let otherPlayers = session.players.filter { $0 != currentPlayer }
        let winner = otherPlayers.first
        
        endGame(winner: winner, reason: .timeUp)
    }
    
    private func handleAITurn() {
        guard let session = currentSession,
              session.gameMode == .aiPlayer else { return }
        
        // AI 응답 시뮬레이션 (1-3초 대기)
        let aiDelay = Double.random(in: 1.0...3.0)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + aiDelay) { [weak self] in
            self?.performAIMove()
        }
    }
    
    private func performAIMove() {
        guard var session = currentSession,
              session.gameState == .playing else { return }
        
        let aiWord = generateAIWord(for: session)
        
        if let word = aiWord {
            if session.addWord(word, by: session.currentPlayer) {
                currentSession = session
                resetTimer()
                print("🤖 AI 단어: \(word)")
            } else {
                // AI 실패 시 플레이어 승리
                let humanPlayer = session.players.first { $0 != session.currentPlayer }
                endGame(winner: humanPlayer, reason: .aiError)
            }
        } else {
            // AI가 단어를 찾지 못함 - 플레이어 승리
            let humanPlayer = session.players.first { $0 != session.currentPlayer }
            endGame(winner: humanPlayer, reason: .aiError)
        }
    }
    
    private func generateAIWord(for session: GameSession) -> String? {
        let lastChar: String
        
        if let lastWord = session.lastWord {
            lastChar = lastWord.word.lastChar
        } else {
            // 첫 단어인 경우 랜덤 시작
            lastChar = ["가", "나", "다", "라", "마", "바", "사"].randomElement() ?? "가"
        }
        
        let usedWords = Set(session.words.map { $0.word.text })
        return wordDictionary.getRandomWord(startingWith: lastChar, excluding: usedWords)
    }
    
    private func calculateAndAwardExperience(session: GameSession, endReason: GameEndReason) {
        for playerID in session.players {
            guard var user = userManager.getUser(id: playerID) else { continue }
            
            var totalExp = 0
            
            // 게임 완주 경험치
            if endReason != .forfeit {
                totalExp += 20
            }
            
            // 단어별 경험치
            let playerWords = session.words.filter { $0.playerID == playerID }
            for gameWord in playerWords {
                totalExp += gameWord.word.experiencePoints
            }
            
            // 승리 경험치
            if session.winner == playerID {
                totalExp += 50
            } else if endReason == .timeUp || endReason == .aiError {
                totalExp += 15
            }
            
            // 경험치 적용
            experienceManager.addExperience(totalExp, to: &user)
            userManager.updateUser(user)
            
            print("\(user.nickname) 경험치: +\(totalExp)")
        }
    }
    
    private func clearInput() {
        currentInput = ""
        errorMessage = nil
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        
        // 3초 후 에러 메시지 자동 제거
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            if self?.errorMessage == message {
                self?.errorMessage = nil
            }
        }
    }
    
    var isGameActive: Bool {
        gameState == .playing || gameState == .waitingForPlayer
    }
    
    var currentPlayerName: String {
        guard let session = currentSession,
              let user = userManager.getUser(id: session.currentPlayer) else {
            return "알 수 없음"
        }
        return user.nickname
    }
    
    var usedWords: [GameWord] {
        currentSession?.words ?? []
    }
    
    var usedWordsCount: Int {
        currentSession?.words.count ?? 0
    }
    
    var lastUsedWord: String? {
        currentSession?.lastWord?.word.text
    }
    
    var nextRequiredChar: String? {
        currentSession?.lastWord?.word.lastChar
    }
}

enum GameState {
    case idle
    case waitingForPlayer
    case playing
    case finished
}

enum WordValidationResult {
    case valid
    case invalid(String)
}

enum GameEndReason {
    case timeUp
    case forfeit
    case aiError
    case invalidWord
}

extension GameSession {
    var gameState: GameState {
        switch status {
        case .waiting: return .waitingForPlayer
        case .playing: return .playing
        case .finished, .cancelled: return .finished
        }
    }
}
