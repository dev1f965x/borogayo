const FIRST_SYLLABLE = 0xac00;
const LAST_SYLLABLE = 0xd7a3;
const FINALS = 28;
const RIEUL = 8;

/** Whether a word ends on a consonant, which is what Korean particles turn on. */
function endsOnConsonant(word: string): number {
  const last = word.codePointAt(word.length - 1) ?? 0;
  if (last < FIRST_SYLLABLE || last > LAST_SYLLABLE) return 0;
  return (last - FIRST_SYLLABLE) % FINALS;
}

/** 로 or 으로 — a word ending in ㄹ takes 로 as a vowel does. */
export function asA(word: string): string {
  const final = endsOnConsonant(word);
  return final === 0 || final === RIEUL ? `${word}로` : `${word}으로`;
}

/** 는 or 은, the particle that makes a word the thing being talked about. */
export function about(word: string): string {
  return endsOnConsonant(word) === 0 ? `${word}는` : `${word}은`;
}
