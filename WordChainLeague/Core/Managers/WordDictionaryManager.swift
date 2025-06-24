//
//  WordDictionaryManager.swift
//  WordChainLeague
//
//  Created by Saebyeok Jang on 6/25/25.
//

import Foundation

class WordDictionaryManager: ObservableObject {
    private var wordDictionary: Set<String> = []
    private var wordsByFirstChar: [String: [String]] = [:]
    private var wordsByLastChar: [String: [String]] = [:]
    private var isLoaded: Bool = false
    
    init() {
        loadDictionary()
    }
    
    /// 단어가 사전에 있는지 확인
    func isValidWord(_ word: String) -> Bool {
        let normalizedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        return wordDictionary.contains(normalizedWord)
    }
    
    /// 특정 글자로 시작하는 랜덤 단어 반환 (제외 단어 고려)
    func getRandomWord(startingWith firstChar: String, excluding excludedWords: Set<String> = []) -> String? {
        guard let words = wordsByFirstChar[firstChar] else {
            return nil
        }
        
        let availableWords = words.filter { !excludedWords.contains($0) }
        return availableWords.randomElement()
    }
    
    /// 특정 글자로 시작하는 모든 단어 반환
    func getWords(startingWith firstChar: String) -> [String] {
        return wordsByFirstChar[firstChar] ?? []
    }
    
    /// 특정 글자로 끝나는 모든 단어 반환
    func getWords(endingWith lastChar: String) -> [String] {
        return wordsByLastChar[lastChar] ?? []
    }
    
    /// 단어 검색
    func searchWords(containing query: String) -> [String] {
        guard !query.isEmpty else { return [] }
        
        return Array(wordDictionary)
            .filter { $0.contains(query) }
            .sorted()
            .prefix(50)
            .map { String($0) }
    }
    
    /// 사전 통계 정보
    func getDictionaryStats() -> DictionaryStats {
        return DictionaryStats(
            totalWords: wordDictionary.count,
            uniqueFirstChars: wordsByFirstChar.keys.count,
            uniqueLastChars: wordsByLastChar.keys.count,
            averageWordLength: calculateAverageWordLength(),
            isLoaded: isLoaded
        )
    }
    
    /// 특정 글자로 시작하는 단어 개수
    func getWordCount(startingWith firstChar: String) -> Int {
        return wordsByFirstChar[firstChar]?.count ?? 0
    }
    
    /// AI가 사용할 전략적 단어 선택
    func getStrategicWord(startingWith firstChar: String, difficulty: AIDifficulty, excluding excludedWords: Set<String> = []) -> String? {
        guard let words = wordsByFirstChar[firstChar] else {
            return nil
        }
        
        let availableWords = words.filter { !excludedWords.contains($0) }
        
        switch difficulty {
        case .easy:
            return getEasyWord(from: availableWords)
        case .medium:
            return getMediumWord(from: availableWords)
        case .hard:
            return getHardWord(from: availableWords)
        }
    }
    
    // MARK: - Private Methods
    
    private func loadDictionary() {
        // 우선 기본 단어들로 초기화 (실제로는 JSON 파일에서 로드)
        loadDefaultWords()
        
        // JSON 파일에서 단어 로드 시도
        if let path = Bundle.main.path(forResource: "words", ofType: "json") {
            loadWordsFromFile(path: path)
        }
        
        // 색인 생성
        buildIndices()
        
        isLoaded = true
        print("사전 로드 완료: \(wordDictionary.count)개 단어")
    }
    
    private func loadDefaultWords() {
        let defaultWords = [
            // 음식
            "사과", "과자", "자두", "두부", "부침개", "개구리", "리본", "본체",
            "체리", "리듬", "듬직", "직장", "장미", "미역", "역사", "사람",
            "람보", "보리", "리스", "스위치", "치킨", "킨더", "더위", "위험",
            
            // 동물
            "고양이", "이구아나", "나비", "비둘기", "기린", "린스", "스님", "님프",
            "프라이팬", "팬더", "더치", "치타", "타조", "조개", "개미", "미끄럼틀",
            "틀니", "니켈", "켈프", "프로그램", "램프", "프린터", "터키", "키위",
            
            // 일상용품
            "연필", "필통", "통장", "장갑", "갑옷", "옷장", "장난감", "감자",
            "자석", "석유", "유리", "리모컨", "컨테이너", "너구리", "리본", "본드",
            "드라이버", "버스", "스마트폰", "폰카", "카메라", "라면", "면도기", "기타",
            
            // 자연
            "나무", "무지개", "개울", "울음", "음성", "성산", "산소", "소나무",
            "무궁화", "화산", "산업", "업무", "무역", "역할", "할머니", "니트",
            "트럭", "럭키", "키노", "노을", "을지로", "로봇", "봇물", "물고기",
            
            // 추가 단어들
            "가위", "위로", "로또", "또래", "래퍼", "퍼즐", "즐거움", "움직임",
            "김치", "치즈", "즈음", "음료", "료리", "리터", "터널", "널빤지",
            "지갑", "갑자기", "기차", "차례", "례의", "의사", "사진", "진주",
            "주스", "스타", "타이어", "어린이", "이름", "름차순", "순간", "간식",
            "식당", "당근", "근육", "육류", "류머티즘", "즘새", "새벽", "벽돌",
            "돌멩이", "이야기", "기분", "분수", "수박", "박수", "수영", "영화"
        ]
        
        wordDictionary = Set(defaultWords)
    }
    
