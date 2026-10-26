"""Encode review CSV for SQL Server character-mode BULK INSERT, losslessly.

Run before sql/02_load_stg_bulk_insert.sql. Standard library only.
US (0x1f) separates fields; RS (0x1e) separates records. Neither may occur
in source values. Newlines, commas and quotes inside comments remain intact.
"""
import argparse
import csv
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HEADER = ['review_id', 'order_id', 'review_score', 'review_comment_title',
          'review_comment_message', 'review_creation_date', 'review_answer_timestamp']
LIMITS = [100, 100, 100, 4000, 4000, 100, 100]
FIELD = '\x1f'
RECORD = '\x1e'


def prepare(source, destination):
    source, destination = Path(source), Path(destination)
    if source.resolve() == destination.resolve():
        raise ValueError('Output must not overwrite the source CSV.')
    # Validate the whole file before writing any output.
    with source.open(encoding='utf-8-sig', newline='') as stream:
        reader = csv.reader(stream, strict=True)
        if next(reader, None) != HEADER:
            raise ValueError('Unexpected review CSV header or column order.')
        rows = list(reader)
    if not rows:
        raise ValueError('Review CSV contains no records.')
    for number, row in enumerate(rows, 1):
        if len(row) != len(HEADER):
            raise ValueError(f'Record {number}: expected 7 fields, got {len(row)}.')
        for name, value, limit in zip(HEADER, row, LIMITS):
            if FIELD in value or RECORD in value:
                raise ValueError(f'Record {number}, {name}: reserved delimiter in source.')
            if len(value.encode('utf-16-le')) // 2 > limit:
                raise ValueError(f'Record {number}, {name}: exceeds staging NVARCHAR({limit}).')
    payload = (RECORD.join(FIELD.join(row) for row in rows) + RECORD).encode('utf-8')
    decoded = [row.split(FIELD) for row in payload.decode('utf-8').split(RECORD)[:-1]]
    if decoded != rows:
        raise AssertionError('Round-trip mismatch; refusing to write output.')
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix(destination.suffix + '.tmp')
    temporary.write_bytes(payload)
    temporary.replace(destination)
    evidence = {
        'rows': len(rows), 'columns': len(HEADER),
        'multiline_records': sum(any('\n' in v or '\r' in v for v in r) for r in rows),
        'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
        'output_sha256': hashlib.sha256(payload).hexdigest(),
        'round_trip': 'PASS', 'encoding': 'utf-8', 'header': False,
        'field_terminator': '0x1f', 'row_terminator': '0x1e',
    }
    destination.with_suffix('.json').write_text(json.dumps(evidence, indent=2), encoding='utf-8')
    return evidence


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=ROOT/'data/raw/olist_order_reviews_dataset.csv')
    parser.add_argument('--output', type=Path, default=ROOT/'data/prepared/olist_order_reviews.bulk')
    args = parser.parse_args()
    evidence = prepare(args.source, args.output)
    print(f"PASS: {evidence['rows']:,} records, {evidence['multiline_records']:,} multiline; exact round-trip verified.")
    print(f'BULK input: {args.output.resolve()}')


if __name__ == '__main__':
    main()
