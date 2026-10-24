//go:build windows

package main

import (
    "bytes"
    "embed"
    "image"
    _ "image/png"
    "log"
    "os"
    "path/filepath"
    "runtime"
    "strings"
    "syscall"
    "unsafe"
)

var version = "source-review"

//go:embed assets/hero.png
var heroFS embed.FS

const (
    idPath = 1001
    idBrowse = 1002
    idNormal = 1003
    idLarge = 1004
    idLargest = 1005
    idInstall = 1006
    idUninstall = 1007
    idStatus = 1008

    wmJobDone = WM_APP + 1
)

var (
    mainHwnd uintptr
    hPath, hBrowse, hNormal, hLarge, hLargest, hInstall, hUninstall, hStatus uintptr
    instance uintptr
    dpiScale float64 = 1.0
    fontNormal, fontBold uintptr
    brushBg, brushPanel, brushEdit uintptr
    heroPixels []byte // BGRA, bottom-up for StretchDIBits
    heroW, heroH int
    working bool
    asyncResult string
    asyncOK bool
)

func sx(v int) int32 { return int32(float64(v)*dpiScale + 0.5) }
func sy(v int) int32 { return sx(v) }

func main() {
    runtime.LockOSThread()
    setupLogging()
    log.Printf("MW4 Thai installer %s, payload sha256=%s", version, payloadSHA256())

    procSetProcessDPIAware.Call()
    if d,_,_ := procGetDpiForSystem.Call(); d >= 96 && d <= 384 { dpiScale = float64(d)/96.0 }

    if !isAdmin() && !hasArg("--elevated") {
        if elevateSelf() { return }
    }

    if err := prepareHero(); err != nil { log.Printf("hero read error: %v", err) }
    procCoInitializeEx.Call(0, COINIT_APARTMENTTHREADED)

    inst,_,_ := procGetModuleHandleW.Call(0)
    instance = inst
    className := wstr("AKIEMOD_MW4_THAI_INSTALLER")
    cursor,_,_ := procLoadCursorW.Call(0, IDC_ARROW)
    wc := WNDCLASSEX{
        CbSize: uint32(unsafe.Sizeof(WNDCLASSEX{})),
        LpfnWndProc: syscall.NewCallback(wndProc),
        HInstance: instance,
        HCursor: cursor,
        LpszClassName: className,
    }
    if r,_,_ := procRegisterClassExW.Call(uintptr(unsafe.Pointer(&wc))); r == 0 { panic("RegisterClassExW failed") }

    width, height := sx(1120), sy(790)
    hwnd := createWindow(0, "AKIEMOD_MW4_THAI_INSTALLER", "MW4 Thai Localization Mod Installer — by akiemod", WS_OVERLAPPEDWINDOW, 100, 60, width, height, 0, 0, instance)
    if hwnd == 0 { panic("CreateWindowExW failed") }
    mainHwnd = hwnd
    procShowWindow.Call(hwnd, SW_SHOW)
    procUpdateWindow.Call(hwnd)

    var msg MSG
    for {
        r,_,_ := procGetMessageW.Call(uintptr(unsafe.Pointer(&msg)), 0, 0, 0)
        if int32(r) <= 0 { break }
        procTranslateMessage.Call(uintptr(unsafe.Pointer(&msg)))
        procDispatchMessageW.Call(uintptr(unsafe.Pointer(&msg)))
    }
}

func setupLogging() {
    p := filepath.Join(os.TempDir(), "MW4_Thai_Setup_by_akiemod.log")
    f, err := os.OpenFile(p, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0644)
    if err == nil { log.SetOutput(f) }
    log.SetFlags(log.LstdFlags | log.Lmicroseconds)
}

func hasArg(s string) bool { for _, a := range os.Args[1:] { if a == s { return true } }; return false }
func isAdmin() bool { r,_,_ := procIsUserAnAdmin.Call(); return r != 0 }
func elevateSelf() bool {
    exe, err := os.Executable(); if err != nil { return false }
    verb := wstr("runas"); file := wstr(exe); params := wstr("--elevated")
    r,_,_ := procShellExecuteW.Call(0, uintptr(unsafe.Pointer(verb)), uintptr(unsafe.Pointer(file)), uintptr(unsafe.Pointer(params)), 0, SW_SHOWNORMAL)
    return r > 32
}

