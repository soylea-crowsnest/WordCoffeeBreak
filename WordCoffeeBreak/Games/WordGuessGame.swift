import Foundation

class WordGuessGame {
    private let turnManager: TurnManager
    private let services = AppServices.shared

    // Game state
    private var targetWord: String = ""
    private var guessHistory: [GuessResult] = []
    private var gameState: WordGuessGameState = .playing
    private var lastSpokenMessage: String = ""

    private let maxGuesses = 6

    // Thinking pause phrases
    private let thinkingPhrases: Set<String> = [
        "WAIT", "HOLD", "HOLD ON", "NEED TIME", "THINKING",
        "NEED A MINUTE", "NEED A MOMENT", "ONE MOMENT",
        "PAUSE", "JUST A MOMENT", "HANG ON", "LET ME THINK",
        "NEED MORE TIME", "STAY", "ONE SECOND", "SEC"
    ]

    private let resumePhrases: Set<String> = [
        "READY", "START", "BEGIN", "GO", "OK", "OKAY",
        "BEGIN AGAIN", "START AGAIN", "CONTINUE", "YES",
        "I'M READY", "GUESS", "BACK"
    ]

    init(turnManager: TurnManager) {
        self.turnManager = turnManager
    }

    // MARK: - Public API

    func start() {
        print("[WordGuessGame] Starting new game")
        resetGame()
        sayGreeting()
    }

    // MARK: - Game Flow

    private func resetGame() {
        targetWord = WordLists.randomAnswer()
        guessHistory = []
        gameState = .playing
        print("[WordGuessGame] Target word: \(targetWord)")
    }

    private func sayGreeting() {
        let greeting = "Word Guess. I'm thinking of a 5 letter word. You have \(maxGuesses) guesses. Say WAIT if you need time to think. What's your first guess?"
        speakAndListen(greeting)
    }

    private func handleInput(_ parsed: ParsedCommand) {
        let upper = parsed.normalizedInput.uppercased()

        // Check for thinking/pause phrases first
        if isThinkingPhrase(upper) {
            enterThinkingMode()
            return
        }

        // Check for guess recall requests
        if let recallResponse = handleRecallRequest(upper) {
            speakAndListen(recallResponse)
            return
        }

        // Handle global commands
        if let command = parsed.globalCommand {
            handleGlobalCommand(command, parsed: parsed)
            return
        }

        // Process the guess
        let input = parsed.normalizedInput

        // Validate: must be 5 letters
        guard input.count == 5 else {
            promptForValidWord(reason: "Please say a 5 letter word. Say WAIT if you need more time.")
            return
        }

        // Validate: must be alphabetic
        guard input.allSatisfy({ $0.isLetter }) else {
            promptForValidWord(reason: "Please say a word using only letters.")
            return
        }

        // Validate: must be a known word
        guard WordLists.isValidGuess(input) else {
            promptForValidWord(reason: "I don't recognize \(spelledOut(input)). Try another word.")
            return
        }

        // Valid guess - evaluate it
        processGuess(input)
    }

    // MARK: - Guess Recall

    /// Checks if the input is asking to recall a previous guess. Returns the spoken response, or nil.
    private func handleRecallRequest(_ input: String) -> String? {
        guard !guessHistory.isEmpty else {
            // Check if they're asking about guesses when none have been made
            if input.contains("GUESS") && (input.contains("WHAT") || input.contains("MY") || input.contains("RECAP") || input.contains("ALL")) {
                return "You haven't guessed yet. What's your first guess?"
            }
            return nil
        }

        // "Recap" / "all guesses" / "my guesses" / "read them back" / "summary"
        if input.contains("RECAP") || input.contains("ALL GUESS") || input.contains("MY GUESS")
            || input.contains("SUMMARY") || input.contains("READ THEM") || input.contains("READ BACK")
            || input.contains("SO FAR") {
            return recapAllGuesses()
        }

        // "First guess" / "guess 1" / "guess one"
        if let number = extractGuessNumber(from: input) {
            return recallGuess(number: number)
        }

        // "Last guess" / "previous guess"
        if input.contains("LAST GUESS") || input.contains("PREVIOUS GUESS") {
            return recallGuess(number: guessHistory.count)
        }

        return nil
    }

