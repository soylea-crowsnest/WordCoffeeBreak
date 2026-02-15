import Foundation

enum GlobalCommand: String {
    case `repeat` = "REPEAT"
    case help = "HELP"
    case rules = "RULES"
    case hint = "HINT"
    case giveUp = "GIVE UP"
    case stats = "STATS"
    case quit = "QUIT"
}

struct ParsedCommand {
    let globalCommand: GlobalCommand?
    let normalizedInput: String
    let rawInput: String
    
    init(globalCommand: GlobalCommand?, normalizedInput: String, rawInput: String) {
        self.globalCommand = globalCommand
        self.normalizedInput = normalizedInput
        self.rawInput = rawInput
    }
}
