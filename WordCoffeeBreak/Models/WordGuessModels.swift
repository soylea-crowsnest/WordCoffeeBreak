import Foundation

// MARK: - Letter Result

enum LetterResult: Equatable {
    case correct   // Green: right letter, right position
    case present   // Yellow: right letter, wrong position
    case absent    // Gray: letter not in word

    var spokenDescription: String {
        switch self {
        case .correct: return "green"
        case .present: return "yellow"
        case .absent: return "gray"
        }
    }
}

// MARK: - Guess Result

struct GuessResult {
    let guess: String
    let results: [LetterResult]

    var isAllCorrect: Bool {
        results.allSatisfy { $0 == .correct }
    }

    /// Generates spoken feedback like "S is green. T is yellow. A is gray. R is green. E is green."
    func spokenFeedback() -> String {
        let letters = Array(guess)
        var parts: [String] = []

        for (index, letter) in letters.enumerated() {
            let result = results[index]
            parts.append("\(letter) is \(result.spokenDescription)")
        }

        return parts.joined(separator: ". ") + "."
    }
}

// MARK: - Game State

enum WordGuessGameState {
    case playing
    case won(guessCount: Int)
    case lost(answer: String)
}

// MARK: - Word Guess Logic

struct WordGuessLogic {

    /// Compares a guess against the target word and returns letter-by-letter results.
    /// Uses Wordle's exact algorithm: greens first, then yellows for remaining unmatched letters.
    static func evaluate(guess: String, target: String) -> GuessResult {
        let guessLetters = Array(guess.uppercased())
        let targetLetters = Array(target.uppercased())

        guard guessLetters.count == 5, targetLetters.count == 5 else {
            fatalError("Both guess and target must be 5 letters")
        }

        var results: [LetterResult] = Array(repeating: .absent, count: 5)
        var targetRemaining: [Character] = targetLetters

        // First pass: mark correct (green) letters
        for i in 0..<5 {
            if guessLetters[i] == targetLetters[i] {
                results[i] = .correct
                // Remove from remaining pool (use a placeholder)
                if let idx = targetRemaining.firstIndex(of: guessLetters[i]) {
                    targetRemaining[idx] = "_"
                }
            }
        }

        // Second pass: mark present (yellow) letters
        for i in 0..<5 {
            if results[i] == .correct {
                continue // Already matched
            }

            if let idx = targetRemaining.firstIndex(of: guessLetters[i]) {
                results[i] = .present
                targetRemaining[idx] = "_" // Consume this letter
            }
        }

        return GuessResult(guess: guess.uppercased(), results: results)
    }
}