    private func loadWordsFromFile(path: String) {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let wordsArray = try JSONDecoder().decode([String].self, from: data)
            
            // 기존 단어와 병합
            for word in wordsArray {
                let cleanWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleanWord.isEmpty && cleanWord.count >= 2 {
                    wordDictionary.insert(cleanWord)
                }
            }
        } catch {
            print("words.json 파일 로드 실패: \(error.localizedDescription)")
        }
    }
    
    private func buildIndices() {
        wordsByFirstChar.removeAll()
        wordsByLastChar.removeAll()
        
        for word in wordDictionary {
            let firstChar = String(word.prefix(1))
            let lastChar = String(word.suffix(1))
            
            // 첫 글자 인덱스
            if wordsByFirstChar[firstChar] == nil {
                wordsByFirstChar[firstChar] = []
            }
            wordsByFirstChar[firstChar]?.append(word)
            
            // 마지막 글자 인덱스
            if wordsByLastChar[lastChar] == nil {
                wordsByLastChar[lastChar] = []
            }
            wordsByLastChar[lastChar]?.append(word)
        }
        
        // 정렬
        for key in wordsByFirstChar.keys {
            wordsByFirstChar[key]?.sort()
        }
        
        for key in wordsByLastChar.keys {
            wordsByLastChar[key]?.sort()
        }
    }
    
    private func calculateAverageWordLength() -> Double {
        guard !wordDictionary.isEmpty else { return 0 }
        
        let totalLength = wordDictionary.reduce(0) { $0 + $1.count }
        return Double(totalLength) / Double(wordDictionary.count)
    }
    
    private func getEasyWord(from words: [String]) -> String? {
        // 쉬운 난이도: 흔한 끝 글자로 끝나는 단어 선택
        let commonEndChars = ["이", "가", "다", "리", "기", "미", "사", "자"]
        
        let easyWords = words.filter { word in
            let lastChar = String(word.suffix(1))
            return commonEndChars.contains(lastChar)
        }
        
        return easyWords.randomElement() ?? words.randomElement()
    }
    
    private func getMediumWord(from words: [String]) -> String? {
        // 중간 난이도: 적당히 어려운 끝 글자 선택
        let mediumEndChars = ["음", "름", "은", "을", "업", "입", "옵"]
        
        let mediumWords = words.filter { word in
            let lastChar = String(word.suffix(1))
            return mediumEndChars.contains(lastChar)
        }
        
        return mediumWords.randomElement() ?? words.randomElement()
    }
    
    private func getHardWord(from words: [String]) -> String? {
        // 어려운 난이도: 어려운 끝 글자로 끝나는 단어 선택
        let hardEndChars = ["늠", "읽", "닦", "곡", "욕", "틈", "흠"]
        
        let hardWords = words.filter { word in
            let lastChar = String(word.suffix(1))
            return hardEndChars.contains(lastChar) ||
                   getWordCount(startingWith: lastChar) <= 3
        }
        
        return hardWords.randomElement() ??
               words.filter { $0.count >= 4 }.randomElement() ??
               words.randomElement()
    }
    
    /// 단어 추가 (커스텀 단어)
    func addCustomWord(_ word: String) -> Bool {
        let cleanWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard cleanWord.count >= 2,
              cleanWord.allSatisfy({ $0.isKorean }),
              !wordDictionary.contains(cleanWord) else {
            return false
        }
        
        wordDictionary.insert(cleanWord)
        
        // 인덱스 업데이트
        let firstChar = String(cleanWord.prefix(1))
        let lastChar = String(cleanWord.suffix(1))
        
        if wordsByFirstChar[firstChar] == nil {
            wordsByFirstChar[firstChar] = []
        }
        wordsByFirstChar[firstChar]?.append(cleanWord)
        wordsByFirstChar[firstChar]?.sort()
        
        if wordsByLastChar[lastChar] == nil {
            wordsByLastChar[lastChar] = []
        }
        wordsByLastChar[lastChar]?.append(cleanWord)
        wordsByLastChar[lastChar]?.sort()
        
        return true
    }
    
    /// 힌트 제공
    func getHint(startingWith firstChar: String, excluding excludedWords: Set<String> = []) -> String? {
        guard let words = wordsByFirstChar[firstChar] else { return nil }
        
        let availableWords = words.filter { !excludedWords.contains($0) }
        guard let word = availableWords.randomElement() else { return nil }
        
        // 단어의 첫 2글자만 힌트로 제공
        let hintLength = min(2, word.count)
        return String(word.prefix(hintLength)) + "..."
    }
}

struct DictionaryStats {
    let totalWords: Int
    let uniqueFirstChars: Int
    let uniqueLastChars: Int
    let averageWordLength: Double
    let isLoaded: Bool
}

enum AIDifficulty: String, CaseIterable {
    case easy = "쉬움"
    case medium = "보통"
    case hard = "어려움"
    
    var displayName: String {
        return rawValue
    }
    
    var description: String {
        switch self {
        case .easy:
            return "AI가 쉬운 단어를 사용합니다"
        case .medium:
            return "AI가 적당한 난이도의 단어를 사용합니다"
        case .hard:
            return "AI가 어려운 단어를 사용합니다"
        }
    }
}

extension Character {
    var isKorean: Bool {
        let scalar = self.unicodeScalars.first!
        return (0xAC00...0xD7AF).contains(scalar.value) || // 한글 완성형
               (0x1100...0x11FF).contains(scalar.value) || // 한글 자모
               (0x3130...0x318F).contains(scalar.value)    // 한글 호환 자모
    }
}
