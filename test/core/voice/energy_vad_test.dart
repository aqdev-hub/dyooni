import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dyooni/core/voice/energy_vad.dart';
import 'package:flutter_test/flutter_test.dart';

/// [ms] of a 200 Hz tone whose RMS is [rms] (0..1), as PCM16 little-endian mono at 16 kHz.
Uint8List tone(int ms, double rms) {
  final samples = 16 * ms;
  final data = ByteData(samples * 2);
  final amplitude = rms * math.sqrt2;
  for (var i = 0; i < samples; i++) {
    final v = amplitude * math.sin(2 * math.pi * 200 * i / 16000);
    data.setInt16(i * 2, (v * 32767).round(), Endian.little);
  }
  return data.buffer.asUint8List();
}

void main() {
  test('silence and quiet room noise never read as speech', () {
    final vad = EnergyVad();
    for (var i = 0; i < 10; i++) {
      expect(vad.addChunk(tone(100, 0.003)), isFalse);
    }
    expect(vad.speechStarted, isFalse);
  });

  test('sustained speech becomes active after about 200 ms and stays active', () {
    final vad = EnergyVad();
    expect(vad.addChunk(tone(100, 0.003)), isFalse);
    final results = [for (var i = 0; i < 6; i++) vad.addChunk(tone(100, 0.05))];
    expect(vad.speechStarted, isTrue);
    expect(results.last, isTrue);
  });

  test('a short burst (cough/tap) does not start speech', () {
    final vad = EnergyVad();
    vad.addChunk(tone(100, 0.003));
    expect(vad.addChunk(tone(100, 0.08)), isFalse);
    for (var i = 0; i < 5; i++) {
      vad.addChunk(tone(100, 0.003));
    }
    expect(vad.speechStarted, isFalse);
  });

  test('activity ends shortly after speech stops', () {
    final vad = EnergyVad();
    vad.addChunk(tone(100, 0.003));
    for (var i = 0; i < 6; i++) {
      vad.addChunk(tone(100, 0.05));
    }
    final tail = [for (var i = 0; i < 6; i++) vad.addChunk(tone(100, 0.003))];
    expect(tail.first, isTrue); // still inside the 300 ms hangover
    expect(tail.last, isFalse);
  });

  test('chunks of arbitrary, odd sizes are handled', () {
    final vad = EnergyVad();
    final data = tone(1000, 0.05);
    for (var i = 0; i < data.length; i += 1001) {
      vad.addChunk(Uint8List.sublistView(data, i, math.min(i + 1001, data.length)));
    }
    expect(vad.speechStarted, isTrue);
    expect(vad.durationMs, inInclusiveRange(960, 1000));
  });

  test('peakRms and duration are tracked; reset clears them', () {
    final vad = EnergyVad();
    vad.addChunk(tone(200, 0.05));
    expect(vad.peakRms, closeTo(0.05, 0.005));
    expect(vad.durationMs, 200);
    vad.reset();
    expect(vad.peakRms, 0);
    expect(vad.durationMs, 0);
    expect(vad.speechStarted, isFalse);
  });
}
