#
# Windows version of WebFrame

import stdx/os
import stdx/dynlib
import std/asyncdispatch
import std/tables
import classes
import winim/com
import ./windows_wrl
import ./windows_webview2


## Useful functions from uxtheme.dll
dynamicImport("uxtheme.dll"):

    ## Preferred app modes
    type PreferredAppMode = enum 
        APPMODE_DEFAULT = 0
        APPMODE_ALLOWDARK = 1
        APPMODE_FORCEDARK = 2
        APPMODE_FORCELIGHT = 3
        APPMODE_MAX = 4

    ## Set the preferred app mode, mainly changes context menus
    proc SetPreferredAppMode(mode : PreferredAppMode) {.stdcall, winapiOrdinal: 135, winapiVersion: "10.0.17763".}
    

## If true (the default), will apply WinApi styling (dark mode support, HiDPI, etc) on first init of a WebFrame.
var WebFrameApplyWinApiStyling* = true

## List of all active windows
var activeHWNDs: Table[HWND, RootRef]

## Proxy function that sends messages to the Nim object
proc wndProcProxy(hwnd: HWND, uMsg: UINT, wParam: WPARAM, lParam: LPARAM): LRESULT {.stdcall.}

## Register the Win32 "class"
proc registerWindowClass*(): string =

    # If done already, stop
    const WindowClassName = "NimWebFrameWindowClass"
    var hasDone {.global.} = false
    if hasDone:
        return WindowClassName

    # Do it
    var wc: WNDCLASSEX
    wc.cbSize = sizeof(WNDCLASSEX).UINT
    wc.lpfnWndProc = wndProcProxy
    wc.hInstance = GetModuleHandle(nil)
    wc.lpszClassName = WindowClassName
    wc.style = CS_HREDRAW or CS_VREDRAW
    wc.hIcon = LoadIcon(0, IDI_APPLICATION);
    wc.hCursor = LoadCursor(0, IDC_ARROW);
    wc.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
    RegisterClassEx(wc)

    # Done
    hasDone = true
    return WindowClassName