func prepareHero() error {
    b, err := heroFS.ReadFile("assets/hero.png")
    if err != nil { return err }
    img, _, err := image.Decode(bytes.NewReader(b))
    if err != nil { return err }
    bounds := img.Bounds(); heroW, heroH = bounds.Dx(), bounds.Dy()
    heroPixels = make([]byte, heroW*heroH*4)
    // GDI BI_RGB expects BGRA and positive height means bottom-up rows.
    for y := 0; y < heroH; y++ {
        sy := heroH-1-y
        for x := 0; x < heroW; x++ {
            r,g,b,a := img.At(bounds.Min.X+x, bounds.Min.Y+sy).RGBA()
            i := (y*heroW+x)*4
            heroPixels[i+0]=byte(b>>8); heroPixels[i+1]=byte(g>>8); heroPixels[i+2]=byte(r>>8); heroPixels[i+3]=byte(a>>8)
        }
    }
    return nil
}

func wndProc(hwnd uintptr, msg uint32, wParam, lParam uintptr) uintptr {
    switch msg {
    case WM_CREATE:
        createControls(hwnd)
        return 0
    case WM_PAINT:
        paintMain(hwnd)
        return 0
    case WM_CTLCOLORSTATIC, WM_CTLCOLORBTN:
        hdc := wParam
        procSetBkMode.Call(hdc, TRANSPARENT)
        procSetTextColor.Call(hdc, rgb(238,238,238))
        return brushBg
    case WM_CTLCOLOREDIT:
        hdc := wParam
        procSetBkMode.Call(hdc, TRANSPARENT)
        procSetTextColor.Call(hdc, rgb(245,245,245))
        return brushEdit
    case WM_DRAWITEM:
        drawButton((*DRAWITEMSTRUCT)(unsafe.Pointer(lParam)))
        return 1
    case WM_COMMAND:
        id := loword(wParam)
        switch id {
        case idBrowse: browseFolder(hwnd)
        case idInstall: startJob(true)
        case idUninstall: startJob(false)
        }
        return 0
    case wmJobDone:
        finishJob()
        return 0
    case WM_DESTROY:
        if fontNormal != 0 { procDeleteObject.Call(fontNormal) }
        if fontBold != 0 { procDeleteObject.Call(fontBold) }
        if brushBg != 0 { procDeleteObject.Call(brushBg) }
        if brushPanel != 0 { procDeleteObject.Call(brushPanel) }
        if brushEdit != 0 { procDeleteObject.Call(brushEdit) }
        procPostQuitMessage.Call(0)
        return 0
    }
    r,_,_ := procDefWindowProcW.Call(hwnd, uintptr(msg), wParam, lParam)
    return r
}

func makeFont(px int, weight int) uintptr {
    name := wstr("Segoe UI")
    h,_,_ := procCreateFontW.Call(uintptr(-sy(px)), 0,0,0, uintptr(weight), 0,0,0, 1,0,0,5,0, uintptr(unsafe.Pointer(name)))
    return h
}

func setFont(h uintptr, f uintptr) { procSendMessageW.Call(h, WM_SETFONT, f, 1) }

