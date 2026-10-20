"""Public build and Windows fixture tests; no external runtime is executed."""
import ctypes
import hashlib
import json
import os
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from build import build_stub, read_rows, validate

META = json.loads((ROOT / 'project.json').read_text(encoding='utf-8'))
DATA_ZIP = ROOT / 'dist' / f"{META['name']}-{META['version']}-data.zip"
SOURCE_ZIP = ROOT / 'dist' / f"{META['name']}-{META['version']}-source.zip"
PREFIX = META['name'] + '/'
NAMES = ('bink2w64.dll', 'trhook.dll', 'rtlcompanion.dll', 'trdata2.bin')
TEST_ROOT = ROOT / 'tests/.tmp'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def pairs(data):
    count, = struct.unpack_from('<I', data)
    pos = 4
    out = {}
    for _ in range(count):
        entry = []
        for _ in range(2):
            n, = struct.unpack_from('<H', data, pos)
            pos += 2
            entry.append(data[pos:pos + n].decode('utf-8'))
            pos += n
        if entry[0] in out:
            raise AssertionError('Duplicate binary key')
        out[entry[0]] = entry[1]
    if pos != len(data):
        raise AssertionError('Binary length mismatch')
    return out


class PublicBuildTests(unittest.TestCase):
    def test_payload_hashes_and_known_translations(self):
        with zipfile.ZipFile(DATA_ZIP) as z:
            manifest = json.loads(z.read(PREFIX + 'package.json'))
            self.assertFalse(manifest['CampaignComplete'])
            self.assertFalse(manifest['ThirdPartyLoaderBundled'])
            self.assertEqual(manifest['TranslationEntries'], len(read_rows()))
            for mode, digest in manifest['Variants'].items():
                self.assertEqual(sha(z.read(PREFIX + f'files/trdata2-{mode}.bin')), digest)
            table = pairs(z.read(PREFIX + 'files/trdata2-normal.bin'))
            self.assertEqual(table['Okay, make it fast, guys.'], 'โอเค รีบหน่อยนะทุกคน')
            self.assertEqual(table['Park, think fast!'], 'พัค รับให้ทันนะ!')
            self.assertEqual(table['Cpl. Dunn'], 'สิบโทดันน์')
            self.assertEqual(z.read(PREFIX + 'files/rtlcompanion.dll'), build_stub())

    def test_public_archives_exclude_imported_or_private_files(self):
        for path in (DATA_ZIP, SOURCE_ZIP):
            with zipfile.ZipFile(path) as z:
                self.assertIsNone(z.testzip())
                for name in z.namelist():
                    self.assertFalse(name.lower().endswith(('bink2w64.dll', 'trhook.dll')))
                    self.assertFalse(any(p in name.split('/') for p in ('runtime-local', 'diagnostics', 'inputs', '.git')))
                    self.assertNotIn('reference_master.jsonl', name)
                    if path == SOURCE_ZIP:
                        self.assertFalse(name.endswith(('.dll', '.exe', '.bin')))
                self.assertIn(PREFIX + 'LICENSES/upstream-farsi-MIT.txt', z.namelist())

    def test_invalid_translation_is_rejected(self):
        for rows in [
            [dict(en='Use [{+use}] &&1', th='ใช้', status='draft')],
            [dict(en='x', th='ไทย', status='draft')] * 2,
            [dict(en='x', th='\u202eไทย', status='draft')],
        ]:
            with self.assertRaises(ValueError):
                validate(rows)

    @unittest.skipUnless(os.name == 'nt', 'Windows native loader check')
    def test_own_stub_loads_and_export_returns(self):
        TEST_ROOT.mkdir(exist_ok=True)
        path = TEST_ROOT / 'own-helper.dll'
        path.write_bytes(build_stub())
        api = ctypes.WinDLL('kernel32', use_last_error=True)
        api.LoadLibraryW.argtypes = [ctypes.c_wchar_p]
        api.LoadLibraryW.restype = ctypes.c_void_p
        api.GetProcAddress.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
        api.GetProcAddress.restype = ctypes.c_void_p
        api.FreeLibrary.argtypes = [ctypes.c_void_p]
        handle = api.LoadLibraryW(str(path.resolve()))
        self.assertTrue(handle, f'LoadLibrary error {ctypes.get_last_error()}')
        try:
            proc = api.GetProcAddress(handle, b'RtlCompanionInit')
            self.assertTrue(proc)
            ctypes.WINFUNCTYPE(None)(proc)()
        finally:
            api.FreeLibrary(handle)
            path.unlink()


