//go:build windows

package main

import (
    "archive/zip"
    "bytes"
    "crypto/sha256"
    "embed"
    "fmt"
    "io"
    "log"
    "os"
    "path/filepath"
    "strings"
)

// The installer is fully offline. These are the only embedded payload files used.
//go:embed assets/payload.zip
var embeddedFiles embed.FS

var installTargets = []string{
    "bink2w64.dll",
    "rtlcompanion.dll",
    "trhook.dll",
    "trdata2.bin",
}

var legacyBackupDirs = []string{
    ".thai-campaign-v3-backup",
    ".thai-story-full-backup",
    ".thai-demo-backup",
}

func embeddedPayload() ([]byte, error) {
    return embeddedFiles.ReadFile("assets/payload.zip")
}

func resolveSP26(input string) (string, error) {
    input = strings.TrimSpace(strings.Trim(input, `"`))
    if input == "" {
        return "", fmt.Errorf("กรุณาเลือกโฟลเดอร์เกม")
    }
    abs, err := filepath.Abs(input)
    if err != nil {
        return "", err
    }
    candidates := []string{abs, filepath.Join(abs, "sp26")}
    for _, p := range candidates {
        st, err := os.Stat(filepath.Join(p, "sp26-cod.exe"))
        if err == nil && !st.IsDir() {
            return p, nil
        }
    }
    return "", fmt.Errorf("ไม่พบ sp26-cod.exe ในโฟลเดอร์ที่เลือกหรือโฟลเดอร์ sp26")
}

func payloadMap() (map[string][]byte, error) {
    raw, err := embeddedPayload()
    if err != nil {
        return nil, err
    }
    zr, err := zip.NewReader(bytes.NewReader(raw), int64(len(raw)))
    if err != nil {
        return nil, err
    }
    out := make(map[string][]byte)
    for _, f := range zr.File {
        name := filepath.Base(f.Name)
        switch name {
        case "bink2w64.dll", "rtlcompanion.dll", "trhook.dll", "trdata2-normal.bin", "trdata2-large.bin", "trdata2-largest.bin":
        default:
            continue
        }
        r, err := f.Open()
        if err != nil {
            return nil, err
        }
        b, err := io.ReadAll(r)
        r.Close()
        if err != nil {
            return nil, err
        }
        out[name] = b
    }
    return out, nil
}

func chosenSubtitlePayload(size string) string {
    switch strings.ToLower(size) {
    case "large":
        return "trdata2-large.bin"
    case "largest":
        return "trdata2-largest.bin"
    default:
        return "trdata2-normal.bin"
    }
}

func backupRoot(sp26 string) string {
    return filepath.Join(sp26, legacyBackupDirs[0])
}

func findExistingBackup(sp26 string) string {
    for _, name := range legacyBackupDirs {
        p := filepath.Join(sp26, name)
        if st, err := os.Stat(p); err == nil && st.IsDir() {
            return p
        }
    }
    return ""
}

func copyFile(src, dst string) error {
    in, err := os.Open(src)
    if err != nil {
        return err
    }
    defer in.Close()
    st, err := in.Stat()
    if err != nil {
        return err
    }
    if err := os.MkdirAll(filepath.Dir(dst), 0755); err != nil {
        return err
    }
    tmp := dst + ".akiemod.tmp"
    out, err := os.OpenFile(tmp, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, st.Mode().Perm())
    if err != nil {
        return err
    }
    _, copyErr := io.Copy(out, in)
    closeErr := out.Close()
    if copyErr != nil {
        _ = os.Remove(tmp)
        return copyErr
    }
    if closeErr != nil {
        _ = os.Remove(tmp)
        return closeErr
    }
    _ = os.Remove(dst)
    return os.Rename(tmp, dst)
}

func writeAtomic(dst string, data []byte) error {
    if err := os.MkdirAll(filepath.Dir(dst), 0755); err != nil {
        return err
    }
    tmp := dst + ".akiemod.tmp"
    if err := os.WriteFile(tmp, data, 0644); err != nil {
        return err
    }
    _ = os.Remove(dst)
    return os.Rename(tmp, dst)
}