func createControls(hwnd uintptr) {
    brushBg,_,_ = procCreateSolidBrush.Call(rgb(17,17,17))
    brushPanel,_,_ = procCreateSolidBrush.Call(rgb(28,28,28))
    brushEdit,_,_ = procCreateSolidBrush.Call(rgb(33,33,33))
    fontNormal = makeFont(11, 400)
    fontBold = makeFont(15, 650)

    y := 405
    title := createWindow(0,"STATIC","Thai Localization Mod",WS_CHILD|WS_VISIBLE, sx(36),sy(y),sx(500),sy(36),hwnd,0,instance); setFont(title,fontBold)
    by := createWindow(0,"STATIC","by akiemod",WS_CHILD|WS_VISIBLE,sx(36),sy(y+37),sx(300),sy(26),hwnd,0,instance); setFont(by,fontNormal)

    lab := createWindow(0,"STATIC","ตำแหน่งโฟลเดอร์เกม / Game folder (เลือกโฟลเดอร์ sp26 หรือโฟลเดอร์หลักของเกม)",WS_CHILD|WS_VISIBLE,sx(36),sy(y+78),sx(900),sy(28),hwnd,0,instance); setFont(lab,fontNormal)
    hPath = createWindow(WS_EX_CLIENTEDGE,"EDIT",loadLastSP26(),WS_CHILD|WS_VISIBLE|WS_TABSTOP|ES_AUTOHSCROLL,sx(36),sy(y+108),sx(850),sy(36),hwnd,idPath,instance); setFont(hPath,fontNormal)
    hBrowse = createWindow(0,"BUTTON","เรียกดู...",WS_CHILD|WS_VISIBLE|WS_TABSTOP|BS_OWNERDRAW,sx(900),sy(y+108),sx(165),sy(36),hwnd,idBrowse,instance); setFont(hBrowse,fontNormal)

    lab2 := createWindow(0,"STATIC","ขนาดซับไตเติ้ลภาษาไทย / Subtitle size",WS_CHILD|WS_VISIBLE,sx(36),sy(y+160),sx(500),sy(28),hwnd,0,instance); setFont(lab2,fontNormal)
    hNormal = createWindow(0,"BUTTON","ปกติ (Normal)",WS_CHILD|WS_VISIBLE|WS_TABSTOP|WS_GROUP|BS_AUTORADIOBUTTON,sx(44),sy(y+195),sx(240),sy(32),hwnd,idNormal,instance); setFont(hNormal,fontNormal)
    hLarge = createWindow(0,"BUTTON","ใหญ่ (Large)",WS_CHILD|WS_VISIBLE|WS_TABSTOP|BS_AUTORADIOBUTTON,sx(325),sy(y+195),sx(240),sy(32),hwnd,idLarge,instance); setFont(hLarge,fontNormal)
    hLargest = createWindow(0,"BUTTON","ใหญ่ที่สุด (Largest)",WS_CHILD|WS_VISIBLE|WS_TABSTOP|BS_AUTORADIOBUTTON,sx(610),sy(y+195),sx(270),sy(32),hwnd,idLargest,instance); setFont(hLargest,fontNormal)
    procSendMessageW.Call(hLargest, BM_SETCHECK, BST_CHECKED, 0)

    hUninstall = createWindow(0,"BUTTON","ถอนการติดตั้ง / Uninstall",WS_CHILD|WS_VISIBLE|WS_TABSTOP|BS_OWNERDRAW,sx(36),sy(y+250),sx(315),sy(54),hwnd,idUninstall,instance); setFont(hUninstall,fontBold)
    hInstall = createWindow(0,"BUTTON","ติดตั้งม็อดภาษาไทย / Install",WS_CHILD|WS_VISIBLE|WS_TABSTOP|BS_OWNERDRAW,sx(700),sy(y+250),sx(365),sy(54),hwnd,idInstall,instance); setFont(hInstall,fontBold)
    hStatus = createWindow(0,"STATIC","พร้อมติดตั้ง • Offline installer • no external downloads",WS_CHILD|WS_VISIBLE,sx(375),sy(y+263),sx(300),sy(36),hwnd,idStatus,instance); setFont(hStatus,fontNormal)
}

func paintMain(hwnd uintptr) {
    var ps PAINTSTRUCT
    hdc,_,_ := procBeginPaint.Call(hwnd, uintptr(unsafe.Pointer(&ps)))
    var rc RECT; procGetClientRect.Call(hwnd, uintptr(unsafe.Pointer(&rc)))
    if brushBg == 0 { brushBg,_,_ = procCreateSolidBrush.Call(rgb(17,17,17)) }
    procFillRect.Call(hdc, uintptr(unsafe.Pointer(&rc)), brushBg)

    if len(heroPixels) > 0 {
        // Fill the top hero area while preserving the artwork's full width/height ratio.
        dstX, dstY, dstW, dstH := sx(18), sy(18), sx(1070), sy(360)
        bmi := BITMAPINFO{Header: BITMAPINFOHEADER{BiSize:uint32(unsafe.Sizeof(BITMAPINFOHEADER{})),BiWidth:int32(heroW),BiHeight:int32(heroH),BiPlanes:1,BiBitCount:32,BiCompression:BI_RGB}}
        procStretchDIBits.Call(hdc, uintptr(dstX),uintptr(dstY),uintptr(dstW),uintptr(dstH), 0,0,uintptr(heroW),uintptr(heroH), uintptr(unsafe.Pointer(&heroPixels[0])), uintptr(unsafe.Pointer(&bmi)), DIB_RGB_COLORS, SRCCOPY)
    }
    procEndPaint.Call(hwnd, uintptr(unsafe.Pointer(&ps)))
}

