import Foundation

class EchoTestGame {
    private let turnManager: TurnManager
    private let services = AppServices.shared
    
    init(turnManager: TurnManager) {
        self.turnManager = turnManager
    }
    
    func start() {
        print("[EchoTestGame] Starting Echo Test")
        sayGreeting()
    }
    
    private func sayGreeting() {
        let spec = InputSpec(
            acceptedInputTypes: [.openEnded],
            validationSource: .none,
            allowsSpaces: true
        )
        
        turnManager.beginTurn(
            speak: "Echo Test. Say anything. Say QUIT to exit.",
            expectingInput: spec,
            listenAfterSpeech: true
        ) { [weak self] parsed in
            self?.handleInput(parsed)
        }
    }
    
    private func handleInput(_ parsed: ParsedCommand) {
        // Check for quit command
        if parsed.globalCommand == .quit {
            turnManager.beginTurn(
                speak: "Goodbye!",
                expectingInput: InputSpec(),
                listenAfterSpeech: false
            ) { _ in }
            return
        }
        
        // Check for repeat command
        if parsed.globalCommand == .`repeat` {
            turnManager.repeatLastutterance()
            return
        }
        
        // Echo back what was said
        let echoText = "You said: \(parsed.normalizedInput)."
        
        let spec = InputSpec(
            acceptedInputTypes: [.openEnded],
            validationSource: .none,
            allowsSpaces: true
        )
        
        turnManager.beginTurn(
            speak: echoText,
            expectingInput: spec,
            listenAfterSpeech: true
        ) { [weak self] nextParsed in
            self?.handleInput(nextParsed)
        }
    }
}
