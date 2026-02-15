import Foundation
import Combine

enum TurnState: Equatable {
    case idle
    case speaking
    case listening
    case processing
}

class TurnManager: ObservableObject {
    @Published private(set) var state: TurnState = .idle
    
    private let services = AppServices.shared
    private var lastSpokenText: String?
    private var currentInputSpec: InputSpec?
    private var onInputReceived: ((ParsedCommand) -> Void)?
    
    private let cooldownDelay: TimeInterval = 0.3
    
    func beginTurn(
        speak text: String,
        expectingInput spec: InputSpec,
        listenAfterSpeech: Bool = true,
        onInputReceived: @escaping (ParsedCommand) -> Void
    ) {
        guard state == .idle else {
            print("[TurnManager] ⚠️ Cannot begin turn - not idle (current: \(state))")
            return
        }
        
        lastSpokenText = text
        currentInputSpec = spec
        self.onInputReceived = onInputReceived
        
        setState(.speaking)
        
        services.speechManager.speak(text) { [weak self] in
            guard let self = self else { return }
            
            if listenAfterSpeech {
                // Cooldown before listening
                DispatchQueue.main.asyncAfter(deadline: .now() + self.cooldownDelay) {
                    self.startListening()
                }
            } else {
                self.setState(.idle)
            }
        }
    }
    
    func finishTurn() {
        print("[TurnManager] Turn finished, returning to idle")
        setState(.idle)
        cleanup()
    }
    
    func cancelTurn() {
        print("[TurnManager] Turn cancelled")
        services.speechManager.stop()
        services.voiceRecognitionManager.stopListening()
        setState(.idle)
        cleanup()
    }
    
    func handleBargeIn() {
        guard state == .speaking else { return }
        
        print("[TurnManager] 🎙️ Speech interrupted, resuming listen...")
        services.speechManager.stop()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + cooldownDelay) { [weak self] in
            self?.startListening()
        }
    }
    
    func repeatLastutterance() {
        guard let lastText = lastSpokenText else {
            print("[TurnManager] No previous utterance to repeat")
            return
        }
        
        guard state == .idle || state == .listening else {
            print("[TurnManager] Cannot repeat - currently \(state)")
            return
        }
        
        if state == .listening {
            services.voiceRecognitionManager.stopListening()
        }
        
        setState(.speaking)
        services.speechManager.speak(lastText) { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + self.cooldownDelay) {
                self.startListening()
            }
        }
    }
    
    // MARK: - Private Helpers

    private func startListening() {
        print("[TurnManager] 🎤 startListening() called")
        
        guard let spec = currentInputSpec else {
            print("[TurnManager] ⚠️ No input spec - cannot listen")
            setState(.idle)
            return
        }
        
        setState(.listening)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.services.voiceRecognitionManager.startListening(
                onResult: { [weak self] result in
                    self?.handleRecognitionResult(result, spec: spec)
                },
                onError: { [weak self] error in
                    self?.handleRecognitionError(error)
                }
            )
        }
        }
    private func handleRecognitionResult(_ result: VoiceRecognitionResult, spec: InputSpec) {
            guard result.isFinal else { return }
            guard state == .listening else {
                print("[TurnManager] ⚠️ Ignoring ghost callback (state: \(state))")
                return
            }
            
            print("[TurnManager] Final recognition: \(result.text)")
            services.voiceRecognitionManager.stopListening()
            setState(.processing)
            
            let parsed = services.commandParser.parse(result.text, with: spec)
            
            // Return to idle BEFORE delivering to game, so game can start a new turn
            let callback = onInputReceived
            cleanup()
            setState(.idle)
            callback?(parsed)
        }
    
    private func handleRecognitionError(_ error: Error) {
        guard state == .listening || state == .processing else {
            print("[TurnManager] ⚠️ Ignoring ghost error callback (state: \(state))")
            return
        }
        print("[TurnManager] Recognition error: \(error.localizedDescription)")
        services.voiceRecognitionManager.stopListening()
        setState(.idle)
        cleanup()
    }
    
    private func setState(_ newState: TurnState) {
        guard state != newState else { return }
        print("[TurnManager] State: \(state) → \(newState)")
        state = newState
    }
    
    private func cleanup() {
        currentInputSpec = nil
        onInputReceived = nil
    }
}