@unittest.skipUnless(os.name == 'nt', 'Windows PowerShell fixture tests')
class InstallerTests(unittest.TestCase):
    def setUp(self):
        TEST_ROOT.mkdir(exist_ok=True)
        self.case = Path(tempfile.mkdtemp(prefix='fixture-', dir=TEST_ROOT))
        self.bundle = self.case / META['name']
        with zipfile.ZipFile(DATA_ZIP) as z:
            for info in z.infolist():
                path = (self.case / info.filename).resolve()
                self.assertTrue(path.is_relative_to(self.case.resolve()))
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(z.read(info))
        self.game = self.case / 'Game [ไทย]'
        self.sp = self.game / 'sp26'
        self.sp.mkdir(parents=True)
        (self.sp / 'sp26-cod.exe').write_bytes(b'Fixture - never executed')
        self.provider = self.case / 'user-provided-runtime'
        self.provider.mkdir()
        # Tests use opaque harmless fixture files, not the third-party binaries.
        self.hashes = {}
        for name in ('bink2w64.dll', 'trhook.dll'):
            data = ('fixture-not-executable:' + name).encode()
            (self.provider / name).write_bytes(data)
            self.hashes[name] = sha(data)
        meta_path = self.bundle / 'project.json'
        meta = json.loads(meta_path.read_text(encoding='utf-8'))
        meta['runtime_hashes'] = self.hashes
        meta_path.write_text(json.dumps(meta), encoding='utf-8')
        package_path = self.bundle / 'package.json'
        package = json.loads(package_path.read_text(encoding='utf-8'))
        package['Payload'].update(self.hashes)
        package_path.write_text(json.dumps(package), encoding='utf-8')

    def tearDown(self):
        case = self.case.resolve()
        if not case.is_relative_to(TEST_ROOT.resolve()) or case == TEST_ROOT.resolve():
            raise AssertionError('Unsafe fixture cleanup target')
        shutil.rmtree(case)

    def run_ps(self, script, *args, ok=True):
        result = subprocess.run(['powershell.exe', '-NoLogo', '-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-File', str(self.bundle / 'tools' / script), *args, '-NonInteractive'], capture_output=True, timeout=40)
        self.assertEqual(result.returncode, 0 if ok else 1, (result.stdout + result.stderr).decode('utf-8', errors='replace'))

    def prepare(self):
        self.run_ps('prepare_runtime.ps1', '-RuntimePath', str(self.provider))

    def install(self):
        self.run_ps('installer.ps1', '-Mode', 'install', '-GamePath', str(self.game))

    def uninstall(self, ok=True):
        self.run_ps('installer.ps1', '-Mode', 'uninstall', '-GamePath', str(self.game), ok=ok)

    def test_import_only_two_supported_files_not_foreign_rtl(self):
        before = (self.bundle / 'files/rtlcompanion.dll').read_bytes()
        (self.provider / 'rtlcompanion.dll').write_bytes(b'foreign RTL - do not import')
        self.prepare()
        self.assertEqual({p.name for p in (self.bundle / 'runtime-local').iterdir()}, set(self.hashes))
        self.assertEqual((self.bundle / 'files/rtlcompanion.dll').read_bytes(), before)
        self.assertFalse((self.sp / '.mw4-thai-backups').exists())

    def test_bad_runtime_rejected_before_import(self):
        (self.provider / 'trhook.dll').write_bytes(b'wrong version')
        self.run_ps('prepare_runtime.ps1', '-RuntimePath', str(self.provider), ok=False)
        self.assertFalse((self.bundle / 'runtime-local').exists())
        self.assertFalse((self.sp / '.mw4-thai-backups').exists())

    def test_install_without_local_runtime_does_not_change_game(self):
        self.run_ps('installer.ps1', '-Mode', 'install', '-GamePath', str(self.game), ok=False)
        self.assertEqual({p.name for p in self.sp.iterdir()}, {'sp26-cod.exe'})

    def test_install_resize_diagnose_and_restore_both_locations(self):
        original = {}
        for folder in (self.game, self.sp):
            for name in NAMES:
                path = folder / name
                original[path] = (folder.name + ':' + name).encode('utf-8')
                path.write_bytes(original[path])
        self.prepare()
        self.install()
        self.run_ps('installer.ps1', '-Mode', 'resize', '-SubtitleSize', 'normal', '-GamePath', str(self.game))
        for folder in (self.game, self.sp):
            self.assertEqual((folder / 'trdata2.bin').read_bytes(), (self.bundle / 'files/trdata2-normal.bin').read_bytes())
        self.run_ps('diagnose.ps1', '-GamePath', str(self.game))
        report = json.loads((self.bundle / 'diagnostics/last-check.json').read_text(encoding='utf-8-sig'))
        self.assertEqual(len(report['TranslationTables']), 2)
        self.assertTrue(all(p['MatchesExpected'] for t in report['TranslationTables'] for p in t['Probes']))
        self.uninstall()
        self.assertTrue(all(path.read_bytes() == data for path, data in original.items()))

    def test_modified_game_file_prevents_uninstall(self):
        self.prepare()
        self.install()
        (self.game / 'trhook.dll').write_bytes(b'new external mod')
        before = {folder / name: (folder / name).read_bytes() for folder in (self.game, self.sp) for name in NAMES}
        self.uninstall(ok=False)
        self.assertTrue(all(path.read_bytes() == data for path, data in before.items()))

    def test_reinstall_and_same_runtime_update_preserve_backup(self):
        self.prepare()
        self.install()
        marker = self.sp / 'mw4-thai-install.json'
        before = json.loads(marker.read_text(encoding='utf-8-sig'))['BackupDir']
        self.install()
        self.run_ps('installer.ps1', '-Mode', 'update', '-GamePath', str(self.game))
        self.assertEqual(json.loads(marker.read_text(encoding='utf-8-sig'))['BackupDir'], before)
        self.uninstall()
        for folder in (self.game, self.sp):
            self.assertTrue(all(not (folder / name).exists() for name in NAMES))


if __name__ == '__main__':
    unittest.main(verbosity=2)
