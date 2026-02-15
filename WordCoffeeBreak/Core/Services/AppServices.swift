import Foundation

class AppServices {
    static let shared = AppServices()
    
    let speechManager = SpeechManager()
    let voiceRecognitionManager = VoiceRecognitionManager()
    let commandParser = CommandParser()
    
    private init() {
        print("[AppServices] Initialized (single instance)")
    }
}
