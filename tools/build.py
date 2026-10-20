"""Build public AKIE data packages. Third-party loader DLLs are never bundled."""
import argparse
import collections
import hashlib
import json
import re
import struct
import zipfile
from pathlib import Path
from build_stub import build_stub

ROOT = Path(__file__).resolve().parents[1]
TOKEN = re.compile(r'\^\?#x[0-9a-fA-F]+\.#x[0-9a-fA-F]+\^?|\^F[^\^\r\n]+\^|\[\{[^}\r\n]+\}\]|&&\d+|%(?:\d+\$)?[-+#0 ]*(?:\d+|\*)?(?:\.(?:\d+|\*))?[diuoxXfFeEgGaAcsp]|\{[^}\r\n]+\}|\^[0-9A-Za-z%+$#.-]|\n')
SIZES = {'normal': None, 'large': 30, 'largest': 40}
ROOT_DOCS = ('README.md', 'LICENSE', 'THIRD_PARTY_NOTICES.md', 'CHANGELOG.md', 'project.json')
BAT_FILES = ('install.bat', 'uninstall.bat', 'update.bat', 'check_install.bat', 'prepare_runtime.bat', 'subtitle-size-normal.bat', 'subtitle-size-large.bat', 'subtitle-size-largest.bat')
PUBLIC_TOOLS = ('installer.ps1', 'diagnose.ps1', 'prepare_runtime.ps1')


def read_rows():
    return [json.loads(line) for line in (ROOT / 'translations/thai.jsonl').read_text(encoding='utf-8').splitlines() if line.strip()]


def validate(rows):
    seen = set()
    for n, row in enumerate(rows, 1):
        en, th = row['en'], row['th']
        if not en or not th.strip() or en in seen:
            raise ValueError(f'Row {n}: empty or duplicate lookup key/translation')
        seen.add(en)
        if row['status'] not in {'draft', 'reviewed', 'imported_unreviewed', 'keep_original'}:
            raise ValueError(f'Row {n}: invalid review status')
        if collections.Counter(TOKEN.findall(en)) != collections.Counter(TOKEN.findall(th)):
            raise ValueError(f'Row {n}: formatting tokens differ')
        if '\ufffd' in en + th or any(c in en + th for c in '\x00\u200e\u200f\u202a\u202b\u202c\u202d\u202e\u2066\u2067\u2068\u2069'):
            raise ValueError(f'Row {n}: corrupt or directional text')


def render(row, size):
    th = row['th']
    if size and row.get('origin') != 'campaign_ui' and row.get('render') != 'ui':
        th = f'^H{size}^' + re.sub(r'^\^H(?:\d+)?\^', '', th)
    return th


def encode(rows, size):
    validate(rows)
    out = bytearray(struct.pack('<I', len(rows)))
    for row in rows:
        for text in (row['en'], render(row, size)):
            b = text.encode('utf-8')
            if len(b) > 65535:
                raise ValueError('Text exceeds uint16 byte length')
            out += struct.pack('<H', len(b)) + b
    return bytes(out)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def source_paths():
    # Explicit allowlist: local runtime files, raw input archives, logs,
    # personal paths and private reference corpora cannot enter a source ZIP.
    paths = [ROOT / n for n in (*ROOT_DOCS, *BAT_FILES, '.gitignore', '.gitattributes', 'CONTRIBUTING.md')]
    paths += [ROOT / 'translations/thai.jsonl', ROOT / 'translations/speaker_names_th.json']
    for folder, patterns in [('tools', ('*.py', '*.ps1')), ('docs', ('*.md',)), ('src', ('*.c',)), ('tests', ('*.py',)), ('LICENSES', ('*.txt',)), ('.github', ('*.yml', '*.md'))]:
        for pattern in patterns:
            paths += list((ROOT / folder).rglob(pattern) if folder == '.github' else (ROOT / folder).glob(pattern))
    paths += [ROOT / 'reports/visible_checks.json']
    return sorted(set(paths))


def build():
    meta = json.loads((ROOT / 'project.json').read_text(encoding='utf-8'))
    rows = read_rows()
    validate(rows)
    files = {f'files/trdata2-{mode}.bin': encode(rows, size) for mode, size in SIZES.items()}
    files['files/trdata2.bin'] = files['files/trdata2-large.bin']
    files['files/rtlcompanion.dll'] = build_stub()
    manifest = dict(Schema=1, Version=meta['version'], Project=meta['display_name'], Author=meta['author'], DevelopmentBuild=True, CampaignComplete=False, InGameVerified=False, TranslationEntries=len(rows),
                    Payload={**meta['runtime_hashes'], 'trdata2.bin': digest(files['files/trdata2.bin']), 'rtlcompanion.dll': digest(files['files/rtlcompanion.dll'])},
                    Variants={mode: digest(files[f'files/trdata2-{mode}.bin']) for mode in SIZES}, KnownDataBuilds={},
                    ThirdPartyLoaderBundled=False, RuntimeSource='User-provided local files verified by SHA-256')
    files['package.json'] = (json.dumps(manifest, indent=2) + '\n').encode('utf-8')
    for name in (*ROOT_DOCS, *BAT_FILES):
        files[name] = (ROOT / name).read_bytes()
    for name in PUBLIC_TOOLS:
        files['tools/' + name] = (ROOT / 'tools' / name).read_bytes()
    for p in (ROOT / 'docs').glob('*.md'):
        files[p.relative_to(ROOT).as_posix()] = p.read_bytes()
    files['LICENSES/upstream-farsi-MIT.txt'] = (ROOT / 'LICENSES/upstream-farsi-MIT.txt').read_bytes()
    files['reports/visible_checks.json'] = (ROOT / 'reports/visible_checks.json').read_bytes()
    coverage = dict(lookup_entries=len(rows), review_statuses=dict(collections.Counter(r['status'] for r in rows)), campaign_coverage_percent=None, campaign_complete=False, in_game_verified=False)
    files['reports/coverage.json'] = (json.dumps(coverage, indent=2) + '\n').encode('utf-8')
    dist = ROOT / 'dist'
    dist.mkdir(exist_ok=True)
    prefix = meta['name'] + '/'
    output = dist / f"{meta['name']}-{meta['version']}-data.zip"
    with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for name, data in sorted(files.items()):
            z.writestr(prefix + name, data)
    source = dist / f"{meta['name']}-{meta['version']}-source.zip"
    with zipfile.ZipFile(source, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for path in source_paths():
            if not path.is_file():
                raise ValueError(f'Missing source file: {path.name}')
            z.write(path, prefix + path.relative_to(ROOT).as_posix())
    # Defense-in-depth: a local import must never silently turn into a public DLL bundle.
    for path in (output, source):
        with zipfile.ZipFile(path) as z:
            if z.testzip() or any(n.lower().endswith(('bink2w64.dll', 'trhook.dll')) or '/runtime-local/' in n or '/diagnostics/' in n for n in z.namelist()):
                raise ValueError('Unsafe public ZIP contents')
    (dist / 'SHA256SUMS.txt').write_text(''.join(f'{digest(p.read_bytes())}  {p.name}\n' for p in (output, source)), encoding='ascii')
    print(f"Built {len(rows)} Thai lookup entries; third-party loader DLLs excluded.")
    print(output.name)
    print(source.name)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Validate translation source without packaging')
    args = parser.parse_args()
    if args.check:
        validate(read_rows())
        print('Translation source checks passed.')
    else:
        build()
