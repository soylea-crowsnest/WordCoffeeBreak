import Speech
import AVFoundation

class VoiceRecognitionManager: NSObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private var onResult: ((VoiceRecognitionResult) -> Void)?
    private var onError: ((Error) -> Void)?
    private var silenceTimer: Timer?
    private var lastPartialText: String = ""
    private var isListening: Bool = false
    
    func startListening(onResult: @escaping (VoiceRecognitionResult) -> Void, onError: @escaping (Error) -> Void) {
        self.onResult = onResult
        self.onError = onError
        self.lastPartialText = ""
        self.isListening = true
        
        print("[VoiceRecognitionManager] Starting to listen...")
        
        // Configure audio session FIRST
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("[VoiceRecognitionManager] Audio session error: \(error)")
            isListening = false
            onError(error)
            return
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self, self.isListening else { return }
            
            if let error = error {
                print("[VoiceRecognitionManager] Error: \(error.localizedDescription)")
                self.stopListening()
                self.onError?(error)
                return
            }
            
            if let result = result {
                let text = result.bestTranscription.formattedString
                let isFinal = result.isFinal
                print("[VoiceRecognitionManager] Recognized: \(text) (final: \(isFinal))")
                
                if isFinal {
                    self.silenceTimer?.invalidate()
                    self.silenceTimer = nil
                    let voiceResult = VoiceRecognitionResult(text: text, isFinal: true)
                    self.stopListening()
                    self.onResult?(voiceResult)
                } else {
                    self.lastPartialText = text
                    self.resetSilenceTimer()
                }
            }
        }
        
        // Configure audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
            print("[VoiceRecognitionManager] ⚠️ Invalid audio format — cannot listen")
            isListening = false
            onError(NSError(domain: "VoiceRecognition", code: -1,
                           userInfo: [NSLocalizedDescriptionKey: "No valid microphone available."]))
            return
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
            resetSilenceTimer(timeout: 10.0)
        } catch {
            print("[VoiceRecognitionManager] Audio engine failed to start: \(error)")
            isListening = false
            onError(error)
        }
    }
    
    func stopListening() {
        guard isListening else { return }
        
        print("[VoiceRecognitionManager] Stopped listening")
        isListening = false
        
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
    }
    
    // MARK: - Silence Timer
    
    private func resetSilenceTimer(timeout: TimeInterval = 2.0) {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            guard let self = self, self.isListening else { return }
            
            let finalText = self.lastPartialText
            print("[VoiceRecognitionManager] Silence timeout — delivering: '\(finalText)'")
            
            self.stopListening()
            
            if !finalText.isEmpty {
                self.onResult?(VoiceRecognitionResult(text: finalText, isFinal: true))
            } else {
                self.onError?(NSError(domain: "VoiceRecognition", code: -2,
                                      userInfo: [NSLocalizedDescriptionKey: "No speech detected"]))
            }
        }
    }
}
