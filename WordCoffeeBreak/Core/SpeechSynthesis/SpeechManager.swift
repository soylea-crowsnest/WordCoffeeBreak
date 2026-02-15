import AVFoundation

final class SpeechManager: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    private let synthesizer = AVSpeechSynthesizer()
    private var onFinished: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // Use playback category for maximum volume through speakers
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
            print("[SpeechManager] Audio session configured for maximum volume")
        } catch {
            print("[SpeechManager] ⚠️ Audio session error: \(error)")
        }
    }

    /// Replaces known misread short words with IPA-annotated attributed string
    /// to prevent AVSpeechSynthesizer from spelling them out letter by letter.
    private func attributedString(for text: String) -> NSAttributedString {
        // Words that AVSpeechSynthesizer commonly mispronounces as letter-by-letter
        let ipaMap: [(word: String, ipa: String)] = [
            // Multi-char first (longer matches before shorter)
            ("it's", "ɪts"),
            ("I'm",  "aɪm"),
            ("it",   "ɪt"),
            ("is",   "ɪz"),
            ("in",   "ɪn"),
            ("if",   "ɪf"),
            ("its",  "ɪts"),
            ("me",   "miː"),
            ("my",   "maɪ"),
            ("am",   "æm"),
            ("an",   "æn"),
            ("as",   "æz"),
            ("at",   "æt"),
            ("be",   "biː"),
            ("by",   "baɪ"),
            ("do",   "duː"),
            ("go",   "ɡoʊ"),
            ("he",   "hiː"),
            ("no",   "noʊ"),
            ("of",   "ʌv"),
            ("on",   "ɑːn"),
            ("or",   "ɔːɹ"),
            ("so",   "soʊ"),
            ("to",   "tuː"),
            ("up",   "ʌp"),
            ("us",   "ʌs"),
            ("we",   "wiː"),
            ("app",  "æp"),
        ]

        let attributed = NSMutableAttributedString(string: text)

        for entry in ipaMap {
            // Match whole words only, case-insensitively
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: entry.word))\\b"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, options: [], range: range)

            for match in matches.reversed() {
                attributed.addAttribute(
                    NSAttributedString.Key(AVSpeechSynthesisIPANotationAttribute),
                    value: entry.ipa,
                    range: match.range
                )
            }
        }

        return attributed
    }

    func speak(_ text: String, onFinished: @escaping () -> Void) {
        self.onFinished = onFinished

        // Reconfigure and re-activate audio session before speaking,
        // in case VoiceRecognitionManager changed it to .playAndRecord.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.duckOthers])
        try? session.setActive(true)

        let utterance = AVSpeechUtterance(attributedString: attributedString(for: text))
        utterance.rate = 0.48
        utterance.pitchMultiplier = 1.05
        utterance.volume = 1.0  // Maximum volume
        utterance.preUtteranceDelay = 0.2  // Slightly longer delay so user knows speech is coming
        
        // Try premium/enhanced voices in order of quality
        if let voice = AVSpeechSynthesisVoice(identifier: "com.apple.voice.premium.en-US.Ava") {
            utterance.voice = voice
            print("[SpeechManager] Using: Ava (Premium)")
        } else if let voice = AVSpeechSynthesisVoice(identifier: "com.apple.voice.enhanced.en-US.Ava") {
            utterance.voice = voice
            print("[SpeechManager] Using: Ava (Enhanced)")
        } else if let voice = AVSpeechSynthesisVoice(identifier: "com.apple.voice.premium.en-US.Zoe") {
            utterance.voice = voice
            print("[SpeechManager] Using: Zoe (Premium)")
        } else if let voice = AVSpeechSynthesisVoice(identifier: "com.apple.voice.enhanced.en-US.Samantha") {
            utterance.voice = voice
            print("[SpeechManager] Using: Samantha (Enhanced)")
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            print("[SpeechManager] Using: Default voice")
        }
        
        print("[SpeechManager] Speaking: \(text)")
        synthesizer.speak(utterance)
    }
    
    func stop() {
        print("[SpeechManager] Speech stopped")
        synthesizer.stopSpeaking(at: .immediate)
        onFinished = nil
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("[SpeechManager] Speech finished")
        onFinished?()
        onFinished = nil
    }
}
