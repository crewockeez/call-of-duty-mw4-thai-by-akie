//go:build windows

package main

import (
    "syscall"
    "unsafe"
)

var (
    user32   = syscall.NewLazyDLL("user32.dll")
    kernel32 = syscall.NewLazyDLL("kernel32.dll")
    gdi32    = syscall.NewLazyDLL("gdi32.dll")
    shell32  = syscall.NewLazyDLL("shell32.dll")
    ole32    = syscall.NewLazyDLL("ole32.dll")
)

var (
    procRegisterClassExW = user32.NewProc("RegisterClassExW")
    procCreateWindowExW = user32.NewProc("CreateWindowExW")
    procDefWindowProcW = user32.NewProc("DefWindowProcW")
    procShowWindow = user32.NewProc("ShowWindow")
    procUpdateWindow = user32.NewProc("UpdateWindow")
    procGetMessageW = user32.NewProc("GetMessageW")
    procTranslateMessage = user32.NewProc("TranslateMessage")
    procDispatchMessageW = user32.NewProc("DispatchMessageW")
    procPostQuitMessage = user32.NewProc("PostQuitMessage")
    procPostMessageW = user32.NewProc("PostMessageW")
    procSendMessageW = user32.NewProc("SendMessageW")
    procGetDlgItem = user32.NewProc("GetDlgItem")
    procGetWindowTextLengthW = user32.NewProc("GetWindowTextLengthW")
    procGetWindowTextW = user32.NewProc("GetWindowTextW")
    procSetWindowTextW = user32.NewProc("SetWindowTextW")
    procEnableWindow = user32.NewProc("EnableWindow")
    procMessageBoxW = user32.NewProc("MessageBoxW")
    procLoadCursorW = user32.NewProc("LoadCursorW")
    procBeginPaint = user32.NewProc("BeginPaint")
    procEndPaint = user32.NewProc("EndPaint")
    procGetClientRect = user32.NewProc("GetClientRect")
    procFillRect = user32.NewProc("FillRect")
    procDrawTextW = user32.NewProc("DrawTextW")
    procSetBkMode = gdi32.NewProc("SetBkMode")
    procSetTextColor = gdi32.NewProc("SetTextColor")
    procCreateSolidBrush = gdi32.NewProc("CreateSolidBrush")
    procDeleteObject = gdi32.NewProc("DeleteObject")
    procCreateFontW = gdi32.NewProc("CreateFontW")
    procSelectObject = gdi32.NewProc("SelectObject")
    procStretchDIBits = gdi32.NewProc("StretchDIBits")
    procSetProcessDPIAware = user32.NewProc("SetProcessDPIAware")
    procGetDpiForSystem = user32.NewProc("GetDpiForSystem")
    procSHBrowseForFolderW = shell32.NewProc("SHBrowseForFolderW")
    procSHGetPathFromIDListW = shell32.NewProc("SHGetPathFromIDListW")
    procShellExecuteW = shell32.NewProc("ShellExecuteW")
    procIsUserAnAdmin = shell32.NewProc("IsUserAnAdmin")
    procCoTaskMemFree = ole32.NewProc("CoTaskMemFree")
    procCoInitializeEx = ole32.NewProc("CoInitializeEx")
    procGetModuleHandleW = kernel32.NewProc("GetModuleHandleW")
)

