import Foundation

enum InputType: Hashable, Sendable {
    case word
    case singleLetter
    case openEnded
}

enum ValidationSource: Sendable {
    case none
    case allowedGuesses
    case generalDictionary
    case custom(Set<String>)
}

enum NormalizationProfile: Sendable {
    case standard
    case phonetic
    case gameSpecific(phonetic: Bool, overrides: [String: String])
}

struct InputSpec: Sendable {
    let acceptedInputTypes: Set<InputType>
    let validationSource: ValidationSource
    let maxTokens: Int?
    let allowsSpaces: Bool
    let normalizationProfile: NormalizationProfile
    
    init(
        acceptedInputTypes: Set<InputType> = [.word],
        validationSource: ValidationSource = .none,
        maxTokens: Int? = nil,
        allowsSpaces: Bool = true,
        normalizationProfile: NormalizationProfile = .standard
    ) {
        self.acceptedInputTypes = acceptedInputTypes
        self.validationSource = validationSource
        self.maxTokens = maxTokens
        self.allowsSpaces = allowsSpaces
        self.normalizationProfile = normalizationProfile
    }
}
