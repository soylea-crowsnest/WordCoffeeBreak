import Foundation

struct VoiceRecognitionResult {
    let text: String
    let isFinal: Bool
    let confidence: Float?
    
    init(text: String, isFinal: Bool, confidence: Float? = nil) {
        self.text = text
        self.isFinal = isFinal
        self.confidence = confidence
    }
}
