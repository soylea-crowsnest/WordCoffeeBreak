import Foundation

class CommandParser {
    private let normalizer = InputNormalizer()
    
    func parse(_ rawInput: String, with spec: InputSpec) -> ParsedCommand {
        let normalized = normalizer.normalize(rawInput, for: spec)
        let globalCommand = detectGlobalCommand(normalized)
        
        return ParsedCommand(
            globalCommand: globalCommand,
            normalizedInput: normalized,
            rawInput: rawInput
        )
    }
    
    private func detectGlobalCommand(_ input: String) -> GlobalCommand? {
        switch input {
        case "REPEAT":
            return .`repeat`
        case "HELP":
            return .help
        case "RULES":
            return .rules
        case "HINT":
            return .hint
        case "GIVE UP":
            return .giveUp
        case "STATS":
            return .stats
        case "QUIT", "EXIT", "STOP":
            return .quit
        default:
            return nil
        }
    }
}