    /// Extracts a guess number from input like "guess 1", "first guess", "guess one", "number 3"
    private func extractGuessNumber(from input: String) -> Int? {
        // Only trigger if they're actually asking about a guess
        guard input.contains("GUESS") || input.contains("NUMBER") else { return nil }

        let ordinalMap: [(String, Int)] = [
            ("FIRST", 1), ("SECOND", 2), ("THIRD", 3),
            ("FOURTH", 4), ("FIFTH", 5), ("SIXTH", 6),
        ]
        for (word, num) in ordinalMap {
            if input.contains(word) { return num }
        }

        let numberWordMap: [(String, Int)] = [
            ("ONE", 1), ("TWO", 2), ("THREE", 3),
            ("FOUR", 4), ("FIVE", 5), ("SIX", 6),
        ]
        for (word, num) in numberWordMap {
            if input.contains(word) { return num }
        }

        // Try digit: "guess 3"
        for char in input {
            if let digit = char.wholeNumberValue, digit >= 1, digit <= 6 {
                return digit
            }
        }

        return nil
    }

    private func recallGuess(number: Int) -> String {
        guard number >= 1, number <= guessHistory.count else {
            if number > guessHistory.count {
                return "You've only made \(guessHistory.count) \(guessHistory.count == 1 ? "guess" : "guesses") so far. What's your next guess?"
            }
            return "What's your guess?"
        }

        let result = guessHistory[number - 1]
        return "Guess \(number) was \(spelledOut(result.guess)). \(result.spokenFeedback()) What's your next guess?"
    }

    private func recapAllGuesses() -> String {
        var parts: [String] = []
        for (index, result) in guessHistory.enumerated() {
            parts.append("Guess \(index + 1), \(spelledOut(result.guess)). \(result.spokenFeedback())")
        }

        let remaining = maxGuesses - guessHistory.count
        let recap = parts.joined(separator: " ")
        return "\(recap) \(remaining) \(remaining == 1 ? "guess" : "guesses") left. What's your next guess?"
    }

    /// Convenience: speak a message then listen for the next guess
    private func speakAndListen(_ message: String) {
        lastSpokenMessage = message
        turnManager.beginTurn(
            speak: message,
            expectingInput: wordInputSpec(),
            listenAfterSpeech: true
        ) { [weak self] parsed in
            self?.handleInput(parsed)
        }
    }

    // MARK: - Thinking Mode

    private func isThinkingPhrase(_ input: String) -> Bool {
        // Check exact matches
        if thinkingPhrases.contains(input) { return true }
        // Check if input contains a thinking phrase
        for phrase in thinkingPhrases {
            if input.contains(phrase) { return true }
        }
        return false
    }

    private func isResumePhrase(_ input: String) -> Bool {
        if resumePhrases.contains(input) { return true }
        for phrase in resumePhrases {
            if input.contains(phrase) { return true }
        }
        return false
    }

    private func enterThinkingMode() {
        let guessNumber = guessHistory.count
        let remaining = maxGuesses - guessNumber

        let message: String
        if guessNumber == 0 {
            message = "Take your time. Say READY when you want to guess."
        } else {
            message = "Take your time. You have \(remaining) \(remaining == 1 ? "guess" : "guesses") left. Say READY when you want to guess."
        }
        lastSpokenMessage = message

        turnManager.beginTurn(
            speak: message,
            expectingInput: thinkingInputSpec(),
            listenAfterSpeech: true
        ) { [weak self] parsed in
            self?.handleThinkingInput(parsed)
        }
    }

