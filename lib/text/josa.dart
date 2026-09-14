/// Korean particles that change with the final consonant of the word before them.
library;

const _hangulStart = 0xAC00;
const _hangulEnd = 0xD7A3;
const _rieul = 8;

/// Final consonant index of the last syllable (0 = none), reading digits aloud.
int _finalConsonant(String word) {
  final trimmed = word.trimRight();
  if (trimmed.isEmpty) return 0;
  final code = trimmed.runes.last;

  if (code >= _hangulStart && code <= _hangulEnd) {
    return (code - _hangulStart) % 28;
  }
  // 영 일 이 삼 사 오 육 칠 팔 구
  const digits = [21, _rieul, 0, 16, 0, 0, 1, _rieul, _rieul, 0];
  final digit = code - 0x30;
  if (digit >= 0 && digit <= 9) return digits[digit];
  return 0;
}

/// 을/를
String objectJosa(String word) => _finalConsonant(word) == 0 ? '를' : '을';

/// 으로/로. Words ending in ㄹ take 로 as well.
String directionJosa(String word) {
  final consonant = _finalConsonant(word);
  return consonant == 0 || consonant == _rieul ? '로' : '으로';
}
