import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const sampleRate = 22050;
const musicDuration = 40.0;
const seamDuration = 2.0;

void main() {
  final music = _createMusic();
  final move = _createMove();
  final win = _createWin();

  _writeWav('assets/audio/music.wav', music);
  _writeWav('assets/audio/move.wav', move);
  _writeWav('assets/audio/win.wav', win);

  _report('music.wav', music);
  _report('move.wav', move);
  _report('win.wav', win);
}

List<double> _createMusic() {
  final fadeSamples = (sampleRate * seamDuration).toInt();
  final loopSamples = (sampleRate * musicDuration).toInt();
  final raw = List<double>.filled(loopSamples + fadeSamples, 0);
  const voices = [
    (73.416, 0.080, 0.00),
    (146.832, 0.070, 0.13),
    (220.000, 0.048, 0.31),
    (293.665, 0.036, 0.47),
    (349.228, 0.030, 0.62),
    (391.995, 0.025, 0.78),
    (523.251, 0.018, 0.91),
  ];

  for (var i = 0; i < raw.length; i++) {
    final t = i / sampleRate;
    var sample = 0.0;
    for (final (frequency, amplitude, phase) in voices) {
      final movement = 0.76 + 0.24 * sin(2 * pi * (t / 20 + phase));
      final tone =
          sin(2 * pi * frequency * t + phase * pi) +
          0.22 * sin(2 * pi * frequency * 2 * t + phase * 2 * pi) +
          0.07 * sin(2 * pi * frequency * 3 * t);
      sample += amplitude * movement * tone;
    }
    raw[i] = sample;
  }

  const notes = [587.330, 698.456, 783.991, 880.000, 1046.502];
  for (
    var start = 1.0, index = 0;
    start < musicDuration + seamDuration;
    start += 5, index++
  ) {
    _addBell(
      raw,
      start,
      notes[index % notes.length],
      amplitude: 0.105,
      decay: 1.15,
      duration: 3.8,
    );
    if (index.isOdd) {
      _addBell(
        raw,
        start + 1.25,
        notes[(index + 2) % notes.length] / 2,
        amplitude: 0.045,
        decay: 1.5,
        duration: 3.2,
      );
    }
  }

  final loop = List<double>.filled(loopSamples, 0);
  for (var i = 0; i < loopSamples; i++) {
    if (i < fadeSamples) {
      final t = i / (fadeSamples - 1);
      final headWeight = t * t * (3 - 2 * t);
      loop[i] = raw[i] * headWeight + raw[loopSamples + i] * (1 - headWeight);
    } else {
      loop[i] = raw[i];
    }
  }
  return _normalize(loop, -18);
}

List<double> _createMove() {
  const duration = 0.18;
  final samples = List<double>.filled((sampleRate * duration).toInt(), 0);
  final random = Random(17);
  var filteredNoise = 0.0;
  for (var i = 0; i < samples.length; i++) {
    final t = i / sampleRate;
    final attack = min(1, t / 0.003);
    final endFade = min(1, (samples.length - 1 - i) / (sampleRate * 0.018));
    filteredNoise = filteredNoise * 0.55 + (random.nextDouble() * 2 - 1) * 0.45;
    final wood =
        sin(2 * pi * 1174.659 * t) * exp(-t * 34) * 0.62 +
        sin(2 * pi * 1760.0 * t) * exp(-t * 43) * 0.24 +
        sin(2 * pi * 2349.318 * t) * exp(-t * 55) * 0.09;
    samples[i] =
        (wood + filteredNoise * exp(-t * 90) * 0.22) * attack * endFade;
  }
  return _normalize(samples, -17);
}

List<double> _createWin() {
  const duration = 1.55;
  final samples = List<double>.filled((sampleRate * duration).toInt(), 0);
  const notes = [587.330, 698.456, 783.991, 880.000, 1046.502, 1174.659];
  for (var index = 0; index < notes.length; index++) {
    _addBell(
      samples,
      index * 0.13,
      notes[index],
      amplitude: 0.24,
      decay: 3.2,
      duration: 1.1,
    );
  }
  final fadeSamples = (sampleRate * 0.12).toInt();
  for (var i = 0; i < fadeSamples; i++) {
    samples[samples.length - 1 - i] *= i / fadeSamples;
  }
  return _normalize(samples, -17);
}

void _addBell(
  List<double> samples,
  double start,
  double frequency, {
  required double amplitude,
  required double decay,
  required double duration,
}) {
  final first = (start * sampleRate).round();
  final count = (duration * sampleRate).toInt();
  for (var offset = 0; offset < count; offset++) {
    final index = first + offset;
    if (index < 0 || index >= samples.length) continue;
    final t = offset / sampleRate;
    final attack = min(1, t / 0.012);
    final envelope = attack * exp(-t * decay);
    final tone =
        sin(2 * pi * frequency * t) +
        0.28 * sin(2 * pi * frequency * 2.003 * t) * exp(-t * 1.8) +
        0.08 * sin(2 * pi * frequency * 3.98 * t) * exp(-t * 3.5);
    samples[index] += amplitude * envelope * tone;
  }
}

List<double> _normalize(List<double> samples, double targetDb) {
  final rms = sqrt(
    samples.fold<double>(0, (sum, sample) => sum + sample * sample) /
        samples.length,
  );
  final scale = pow(10, targetDb / 20) / rms;
  final normalized = samples.map((sample) => sample * scale).toList();
  final peak = normalized.fold<double>(
    0,
    (value, sample) => max(value, sample.abs()),
  );
  if (peak > 0.98) {
    throw StateError('Сигнал ${targetDb.toStringAsFixed(1)} dB RMS клиппирует');
  }
  return normalized;
}

void _writeWav(String path, List<double> samples) {
  final byteCount = samples.length * 2;
  final data = ByteData(44 + byteCount);
  _writeAscii(data, 0, 'RIFF');
  data.setUint32(4, 36 + byteCount, Endian.little);
  _writeAscii(data, 8, 'WAVE');
  _writeAscii(data, 12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  _writeAscii(data, 36, 'data');
  data.setUint32(40, byteCount, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    final value = (samples[i].clamp(-1, 1) * 32767).round();
    data.setInt16(44 + i * 2, value, Endian.little);
  }
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(data.buffer.asUint8List(), flush: true);
}

void _writeAscii(ByteData data, int offset, String value) {
  for (var i = 0; i < value.length; i++) {
    data.setUint8(offset + i, value.codeUnitAt(i));
  }
}

void _report(String name, List<double> samples) {
  final rms = sqrt(
    samples.fold<double>(0, (sum, sample) => sum + sample * sample) /
        samples.length,
  );
  final peak = samples.fold<double>(
    0,
    (value, sample) => max(value, sample.abs()),
  );
  stdout.writeln(
    '$name: ${(samples.length / sampleRate).toStringAsFixed(2)} s, '
    '${(20 * log(rms) / ln10).toStringAsFixed(2)} dB RMS, '
    'peak ${(20 * log(peak) / ln10).toStringAsFixed(2)} dBFS',
  );
}
