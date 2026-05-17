import { describe, it, expect } from 'vitest';
import { parseCsv, extractZipFiles } from './gtfs-static';

describe('parseCsv', () => {
  it('parses a simple header + rows', () => {
    const { header, rows } = parseCsv('a,b,c\n1,2,3\n4,5,6\n');
    expect(header).toEqual(['a', 'b', 'c']);
    expect(rows).toEqual([
      ['1', '2', '3'],
      ['4', '5', '6'],
    ]);
  });

  it('respects quoted fields containing commas', () => {
    const { rows } = parseCsv('id,name\n1,"Estación, Buenavista"\n2,Centro Medico\n');
    expect(rows).toEqual([
      ['1', 'Estación, Buenavista'],
      ['2', 'Centro Medico'],
    ]);
  });

  it('handles escaped double-quote inside quoted field', () => {
    const { rows } = parseCsv('a\n"He said ""hi"""\n');
    expect(rows).toEqual([['He said "hi"']]);
  });

  it('handles \\r\\n line endings', () => {
    const { header, rows } = parseCsv('h1,h2\r\nv1,v2\r\nv3,v4\r\n');
    expect(header).toEqual(['h1', 'h2']);
    expect(rows).toEqual([
      ['v1', 'v2'],
      ['v3', 'v4'],
    ]);
  });

  it('handles trailing newline gracefully (no phantom empty row)', () => {
    const a = parseCsv('a,b\n1,2\n');
    const b = parseCsv('a,b\n1,2');
    expect(a.rows).toEqual(b.rows);
    expect(a.rows).toEqual([['1', '2']]);
  });

  it('returns empty rows for header-only input', () => {
    const { header, rows } = parseCsv('a,b,c\n');
    expect(header).toEqual(['a', 'b', 'c']);
    expect(rows).toEqual([]);
  });
});

describe('extractZipFiles', () => {
  it('throws on ZIP64 sentinel (cdOffset = 0xFFFFFFFF)', async () => {
    // Construct a minimal EOCD record with the ZIP64 sentinel set on cdOffset.
    // Total file is just the EOCD record (22 bytes); no actual entries.
    const eocd = new Uint8Array(22);
    const view = new DataView(eocd.buffer);
    view.setUint32(0, 0x06054b50, true);          // EOCD signature
    view.setUint16(4, 0, true);                   // disk number
    view.setUint16(6, 0, true);                   // CD start disk
    view.setUint16(8, 0, true);                   // entries on this disk
    view.setUint16(10, 0, true);                  // total entries
    view.setUint32(12, 0, true);                  // CD size
    view.setUint32(16, 0xffffffff, true);         // CD offset — ZIP64 sentinel
    view.setUint16(20, 0, true);                  // comment length

    await expect(extractZipFiles(eocd, ['stops.txt'])).rejects.toThrow(/ZIP64/);
  });

  it('throws on ZIP64 sentinel (cdEntries = 0xFFFF)', async () => {
    const eocd = new Uint8Array(22);
    const view = new DataView(eocd.buffer);
    view.setUint32(0, 0x06054b50, true);
    view.setUint16(10, 0xffff, true);             // entries — ZIP64 sentinel
    await expect(extractZipFiles(eocd, ['x'])).rejects.toThrow(/ZIP64/);
  });

  it('throws "EOCD not found" on garbage input', async () => {
    const garbage = new Uint8Array(100).fill(0xff);
    // Wipe any accidental EOCD signature
    for (let i = 0; i < garbage.length - 3; i++) {
      if (garbage[i] === 0x50 && garbage[i + 1] === 0x4b) garbage[i] = 0x00;
    }
    await expect(extractZipFiles(garbage, ['x'])).rejects.toThrow(/EOCD/);
  });

  it('returns empty map when wanted file is not in CD', async () => {
    // Valid empty zip (just EOCD) — should succeed but find no files.
    const eocd = new Uint8Array(22);
    const view = new DataView(eocd.buffer);
    view.setUint32(0, 0x06054b50, true);
    const result = await extractZipFiles(eocd, ['stops.txt']);
    expect(result.size).toBe(0);
  });
});
