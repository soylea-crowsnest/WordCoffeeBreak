# Word Coffee Break

A voice-first iOS word game designed for accessibility — built for players with vision challenges who prefer audio interaction over visual UI.

## About

Word Coffee Break is an iOS app featuring voice-controlled word games. The app uses speech synthesis to communicate with the player and speech recognition to accept spoken input, creating a hands-free, eyes-free gaming experience.

Built for a 94-year-old grandmother who loves word games but has vision challenges.

## Games

### Word Guess
An audio version of Wordle. The app thinks of a 5-letter word and the player has 6 guesses to figure it out. After each guess, the app reads back letter-by-letter feedback:
- **Green** — correct letter in the correct spot
- **Yellow** — letter is in the word but in the wrong spot
- **Gray** — letter is not in the word

### Echo Test
A simple test game to verify voice input and speech output are working correctly.

## Voice Commands

See [COMMANDS.md](COMMANDS.md) for the full list of voice commands available during gameplay.

## Architecture

- **TurnManager** — State machine (idle → speaking → listening → processing → idle) that coordinates speech output and voice input
- **SpeechManager** — AVSpeechSynthesizer wrapper with IPA pronunciation fixes for short words
- **VoiceRecognitionManager** — SFSpeechRecognizer wrapper with silence timeout detection
- **CommandParser / InputNormalizer** — Processes raw speech recognition text into structured commands
- **Offline-first** — All game logic and word lists are local, no network required

## Requirements

- iOS 17+
- Xcode 15+
- Microphone permission (for voice input)
- Speech recognition permission
