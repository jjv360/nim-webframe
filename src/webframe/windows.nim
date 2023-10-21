#
# Windows version of WebFrame

import stdx/os
import stdx/dynlib
import std/asyncdispatch
import std/tables
import classes
import winim/com
import winim/clr

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


## WebFrame main class, used to create and display web views.
class WebFrame:

    ## If true, will post an application quit message to the event loop when the window is closed by the user.
    ## This will cause the Windows event loop to stop running, and the program to exit if there's nothing else
    ## left for asyncdispatch to do.
    var quitOnClose = true

    # C# libs
    var mscorlib : CLRVariant = CLRVariant(nil)
    var winforms : CLRVariant = CLRVariant(nil)
    var runtime : CLRVariant = CLRVariant(nil)
    var webview2core : CLRVariant = CLRVariant(nil)
    var webview2winforms : CLRVariant = CLRVariant(nil)

    # The window
    var form : CLRVariant = CLRVariant(nil)

    # The WebView
    var webview : CLRVariant = CLRVariant(nil)
    
    ## Constructor
    method init() =

        # Apply styling
        if WebFrameApplyWinApiStyling:

            # Set DPI awareness
            SetProcessDPIAware()

            # Allow app to be in dark mode if the system is in dark mode
            try:
                SetPreferredAppMode(APPMODE_ALLOWDARK)
            except:
                echo "Failed to set dark mode support: " & getCurrentExceptionMsg()

        # Bundled assets
        const WebView2CoreDLL = staticRead("Microsoft.Web.WebView2.Core.dll").COMBinary
        const WebView2WinFormsDLL = staticRead("Microsoft.Web.WebView2.WinForms.dll").COMBinary
        const WebView2LoaderName = "WebView2Loader_" & hostCPU & ".dll"
        const WebView2LoaderDLL = staticRead(WebView2LoaderName)

        # Create a temporary directory to extract the DLLs to
        let tempDir = getTempDir() / "nimwebframe"
        if not tempDir.dirExists: tempDir.createDir()
        echo "Temp folder: ", tempDir

        # Extract files
        if not fileExists(tempDir / "WebView2Loader.dll"): writeFile(tempDir / "WebView2Loader.dll", WebView2LoaderDLL)

        # Load C# libs
        this.mscorlib = load("mscorlib")
        this.winforms = load("System.Windows.Forms")
        this.runtime = load("System.Runtime")
        this.webview2core = load(WebView2CoreDLL)
        this.webview2winforms = load(WebView2WinFormsDLL)

        # Set the WebView2 DLL path
        let Environment = this.webview2core.GetType("Microsoft.Web.WebView2.Core.CoreWebView2Environment")
        @Environment.SetLoaderDllFolderPath(tempDir)

        # Throw an error if WebView2 is not installed
        if not this.isWebView2Installed():
            raise newException(OSError, "WebView2 was not found on this system. Please install it from https://developer.microsoft.com/en-us/microsoft-edge/webview2/")

        # Create a Form
        # var FormStartPosition = this.winforms.GetType("System.Windows.Forms.FormStartPosition")
        this.form = this.winforms.new("System.Windows.Forms.Form")
        this.form.Text = "Loading..."
        this.form.Width = 800
        this.form.Height = 600
        # form.StartPosition = this.winforms.new("System.Windows.Forms.FormStartPosition.CenterScreen")
        this.form.Show()

        # Monitor the form to see when it's closed
        proc monitorForm() {.async.} =

            # Wait until it's closed
            while not this.form.IsDisposed().bool:
                await sleepAsync(100)

            # Quit if needed
            if this.quitOnClose:
                PostQuitMessage(0)

        asyncCheck monitorForm()

        # Create the WebView control
        this.webview = this.webview2winforms.new("Microsoft.Web.WebView2.WinForms.WebView2")
        # webview.Top = 0
        # webview.Left = 0
        # webview.Width = 800#form.Width
        # webview.Height = 600#form.Height
        # webview.CreationProperties = this.webview2core.new("Microsoft.Web.WebView2.WinForms.CoreWebView2CreationProperties")
        this.form.Controls.Add(this.webview)

        # Start Windows event loop
        asyncCheck startNativeEventLoop()


    ## Gets the engine version string
    method engineVersion() : string =

        # Catch errors
        try:

            # Get version string
            var Environment = this.webview2core.GetType("Microsoft.Web.WebView2.Core.CoreWebView2Environment")
            var versionStr = $ @Environment.GetAvailableBrowserVersionString("")
            if versionStr == "": versionStr = "<not found>"
            return "Microsoft WebView2: " & $versionStr

        except:

            # Failed
            echo "Error getting WebView2 version: " & getCurrentExceptionMsg()
            return "Microsoft WebView2: <not found>"


    ## Check if required libraries are available
    method isWebView2Installed() : bool =

        # Catch errors
        try:

            # Get version string
            var Environment = this.webview2core.GetType("Microsoft.Web.WebView2.Core.CoreWebView2Environment")
            var versionStr = $ @Environment.GetAvailableBrowserVersionString("")
            if versionStr == "": return false
            return true

        except:

            # Failed
            echo "Error getting WebView2 version: " & getCurrentExceptionMsg()
            return false


    ## Show the frame
    method show() =

        # Show window
        discard


    ## Hide the window
    method hide() =

        # Hide the window
        discard


    ## Destroy the window
    method destroy() =

        # Destroy the window
        discard


    ## Get the current URL
    method url() : string =
        return $this.webview.Source.ToString()

    ## Set the current URL
    method `url=`(url : string) =
        let uri = this.runtime.new("System.Uri", url)
        let wv = this.webview
        wv.Source = uri
