import { describe, it, expect } from 'vitest';
import { timingSafeEqual } from './index';

/**
 * `timingSafeEqual` replaced a vanilla `!==` admin-secret comparison
 * (REVIEW LOW-01). It must:
 *   - return true when the two strings are exactly equal
 *   - return false on any single-character difference
 *   - return false when lengths differ (length leak is acceptable for
 *     fixed-format bearer tokens, but bypass on length mismatch is not)
 *
 * Functional correctness is what the tests assert; the constant-time
 * property is a runtime claim that's hard to verify in JS — accept it
 * by inspection of the XOR-accumulate loop.
 */
describe('timingSafeEqual', () => {
  it('returns true on exact match', () => {
    expect(timingSafeEqual('secret', 'secret')).toBe(true);
    expect(timingSafeEqual('', '')).toBe(true);
    // Strings with non-ASCII byte sequences still compare equal to themselves.
    expect(timingSafeEqual('contraseña', 'contraseña')).toBe(true);
  });

  it('returns false on any single-byte difference', () => {
    expect(timingSafeEqual('secret', 'Secret')).toBe(false); // case
    expect(timingSafeEqual('secret', 'secre7')).toBe(false); // last char
    expect(timingSafeEqual('secret', 'Xecret')).toBe(false); // first char
    expect(timingSafeEqual('aaaa', 'aaab')).toBe(false);
  });

  it('returns false on length mismatch', () => {
    expect(timingSafeEqual('secret', 'secre')).toBe(false);   // shorter
    expect(timingSafeEqual('secret', 'secrets')).toBe(false); // longer
    expect(timingSafeEqual('', 'a')).toBe(false);
    expect(timingSafeEqual('a', '')).toBe(false);
  });

  it('returns false for unrelated strings of equal length', () => {
    expect(timingSafeEqual('abcdef', 'ghijkl')).toBe(false);
  });
});
