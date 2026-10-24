# Voice v6 — Whisper for local recognition

Replaces Vosk (local mode) with whisper_ggml 2.8.1 (whisper.cpp, CPU, offline).

## Not compiled or run
Written without a Dart SDK. First build must be checked on a real machine.

## Requirements
- Flutter >= 3.29 / Dart >= 3.7, minSdk 24
- First Android build downloads NDK 29.0.13113456 + CMake 3.22.1 and compiles whisper.cpp (long)
- First use downloads a model: small-q5_1 (~190 MB, default) or medium-q5_0 (~540 MB)

## New
- core/voice/whisper_model_provider.dart  — model choice, resumable download, verification
- core/voice/whisper_speech_engine.dart   — records WAV, decodes after stop, cleans text
- core/voice/energy_vad.dart              — end-of-speech detection without live text
- logic/voice/transcript_cleaner.dart     — strips punctuation, hallucinations, prompt echo
- view/widgets/voice/whisper_model_gate.dart
- tests for cleaner and VAD

## Behaviour changes
- No live text while speaking in local mode
- Bluetooth wake-word unavailable in local mode (headset connect -> listens directly)
- Decode delay after each utterance
- Vosk code/dependency now unused (delete after validation)

## Fixed from the v5 log
- VoskModelIdle cast crash on switching to local
- `ref` used after dispose in voice screen

## Please send back
Log lines `[voice] whisper ... decode=...ms peakRms=... speechDetected=...`
and `[voice] system recognizer result ...`.