const (
    WS_OVERLAPPEDWINDOW = 0x00CF0000
    WS_VISIBLE          = 0x10000000
    WS_CHILD            = 0x40000000
    WS_TABSTOP          = 0x00010000
    WS_BORDER           = 0x00800000
    WS_EX_CLIENTEDGE    = 0x00000200
    ES_AUTOHSCROLL      = 0x0080
    BS_PUSHBUTTON       = 0x00000000
    BS_AUTORADIOBUTTON = 0x00000009
    BS_OWNERDRAW        = 0x0000000B
    WS_GROUP            = 0x00020000

    WM_CREATE        = 0x0001
    WM_DESTROY       = 0x0002
    WM_PAINT         = 0x000F
    WM_COMMAND       = 0x0111
    WM_CTLCOLORSTATIC = 0x0138
    WM_CTLCOLOREDIT  = 0x0133
    WM_CTLCOLORBTN   = 0x0135
    WM_DRAWITEM      = 0x002B
    WM_APP           = 0x8000
    WM_SETFONT       = 0x0030

    BM_SETCHECK = 0x00F1
    BM_GETCHECK = 0x00F0
    BST_CHECKED = 1

    SW_SHOW = 5
    SW_SHOWNORMAL = 1

    MB_OK = 0x00000000
    MB_ICONERROR = 0x00000010
    MB_ICONINFORMATION = 0x00000040

    COLOR_WINDOW = 5
    IDC_ARROW = 32512

    TRANSPARENT = 1
    DT_CENTER = 0x00000001
    DT_VCENTER = 0x00000004
    DT_SINGLELINE = 0x00000020
    DT_LEFT = 0x00000000

    BI_RGB = 0
    DIB_RGB_COLORS = 0
    SRCCOPY = 0x00CC0020

    BIF_RETURNONLYFSDIRS = 0x0001
    BIF_NEWDIALOGSTYLE = 0x0040
    COINIT_APARTMENTTHREADED = 0x2
)

type POINT struct { X, Y int32 }
type RECT struct { Left, Top, Right, Bottom int32 }
type MSG struct { Hwnd uintptr; Message uint32; WParam, LParam uintptr; Time uint32; Pt POINT; LPrivate uint32 }
type PAINTSTRUCT struct { Hdc uintptr; FErase int32; RcPaint RECT; FRestore int32; FIncUpdate int32; RgbReserved [32]byte }
type WNDCLASSEX struct {
    CbSize uint32; Style uint32; LpfnWndProc uintptr; CbClsExtra int32; CbWndExtra int32
    HInstance, HIcon, HCursor, HbrBackground uintptr
    LpszMenuName, LpszClassName *uint16
    HIconSm uintptr
}
type BROWSEINFO struct {
    HwndOwner, PidlRoot uintptr
    PszDisplayName *uint16
    LpszTitle *uint16
    UlFlags uint32
    Lpfn, LParam uintptr
    IImage int32
}
type BITMAPINFOHEADER struct {
    BiSize uint32; BiWidth, BiHeight int32; BiPlanes, BiBitCount uint16
    BiCompression, BiSizeImage uint32; BiXPelsPerMeter, BiYPelsPerMeter int32
    BiClrUsed, BiClrImportant uint32
}
type BITMAPINFO struct { Header BITMAPINFOHEADER; Colors [1]uint32 }
type DRAWITEMSTRUCT struct {
    CtlType, CtlID, ItemID, ItemAction, ItemState uint32
    HwndItem, HDC uintptr
    RcItem RECT
    ItemData uintptr
}

func wstr(s string) *uint16 { p, _ := syscall.UTF16PtrFromString(s); return p }
func loword(v uintptr) uint16 { return uint16(v & 0xffff) }

func rgb(r,g,b byte) uintptr { return uintptr(uint32(r) | uint32(g)<<8 | uint32(b)<<16) }

func getWindowText(hwnd uintptr) string {
    n,_,_ := procGetWindowTextLengthW.Call(hwnd)
    if n == 0 { return "" }
    buf := make([]uint16, n+1)
    procGetWindowTextW.Call(hwnd, uintptr(unsafe.Pointer(&buf[0])), n+1)
    return syscall.UTF16ToString(buf)
}

func setWindowText(hwnd uintptr, s string) { procSetWindowTextW.Call(hwnd, uintptr(unsafe.Pointer(wstr(s)))) }

func createWindow(ex uint32, class, text string, style uint32, x,y,w,h int32, parent, id, instance uintptr) uintptr {
    hwnd,_,_ := procCreateWindowExW.Call(
        uintptr(ex), uintptr(unsafe.Pointer(wstr(class))), uintptr(unsafe.Pointer(wstr(text))), uintptr(style),
        uintptr(x), uintptr(y), uintptr(w), uintptr(h), parent, id, instance, 0,
    )
    return hwnd
}