func drawButton(di *DRAWITEMSTRUCT) {
    if di == nil { return }
    yellow := di.CtlID == idInstall
    var br uintptr
    if yellow { br,_,_ = procCreateSolidBrush.Call(rgb(255,205,0)) } else { br,_,_ = procCreateSolidBrush.Call(rgb(45,45,45)) }
    procFillRect.Call(di.HDC, uintptr(unsafe.Pointer(&di.RcItem)), br)
    procDeleteObject.Call(br)
    procSetBkMode.Call(di.HDC, TRANSPARENT)
    if yellow { procSetTextColor.Call(di.HDC, rgb(20,20,20)) } else { procSetTextColor.Call(di.HDC, rgb(245,245,245)) }
    txt := getWindowText(di.HwndItem)
    r := di.RcItem
    procDrawTextW.Call(di.HDC, uintptr(unsafe.Pointer(wstr(txt))), uintptr(len(syscall.StringToUTF16(txt))-1), uintptr(unsafe.Pointer(&r)), DT_CENTER|DT_VCENTER|DT_SINGLELINE)
}

func browseFolder(owner uintptr) {
    buf := make([]uint16, 260)
    bi := BROWSEINFO{HwndOwner:owner,PszDisplayName:&buf[0],LpszTitle:wstr("เลือกโฟลเดอร์เกมหรือโฟลเดอร์ sp26"),UlFlags:BIF_RETURNONLYFSDIRS|BIF_NEWDIALOGSTYLE}
    pidl,_,_ := procSHBrowseForFolderW.Call(uintptr(unsafe.Pointer(&bi)))
    if pidl == 0 { return }
    defer procCoTaskMemFree.Call(pidl)
    path := make([]uint16, 32768)
    ok,_,_ := procSHGetPathFromIDListW.Call(pidl, uintptr(unsafe.Pointer(&path[0])))
    if ok != 0 { setWindowText(hPath, syscall.UTF16ToString(path)) }
}

func selectedSize() string {
    if r,_,_ := procSendMessageW.Call(hLarge,BM_GETCHECK,0,0); r == BST_CHECKED { return "large" }
    if r,_,_ := procSendMessageW.Call(hLargest,BM_GETCHECK,0,0); r == BST_CHECKED { return "largest" }
    return "normal"
}

func setWorking(v bool) {
    working = v
    enabled := uintptr(1); if v { enabled = 0 }
    for _, h := range []uintptr{hBrowse,hInstall,hUninstall,hNormal,hLarge,hLargest,hPath} { procEnableWindow.Call(h, enabled) }
}

func startJob(install bool) {
    if working { return }
    path := strings.TrimSpace(getWindowText(hPath))
    if path == "" { showError("กรุณาเลือกโฟลเดอร์เกมก่อน"); return }
    size := selectedSize()
    setWorking(true)
    if install { setWindowText(hStatus,"กำลังติดตั้ง...") } else { setWindowText(hStatus,"กำลังถอนการติดตั้ง...") }
    go func() {
        var err error
        if install { err = installMod(path,size) } else { err = uninstallMod(path) }
        asyncOK = err == nil
        if err != nil { asyncResult = err.Error() } else if install { asyncResult = "ติดตั้งม็อดภาษาไทยเรียบร้อยแล้ว" } else { asyncResult = "ถอนการติดตั้งและคืนค่าไฟล์เรียบร้อยแล้ว" }
        procPostMessageW.Call(mainHwnd, wmJobDone,0,0)
    }()
}

func finishJob() {
    setWorking(false)
    if asyncOK {
        setWindowText(hStatus,"เสร็จเรียบร้อย")
        procMessageBoxW.Call(mainHwnd, uintptr(unsafe.Pointer(wstr(asyncResult))), uintptr(unsafe.Pointer(wstr("by akiemod"))), MB_OK|MB_ICONINFORMATION)
    } else {
        setWindowText(hStatus,"เกิดข้อผิดพลาด — ดู log ใน TEMP")
        showError(asyncResult)
    }
}

func showError(s string) {
    log.Printf("ERROR: %s",s)
    procMessageBoxW.Call(mainHwnd, uintptr(unsafe.Pointer(wstr(s))), uintptr(unsafe.Pointer(wstr("MW4 Thai Installer — by akiemod"))), MB_OK|MB_ICONERROR)
}

