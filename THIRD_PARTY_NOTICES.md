# Third-party notices

## Farsi reference project

Reference: https://github.com/e3ang/call-of-duty-mw4-persian-farsi

The upstream project's notice is preserved verbatim at `LICENSES/upstream-farsi-MIT.txt`, including its scope exclusions. Copyright (c) 2026 cod-mw4-farsi contributors. This Thai project is independently maintained by AKIE and does not imply endorsement or authorship of the upstream work.

The English lookup keys and reference table structure were obtained from the user-supplied upstream localization materials. Existing Thai mappings were supplied by the user in earlier local development packages and expanded during this project. Imported and draft entries are explicitly marked in `translations/thai.jsonl`; they have not all received linguistic review.

## External runtime loader

`bink2w64.dll` and `trhook.dll` are third-party binaries. The upstream README attributes the runtime loader to the Turkish MW4 patch:

https://techolay.net/sosyal/konu/call-of-duty-modern-warfare-4-turkce-yama.222454/

The upstream MIT notice explicitly excludes those runtime binaries. This project does not bundle or relicense them. `prepare_runtime.ps1` accepts user-provided local files only when their SHA-256 hashes match the supported version. No external installer is executed and no runtime is downloaded automatically. Possession of a file or a matching hash does not establish redistribution permission.

The `rtlcompanion.dll` in our generated public data ZIP is our own import-free no-op compatibility helper, built by `tools/build_stub.py`, equivalent to `src/rtlcompanion.c`. It does not contain the upstream RTL implementation or any copied DLL bytes.

## Original game content

English text is retained as exact runtime lookup keys and remains the property of its respective rights holders. This project's MIT license does not grant rights in original game text, executable code, audiovisual assets or trademarks. No game executable, third-party font, screenshot, original input archive or foreign reference translation corpus is included in the public ZIPs.
