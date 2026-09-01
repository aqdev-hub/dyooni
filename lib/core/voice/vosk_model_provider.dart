import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vosk_flutter/vosk_flutter.dart';

/// Alpha Cephei's own hosted Arabic model (MGB-2, ~318MB) — the smallest general-purpose
/// (non-dialect-restricted) Arabic model Vosk currently publishes. Downloaded ONCE on first use
/// and cached under the app's own storage by [ModelLoader]; every listen after that is fully
/// offline. Deliberately NOT bundled as a Flutter asset — at ~318MB it would roughly triple the
/// app's install size for every single user, even ones who never touch the voice feature.
///
/// KNOWN LIMITATION, stated plainly: this is the ONLY model wired up right now — Arabic only.
/// `voiceRecognitionLanguageProvider` (see logic/voice/voice_provider.dart) still exists as a
/// piece of UI state, but the offline engine does not currently switch models based on it. Adding
/// real English recognition later means downloading a second (much smaller, ~40MB) English model
/// the same way and picking between the two `Recognizer`s in OfflineSpeechEngine.start().
const voskArabicModelUrl = 'https://alphacephei.com/vosk/models/vosk-model-ar-mgb2-0.4.zip';

/// Must match the sample rate the recorder captures at (see OfflineSpeechEngine) — Vosk decodes
/// assuming a fixed rate; mismatching the two silently produces garbled/empty recognition with no
/// error, which would look identical to the original "no speech detected" bug from the outside.
/// Keep this constant as the SINGLE source of truth both sides read from.
const voskSampleRate = 16000;

final voskPluginProvider = Provider<VoskFlutterPlugin>((ref) => VoskFlutterPlugin.instance());

final voskModelLoaderProvider = Provider<ModelLoader>((ref) => ModelLoader());

/// Resolves to the ready-to-use [Model] once downloaded (first run) or loaded from the on-disk
/// cache (every run after). `FutureProvider` caches this for the whole app process — once it
/// resolves, later `ref.watch` calls return the same [Model] instantly instead of re-downloading.
/// The UI (see view/widgets/voice/vosk_model_download_sheet.dart) watches this directly and shows
/// a loading state while it's pending — there is no fine-grained percentage exposed by
/// [ModelLoader.loadFromNetwork] today, so the loading UI is deliberately indeterminate
/// ("قد يستغرق دقائق") rather than a fabricated progress bar.
final voskModelProvider = FutureProvider<Model>((ref) async {
  final vosk = ref.watch(voskPluginProvider);
  final loader = ref.watch(voskModelLoaderProvider);
  final modelPath = await loader.loadFromNetwork(voskArabicModelUrl);
  return vosk.createModel(modelPath);
});
