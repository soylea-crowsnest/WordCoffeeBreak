import Foundation

class InputNormalizer {
    
    func normalize(_ input: String, for spec: InputSpec) -> String {
        var result = input
        
        // Trim whitespace
        result = result.trimmingCharacters(in: .whitespaces)
        
        // Uppercase
        result = result.uppercased()
        
        // Collapse multiple spaces
        result = result.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        
        // Remove spaces if not allowed
        if !spec.allowsSpaces {
            result = result.replacingOccurrences(of: " ", with: "")
        }
        
        // Apply phonetic fixes if needed
        if case .phonetic = spec.normalizationProfile {
            result = applyPhoneticFixes(result)
        }
        
        return result
    }
    
    private func applyPhoneticFixes(_ input: String) -> String {
        var result = input
        
        // Common speech recognition mistakes
        let phoneticMap: [String: String] = [
            "WON": "ONE",
            "TOO": "TWO",
            "FOR": "FOUR",
            "ATE": "EIGHT"
        ]
        
        for (wrong, right) in phoneticMap {
            result = result.replacingOccurrences(of: wrong, with: right)
        }
        
        return result
    }
}
