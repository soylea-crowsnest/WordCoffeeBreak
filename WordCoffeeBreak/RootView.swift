import SwiftUI

struct RootView: View {
    @StateObject private var turnManager = TurnManager()
    @State private var echoGame: EchoTestGame?
    @State private var wordGuessGame: WordGuessGame?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Word Coffee Break")
                .font(.largeTitle)
                .padding()
            
            Text("State: \(stateText)")
                .font(.headline)
                .foregroundColor(stateColor)
            
            Button("Start Echo Test") {
                startEchoTest()
            }
            .buttonStyle(.bordered)
            .disabled(turnManager.state != .idle)

            Button("Play Word Guess") {
                startWordGuess()
            }
            .buttonStyle(.borderedProminent)
            .disabled(turnManager.state != .idle)
        }
        .padding()
    }
    
    private var stateText: String {
        switch turnManager.state {
        case .idle: return "Idle"
        case .speaking: return "Speaking..."
        case .listening: return "Listening..."
        case .processing: return "Processing..."
        }
    }
    
    private var stateColor: Color {
        switch turnManager.state {
        case .idle: return .gray
        case .speaking: return .blue
        case .listening: return .green
        case .processing: return .orange
        }
    }
    
    private func startEchoTest() {
        echoGame = EchoTestGame(turnManager: turnManager)
        echoGame?.start()
    }

    private func startWordGuess() {
        wordGuessGame = WordGuessGame(turnManager: turnManager)
        wordGuessGame?.start()
    }
}

#Preview {
    RootView()
}