    private func handleThinkingInput(_ parsed: ParsedCommand) {
        let upper = parsed.normalizedInput.uppercased()

        // Quit always works
        if parsed.globalCommand == .quit {
            sayGoodbye()
            return
        }

        // Repeat always works - replay last message, stay in thinking mode
        if parsed.globalCommand == .repeat {
            turnManager.beginTurn(
                speak: lastSpokenMessage,
                expectingInput: thinkingInputSpec(),
                listenAfterSpeech: true
            ) { [weak self] parsed in
                self?.handleThinkingInput(parsed)
            }
            return
        }

        // Guess recall works while thinking too
        if let recallResponse = handleRecallRequest(upper) {
            // After recall, go back to thinking mode (not guess mode)
            turnManager.beginTurn(
                speak: recallResponse,
                expectingInput: thinkingInputSpec(),
                listenAfterSpeech: true
            ) { [weak self] parsed in
                self?.handleThinkingInput(parsed)
            }
            return
        }

        // Still thinking? Stay in thinking mode
        if isThinkingPhrase(upper) {
            // Just listen again silently - no need to repeat the message
            turnManager.beginTurn(
                speak: "No rush.",
                expectingInput: thinkingInputSpec(),
                listenAfterSpeech: true
            ) { [weak self] parsed in
                self?.handleThinkingInput(parsed)
            }
            return
        }

        // Ready to resume? Or said a 5-letter word directly?
        if isResumePhrase(upper) {
            promptForGuess()
            return
        }

        // They might have just said their guess directly - try to handle it
        if upper.count == 5 && upper.allSatisfy({ $0.isLetter }) {
            handleInput(parsed)
            return
        }

        // Unknown input while thinking - stay in thinking mode
        promptForGuess()
    }

    private func promptForGuess() {
        let message = "What's your guess?"
        turnManager.beginTurn(
            speak: message,
            expectingInput: wordInputSpec(),
            listenAfterSpeech: true
        ) { [weak self] parsed in
            self?.handleInput(parsed)
        }
    }

    private func processGuess(_ guess: String) {
        let result = WordGuessLogic.evaluate(guess: guess, target: targetWord)
        guessHistory.append(result)

        let guessNumber = guessHistory.count

        if result.isAllCorrect {
            gameState = .won(guessCount: guessNumber)
            announceWin(guessCount: guessNumber)
        } else if guessNumber >= maxGuesses {
            gameState = .lost(answer: targetWord)
            announceLoss()
        } else {
            announceFeedback(result: result, guessNumber: guessNumber)
        }
    }

    // MARK: - Announcements

    private func announceFeedback(result: GuessResult, guessNumber: Int) {
        let feedback = result.spokenFeedback()
        let remaining = maxGuesses - guessNumber
        let guessWord = remaining == 1 ? "guess" : "guesses"

        let message = "\(feedback) That's guess \(guessNumber). \(remaining) \(guessWord) left. What's your next guess? Say WAIT if you need time."

        speakAndListen(message)
    }

    private func announceWin(guessCount: Int) {
        let guessWord = guessCount == 1 ? "guess" : "guesses"
        let message = "Correct! The word was \(spelledOut(targetWord)). You got it in \(guessCount) \(guessWord)! Say PLAY to start a new game, or QUIT to exit."
        lastSpokenMessage = message

        turnManager.beginTurn(
            speak: message,
            expectingInput: endGameInputSpec(),
            listenAfterSpeech: true
        ) { [weak self] parsed in
            self?.handleEndGameInput(parsed)
        }
    }

    private func announceLoss() {
        let message = "Out of guesses. The word was \(spelledOut(targetWord)). Say PLAY to try again, or QUIT to exit."
        lastSpokenMessage = message

        turnManager.beginTurn(
            speak: message,
            expectingInput: endGameInputSpec(),
            listenAfterSpeech: true
        ) { [weak self] parsed in
            self?.handleEndGameInput(parsed)
        }
    }

    private func promptForValidWord(reason: String) {
        lastSpokenMessage = reason
        turnManager.beginTurn(
            speak: reason,
            expectingInput: wordInputSpec(),
            listenAfterSpeech: true
        ) { [weak self] parsed in
            self?.handleInput(parsed)
        }
    }

    // MARK: - End Game Handling

    private func handleEndGameInput(_ parsed: ParsedCommand) {
        if parsed.globalCommand == .quit {
            sayGoodbye()
            return
        }

        if parsed.globalCommand == .repeat {
            // Replay the end-game message through a proper turn
            turnManager.beginTurn(
                speak: lastSpokenMessage,
                expectingInput: endGameInputSpec(),
                listenAfterSpeech: true
            ) { [weak self] parsed in
                self?.handleEndGameInput(parsed)
            }
            return
        }

        let input = parsed.normalizedInput.uppercased()

        if input.contains("PLAY") || input.contains("AGAIN") || input.contains("YES") || input.contains("NEW") {
            start()
            return
        }

        if input.contains("NO") || input.contains("QUIT") || input.contains("EXIT") || input.contains("STOP") {
            sayGoodbye()
            return
        }

        // Didn't understand
        let prompt = "Say PLAY for a new game, or QUIT to exit."
        turnManager.beginTurn(
            speak: prompt,
            expectingInput: endGameInputSpec(),
            listenAfterSpeech: true
        ) { [weak self] parsed in
            self?.handleEndGameInput(parsed)
        }
    }

