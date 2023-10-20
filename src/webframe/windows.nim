#
# Windows version of WebFrame

import stdx/os
import stdx/dynlib
import std/asyncdispatch
import std/tables
import classes
import winim/clr

# Embed + import WebView2Loader.dll ... from the NuGet package: https://www.nuget.org/packages/Microsoft.Web.WebView2
# Path inside NuGet package: /runtimes/win-<arch>/native/WebView2Loader.dll
# Documentation: https://learn.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/webview2-idl
# const dllName = "WebView2Loader_" & hostCPU & ".dll"
# const dllData = staticRead(dllName)
# dynamicImportFromData(dllName, dllData):

#     ## Get the browser version info including channel name if it is not the WebView2 Runtime.
#     proc GetAvailableCoreWebView2BrowserVersionString(browserExecutablePath : PCWSTR, versionInfo : ptr LPWSTR) : HRESULT {.stdcall.}

#     ## Creates an evergreen WebView2 Environment using the installed WebView2 Runtime version.
#     proc CreateCoreWebView2EnvironmentWithOptions(browserExecutablePath : PCWSTR, userDataFolder : PCWSTR, environmentOptions : pointer, environmentCreatedHandler : pointer) : HRESULT {.stdcall.}
    

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


## Check an HRESULT and throw an error if needed
proc checkHResult(res : HRESULT, prefix : string = "") =
    if res == S_OK: return
    if res == CO_E_NOTINITIALIZED: raise newException(OSError, prefix & " COM was not initialized.")
    if res == RPC_E_CHANGED_MODE: raise newException(OSError, prefix & " COM was initialized on a different thread.")
    if res == HRESULT_FROM_WIN32(ERROR_NOT_SUPPORTED): raise newException(OSError, prefix & " Unsupported.")
    if res == HRESULT_FROM_WIN32(ERROR_INVALID_STATE): raise newException(OSError, prefix & " Specified options do not match the options of the WebViews that are currently running in the shared browser process.")
    if res == HRESULT_FROM_WIN32(ERROR_DISK_FULL): raise newException(OSError, prefix & " Disk full.")
    if res == HRESULT_FROM_WIN32(ERROR_PRODUCT_UNINSTALLED): raise newException(OSError, prefix & " Required WebView2 Runtime version is not installed.")
    if res == HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND): raise newException(OSError, prefix & " Could not find WebView2 runtime. Please check that it is installed.")
    if res == HRESULT_FROM_WIN32(ERROR_FILE_EXISTS): raise newException(OSError, prefix & " User data folder cannot be created because a file with the same name already exists.")
    if res == E_ACCESSDENIED: raise newException(OSError, prefix & " Unable to create user data folder, Access Denied.")
    if res == E_FAIL: raise newException(OSError, prefix & " Edge runtime unable to start.")
    raise newException(OSError, prefix & " Unable to perform action. Error 0x" & res.uint.toHex)


## WebFrame main class, used to create and display web views.
class WebFrame:

    ## Current window
    var hwnd : HWND = 0

    ## If true, will post an application quit message to the event loop when the window is closed by the user.
    ## This will cause the Windows event loop to stop running, and the program to exit if there's nothing else
    ## left for asyncdispatch to do.
    var quitOnClose = true
    
    ## Constructor
    method init() =

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
            0,                                  # Extra window styles (WS_EX_LAYERED?)
            registerWindowClass(),              # Class name
            "Loading...",                       # Window title
            WS_OVERLAPPEDWINDOW,                # Window style

            # Size and position, x, y, width, height
            x, y, width, height,

            0,                                  # Parent window    
            0,                                  # Menu
            GetModuleHandle(nil),               # Instance handle
            nil                                 # Extra data, unused since we're keeping track of windows separately
        )

        # Store active HWND
        activeHWNDs[this.hwnd] = this

        # Start Windows event loop
        asyncCheck startNativeEventLoop()

        # Start loading the web view
        asyncCheck this.loadWebView()


    ## Load the web view asynchronously
    method loadWebView() {.async.} =

        # The CreateCoreWebView2EnvironmentWithOptions function takes a Callback C++ class as a parameter. This is gonna be tricky...
        # First let's create our fake C++ VTable
        type CallbackVTable {.pure.} = object
            QueryInterface: proc(this: pointer, riid: pointer, ppvObject: pointer) : HRESULT {.stdcall.}
            AddRef: proc(this: pointer) : HRESULT {.stdcall.}
            Release: proc(this: pointer) : HRESULT {.stdcall.}
            Invoke: proc(this: pointer, env: pointer, res: HRESULT) : HRESULT {.stdcall.}

        # Now let's create our fake C++ class itself
        type CallbackClass {.pure.} = object
            vtable: ptr CallbackVTable
            refCount: uint
            env : pointer
            res : HRESULT
            isComplete : bool

        # Now let's create an instance of our fake C++ class
        var callback = CallbackClass()
        var vtbl = CallbackVTable()
        callback.vtable = vtbl.addr
        callback.vtable.QueryInterface = proc(thisPtr: pointer, riid: pointer, ppvObject: pointer) : HRESULT {.stdcall.} =
            # let this = cast[ptr CallbackClass](thisPtr)
            echo "QueryInterface"
            return S_OK # <-- Really we should be checking GUID's but... meh
        callback.vtable.AddRef = proc(thisPtr: pointer) : HRESULT {.stdcall.} =
            let this = cast[ptr CallbackClass](thisPtr)
            echo "AddRef"
            this.refCount += 1
            return S_OK
        callback.vtable.Release = proc(thisPtr: pointer) : HRESULT {.stdcall.} =
            let this = cast[ptr CallbackClass](thisPtr)
            echo "Release"
            if this.refCount > 0: this.refCount -= 1
            return S_OK
        callback.vtable.Invoke = proc(thisPtr: pointer, env: pointer, res: HRESULT) : HRESULT {.stdcall.} =
            let this = cast[ptr CallbackClass](thisPtr)
            echo "Invoke"
            this.env = env
            this.res = res
            this.isComplete = true
            return S_OK
        callback.refCount = 1

        # Create the WebView2 environment
        let res = CreateCoreWebView2EnvironmentWithOptions(nil, nil, nil, callback.addr)
        checkHResult(res, "Failed to create WebView2 environment.")

        # Wait for it to complete
        while not callback.isComplete:
            await sleepAsync(10)

        # Check for error
        echo "HERE ", callback.env.repr
        checkHResult(callback.res, "Failed to create async WebView2 environment.")

        # Loaded! Extract the COM class
        echo "Loaded WebView2 environment."
        echo callback.env.repr


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

    
    ## WndProc callback
    method wndProc(hwnd: HWND, uMsg: UINT, wParam: WPARAM, lParam: LPARAM): LRESULT =

        # Check message type
        if uMsg == WM_DESTROY:

            # Windows has destroyed our window, destroy us
            this.destroy()

            # Send shutdown message to the event loop
            if this.quitOnClose:
                PostQuitMessage(0)

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