## WebFrame main class, used to create and display web views.
class WebFrame:

    ## Current window
    var hwnd : HWND = 0

    ## If true, will post an application quit message to the event loop when the window is closed by the user.
    ## This will cause the Windows event loop to stop running, and the program to exit if there's nothing else
    ## left for asyncdispatch to do.
    var quitOnClose = true

    ## WebView2 Environment
    var wv2environment : ptr ICoreWebView2Environment = nil

    ## WebView2 Controller
    var wv2controller : ptr ICoreWebView2Controller = nil

    ## WebView2 instance
    var wv2webview : ptr ICoreWebView2 = nil

    ## Contains the URL set by the client if they set it before the web view was loaded
    var lastSetURL = ""
    
    ## Constructor
    method init() =

        # Apply styling
        var HasAppliedStyling {.global.} = false
        if WebFrameApplyWinApiStyling and not HasAppliedStyling:

            # Set DPI awareness
            SetProcessDPIAware()

            # Allow app to be in dark mode if the system is in dark mode
            try:
                SetPreferredAppMode(APPMODE_ALLOWDARK)
            except:
                echo "Failed to set dark mode support: " & getCurrentExceptionMsg()

            # Done
            HasAppliedStyling = true

        # Initialize COM
        CoInitializeEx(nil, COINIT_APARTMENTTHREADED)

        # Throw an error if WebView2 is not installed
        if not this.isWebView2Installed():
            raise newException(OSError, "WebView2 was not found on this system. Please install it from https://developer.microsoft.com/en-us/microsoft-edge/webview2/")

        # Calculate position for the center of the screen
        let width   : DWORD = 800
        let height  : DWORD = 600
        let x       : DWORD = (GetSystemMetrics(SM_CXSCREEN) - width) div 2
        let y       : DWORD = (GetSystemMetrics(SM_CYSCREEN) - height) div 2

        # Create window, initially hidden
        this.hwnd = CreateWindowExW(
            0,                                          # Extra window styles
            registerWindowClass(),                      # Class name
            "Loading...",                               # Window title
            WS_OVERLAPPEDWINDOW,                        # Window style

            # Size and position, x, y, width, height
            x, y, width, height,

            0,                                          # Parent window    
            0,                                          # Menu
            GetModuleHandle(nil),                       # Instance handle
            nil                                         # Extra data, unused since we're keeping track of windows separately
        )

        # Store active HWND
        activeHWNDs[this.hwnd] = this

        # Start Windows event loop
        asyncCheck startNativeEventLoop()

        # Start loading the web view
        asyncCheck this.loadWebView()


    ## Load the web view asynchronously
    method loadWebView() {.async.} =

        # Create path to the temporary profile folder
        let tempDir = getTempDir() / "nim-webframe" / (getAppFilename().lastPathPart() & ".WebView2")

        # Create the WebView2 environment
        var callback = newWRLCallback[ICoreWebView2Environment]()
        var res = CreateCoreWebView2EnvironmentWithOptions(nil, tempDir, nil, callback)
        checkHResult(res, "Failed to create WebView2 environment.")
        this.wv2environment = await callback.getResult()
        
        # Create the controller
        var callback2 = newWRLCallback[ICoreWebView2Controller]()
        res = this.wv2environment.lpVtbl.CreateCoreWebView2Controller(this.wv2environment, this.hwnd, callback2)
        checkHResult(res, "Failed to create WebView2 controller.")
        this.wv2controller = await callback2.getResult()

        # Resize view to fill the window
        var bounds = RECT()
        GetClientRect(this.hwnd, bounds)
        res = this.wv2controller.lpVtbl.put_Bounds(this.wv2controller, bounds)
        checkHResult(res, "Failed to resize WebView2 controller.")

        # Get WebView2
        res = this.wv2controller.lpVtbl.get_CoreWebView2(this.wv2controller, this.wv2webview.addr)
        checkHResult(res)

        # Add listener for when the title changes
        var eventToken : pointer = nil
        res = this.wv2webview.lpVtbl.add_DocumentTitleChanged(this.wv2webview, newWRLCallback(proc (arg : ptr IUnknown) =

            # Set window title to match the document
            SetWindowTextW(this.hwnd, this.documentTitle())

        ), eventToken.addr)

        # Navigate now if they've set a URL
        if this.lastSetURL != "":

            # Navigate
            res = this.wv2webview.lpVtbl.Navigate(this.wv2webview, this.lastSetURL)
            checkHResult(res)



    ## Gets the engine version string
    method engineVersion() : string =

        # Get version string
        var versionWin : LPWSTR
        let res = GetAvailableCoreWebView2BrowserVersionString(nil, versionWin.addr)
        if res != S_OK:
            return "Microsoft WebView2: <not found>"

        # Convert to string
        let version = "Microsoft WebView2: " & $versionWin

        # Free memory
        CoTaskMemFree(versionWin)

        # Done
        return version


    ## Check if required libraries are available
    method isWebView2Installed() : bool =

        # Get version string
        var versionWin : LPWSTR
        let res = GetAvailableCoreWebView2BrowserVersionString(nil, versionWin.addr)
        if res != S_OK:
            return false

        # Free memory
        CoTaskMemFree(versionWin)

        # It exists
        return true


    ## Show the frame
    method show() =

        # Show window
        ShowWindow(this.hwnd, SW_SHOW)


    ## Hide the window
    method hide() =

        # Hide the window
        ShowWindow(this.hwnd, SW_HIDE)


    ## Destroy the window
    method destroy() =

        # Destroy the window
        DestroyWindow(this.hwnd)

        # Remove from active HWNDs
        activeHWNDs.del(this.hwnd)


    ## Get current URL
    method url() : string =

        # Stop if no web view
        if this.wv2webview == nil:
            return ""

        # Get URL
        var uri : LPWSTR
        let res2 = this.wv2webview.lpVtbl.get_Source(this.wv2webview, uri.addr)
        checkHResult(res2)
        let url = $uri

        # Free memory
        CoTaskMemFree(uri)
        return url


    ## Set current URL
    method `url=`(url : string) =

        # Store it
        this.lastSetURL = url

        # Stop if no web view
        if this.wv2webview == nil:
            return

        # Navigate
        let res2 = this.wv2webview.lpVtbl.Navigate(this.wv2webview, url)
        checkHResult(res2)


    ## Get current document title
    method documentTitle() : string =

        # Stop if no web view
        if this.wv2webview == nil:
            return ""

        # Get URL
        var str : LPWSTR
        let res2 = this.wv2webview.lpVtbl.get_DocumentTitle(this.wv2webview, str.addr)
        checkHResult(res2)
        let str2 = $str

        # Free memory
        CoTaskMemFree(str)
        return str2


    ## Set window size
    method setSize(width : int, height : int, center : bool = false) =

        # Check if we should center
        if center:

            # Calculate position for the center of the screen
            let x       : DWORD = (GetSystemMetrics(SM_CXSCREEN) - width.DWORD) div 2
            let y       : DWORD = (GetSystemMetrics(SM_CYSCREEN) - height.DWORD) div 2

            # Resize and move window
            SetWindowPos(this.hwnd, 0, x, y, width.DWORD, height.DWORD, SWP_NOZORDER)

        else:

            # Just resize without moving
            SetWindowPos(this.hwnd, 0, 0, 0, width.DWORD, height.DWORD, SWP_NOMOVE or SWP_NOZORDER)


    ## Set window position
    method setPosition(x : int, y : int) =

        # Move window
        SetWindowPos(this.hwnd, 0, x.DWORD, y.DWORD, 0, 0, SWP_NOSIZE or SWP_NOZORDER)

    
    ## WndProc callback
    method wndProc(hwnd: HWND, uMsg: UINT, wParam: WPARAM, lParam: LPARAM): LRESULT =

        # Check message type
        if uMsg == WM_DESTROY:

            # Windows has destroyed our window, destroy us
            this.destroy()

            # Send shutdown message to the event loop
            if this.quitOnClose:
                PostQuitMessage(0)

        elif uMsg == WM_SIZE:

            # Window was resized, resize the WebView2 controller as well
            if this.wv2controller != nil:
                var bounds = RECT()
                GetClientRect(this.hwnd, bounds)
                discard this.wv2controller.lpVtbl.put_Bounds(this.wv2controller, bounds)

        else:

            # Unknown message, let the system handle it in the default way
            return DefWindowProc(hwnd, uMsg, wParam, lParam)


## Proxy function for stdcall to class function
proc wndProcProxy(hwnd: HWND, uMsg: UINT, wParam: WPARAM, lParam: LPARAM): LRESULT {.stdcall.} =

    # Find class instance
    let component = activeHWNDs.getOrDefault(hwnd, nil).WebFrame()
    if component == nil:

        # No component associated with this HWND, we don't know where to route this message... Maybe it's a thread message or something? 
        # Let's just perform the default action.
        return DefWindowProc(hwnd, uMsg, wParam, lParam)

    # Pass on
    component.wndProc(hwnd, uMsg, wParam, lParam)