    // MARK: - Global Commands

    private func handleGlobalCommand(_ command: GlobalCommand, parsed: ParsedCommand) {
        switch command {
        case .quit:
            sayGoodbye()

        case .repeat:
            speakAndListen(lastSpokenMessage)

        case .help:
            sayHelp()

        case .rules:
            sayRules()

        case .hint:
            giveHint()

        case .giveUp:
            giveUp()

        case .stats:
            speakAndListen("Stats coming soon. What's your guess?")
        }
    }

    private func sayGoodbye() {
        turnManager.beginTurn(
            speak: "Thanks for playing Word Guess. Goodbye!",
            expectingInput: InputSpec(),
            listenAfterSpeech: false
        ) { _ in }
    }

    private func sayHelp() {
        speakAndListen("I'm thinking of a 5 letter word. Guess a word, and I'll tell you which letters are correct. Green means right letter, right spot. Yellow means right letter, wrong spot. Gray means the letter isn't in the word. Say WAIT if you need time to think. Say HINT for a clue, or GIVE UP to reveal the answer. What's your guess?")
    }

    private func sayRules() {
        speakAndListen("Guess the 5 letter word in \(maxGuesses) tries. After each guess, I'll tell you how close you are. Green means correct letter in the correct spot. Yellow means the letter is in the word but wrong spot. Gray means the letter isn't in the word. Say WAIT any time you need to think. What's your guess?")
    }

    private func giveHint() {
        var hintMessage = "Here's a hint. "

        if guessHistory.isEmpty {
            let firstLetter = targetWord.first!
            hintMessage += "The word starts with \(firstLetter)."
        } else {
            let targetLetters = Array(targetWord)
            var revealedPositions = Set<Int>()

            for result in guessHistory {
                for (i, letterResult) in result.results.enumerated() {
                    if letterResult == .correct {
                        revealedPositions.insert(i)
                    }
                }
            }

            let unrevealedPositions = (0..<5).filter { !revealedPositions.contains($0) }

            if let position = unrevealedPositions.first {
                let letter = targetLetters[position]
                let positionWord = ordinal(position + 1)
                hintMessage += "The \(positionWord) letter is \(letter)."
            } else {
                hintMessage += "You've found all the letters! Just arrange them correctly."
            }
        }

        hintMessage += " What's your guess?"

        speakAndListen(hintMessage)
    }

    private func giveUp() {
        gameState = .lost(answer: targetWord)
        let message = "The word was \(spelledOut(targetWord)). Say PLAY to try a new word, or QUIT to exit."
        lastSpokenMessage = message

        turnManager.beginTurn(
            speak: message,
            expectingInput: endGameInputSpec(),
            listenAfterSpeech: true
        ) { [weak self] parsed in
            self?.handleEndGameInput(parsed)
        }
    }

    // MARK: - Input Specs

    private func wordInputSpec() -> InputSpec {
        InputSpec(
            acceptedInputTypes: [.word, .openEnded],
            validationSource: .none,
            maxTokens: nil,
            allowsSpaces: true,
            normalizationProfile: .phonetic
        )
    }

    private func thinkingInputSpec() -> InputSpec {
        InputSpec(
            acceptedInputTypes: [.openEnded],
            validationSource: .none,
            allowsSpaces: true
        )
    }

    private func endGameInputSpec() -> InputSpec {
        InputSpec(
            acceptedInputTypes: [.openEnded],
            validationSource: .none,
            allowsSpaces: true
        )
    }

    // MARK: - Helpers

    /// Spells out a word letter by letter for clarity: "APPLE" -> "A. P. P. L. E."
    private func spelledOut(_ word: String) -> String {
        word.map { String($0) }.joined(separator: ". ")
    }

    /// Returns ordinal string: 1 -> "first", 2 -> "second", etc.
    private func ordinal(_ n: Int) -> String {
        switch n {
        case 1: return "first"
        case 2: return "second"
        case 3: return "third"
        case 4: return "fourth"
        case 5: return "fifth"
        default: return "\(n)th"
        }
    }
}