func backupIfNeeded(sp26 string) error {
    root := backupRoot(sp26)
    if err := os.MkdirAll(root, 0755); err != nil {
        return err
    }
    // If an older installer already made a backup, preserve it and do not replace it.
    existing := findExistingBackup(sp26)
    if existing != "" && existing != root {
        log.Printf("preserving legacy backup: %s", existing)
    }
    for _, name := range installTargets {
        src := filepath.Join(sp26, name)
        dst := filepath.Join(root, name)
        if _, err := os.Stat(dst); err == nil {
            continue
        }
        if existing != "" && existing != root {
            old := filepath.Join(existing, name)
            if _, err := os.Stat(old); err == nil {
                continue
            }
        }
        if st, err := os.Stat(src); err == nil && !st.IsDir() {
            if err := copyFile(src, dst); err != nil {
                return fmt.Errorf("สำรอง %s: %w", name, err)
            }
        }
    }
    return nil
}

func installMod(sp26, subtitleSize string) error {
    var err error
    sp26, err = resolveSP26(sp26)
    if err != nil {
        return err
    }
    log.Printf("INSTALL target=%s subtitle=%s", sp26, subtitleSize)
    if err := backupIfNeeded(sp26); err != nil {
        return err
    }
    p, err := payloadMap()
    if err != nil {
        return err
    }
    required := map[string]string{
        "bink2w64.dll":    "bink2w64.dll",
        "rtlcompanion.dll": "rtlcompanion.dll",
        "trhook.dll":       "trhook.dll",
        "trdata2.bin":      chosenSubtitlePayload(subtitleSize),
    }
    for dstName, payloadName := range required {
        data, ok := p[payloadName]
        if !ok {
            return fmt.Errorf("payload ขาดไฟล์ %s", payloadName)
        }
        if err := writeAtomic(filepath.Join(sp26, dstName), data); err != nil {
            return fmt.Errorf("ติดตั้ง %s: %w", dstName, err)
        }
    }
    saveLastSP26(sp26)
    log.Printf("INSTALL OK")
    return nil
}

func uninstallMod(sp26 string) error {
    var err error
    sp26, err = resolveSP26(sp26)
    if err != nil {
        return err
    }
    log.Printf("UNINSTALL target=%s", sp26)
    root := findExistingBackup(sp26)
    if root == "" {
        return fmt.Errorf("ไม่พบโฟลเดอร์สำรองสำหรับถอนการติดตั้ง")
    }
    restored := 0
    for _, name := range installTargets {
        backup := filepath.Join(root, name)
        target := filepath.Join(sp26, name)
        if st, err := os.Stat(backup); err == nil && !st.IsDir() {
            if err := copyFile(backup, target); err != nil {
                return fmt.Errorf("คืนค่า %s: %w", name, err)
            }
            restored++
        } else if name != "bink2w64.dll" {
            // Mod-only file when no original backup exists.
            _ = os.Remove(target)
        }
    }
    _ = os.Remove(filepath.Join(sp26, "trhook.log"))
    if restored == 0 {
        return fmt.Errorf("โฟลเดอร์สำรองไม่มีไฟล์ต้นฉบับให้คืนค่า")
    }
    log.Printf("UNINSTALL OK")
    return nil
}

func localStateDir() string {
    base := os.Getenv("LOCALAPPDATA")
    if base == "" {
        base = os.TempDir()
    }
    return filepath.Join(base, "akiemod", "MW4Thai")
}

func saveLastSP26(p string) {
    dir := localStateDir()
    _ = os.MkdirAll(dir, 0755)
    _ = os.WriteFile(filepath.Join(dir, "last_sp26.txt"), []byte(p), 0644)
}

func loadLastSP26() string {
    b, err := os.ReadFile(filepath.Join(localStateDir(), "last_sp26.txt"))
    if err != nil {
        return ""
    }
    return strings.TrimSpace(string(b))
}

func payloadSHA256() string {
    b, err := embeddedPayload()
    if err != nil {
        return ""
    }
    sum := sha256.Sum256(b)
    return fmt.Sprintf("%x", sum[:])
}
