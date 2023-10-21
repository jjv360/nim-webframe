
import stdx/dynlib
import winim/com
import ./windows_wrl


# Embed + import WebView2Loader.dll ... from the NuGet package: https://www.nuget.org/packages/Microsoft.Web.WebView2
# Path inside NuGet package: /runtimes/win-<arch>/native/WebView2Loader.dll
# Documentation: https://learn.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/webview2-idl
const dllName = "WebView2Loader_" & hostCPU & ".dll"
const dllData = staticRead(dllName)
dynamicImportFromData(dllName, dllData):

    ## Types
    type

        ## Event registeration token
        EventRegistrationToken* = pointer

        ## Represents the WebView2 Environment.
        ICoreWebView2Environment* {.pure.} = object
            lpVtbl* : ptr ICoreWebView2EnvironmentVtbl
        ICoreWebView2EnvironmentVtbl* {.pure, inheritable.} = object of IUnknownVtbl
            CreateCoreWebView2Controller* : proc(this : ptr ICoreWebView2Environment, parentWindow : HWND, handler : WRLCallback[ICoreWebView2Controller]) : HRESULT {.stdcall.}

        ## Specifies the reason for moving focus.
        COREWEBVIEW2_MOVE_FOCUS_REASON* = enum
            COREWEBVIEW2_MOVE_FOCUS_REASON_PROGRAMMATIC
            COREWEBVIEW2_MOVE_FOCUS_REASON_NEXT
            COREWEBVIEW2_MOVE_FOCUS_REASON_PREVIOUS

        ## Specifies the web resource request contexts.
        COREWEBVIEW2_WEB_RESOURCE_CONTEXT* = enum
            COREWEBVIEW2_WEB_RESOURCE_CONTEXT_ALL
            COREWEBVIEW2_WEB_RESOURCE_CONTEXT_DOCUMENT
            COREWEBVIEW2_WEB_RESOURCE_CONTEXT_STYLESHEET
            COREWEBVIEW2_WEB_RESOURCE_CONTEXT_IMAGE
            COREWEBVIEW2_WEB_RESOURCE_CONTEXT_MEDIA
            COREWEBVIEW2_WEB_RESOURCE_CONTEXT_FONT
            COREWEBVIEW2_WEB_RESOURCE_CONTEXT_SCRIPT
            COREWEBVIEW2_WEB_RESOURCE_CONTEXT_XML_HTTP_REQUEST
            COREWEBVIEW2_WEB_RESOURCE_CONTEXT_FETCH
            COREWEBVIEW2_WEB_RESOURCE_CONTEXT_TEXT_TRACK
            COREWEBVIEW2_WEB_RESOURCE_CONTEXT_EVENT_SOURCE
            COREWEBVIEW2_WEB_RESOURCE_CONTEXT_WEBSOCKET
            COREWEBVIEW2_WEB_RESOURCE_CONTEXT_MANIFEST
            COREWEBVIEW2_WEB_RESOURCE_CONTEXT_SIGNED_EXCHANGE
            COREWEBVIEW2_WEB_RESOURCE_CONTEXT_PING
            COREWEBVIEW2_WEB_RESOURCE_CONTEXT_CSP_VIOLATION_REPORT
            COREWEBVIEW2_WEB_RESOURCE_CONTEXT_OTHER

        ## Specifies the image format for the ICoreWebView2::CapturePreview method.
        COREWEBVIEW2_CAPTURE_PREVIEW_IMAGE_FORMAT* = enum
            COREWEBVIEW2_CAPTURE_PREVIEW_IMAGE_FORMAT_PNG
            COREWEBVIEW2_CAPTURE_PREVIEW_IMAGE_FORMAT_JPEG

        ## The owner of the CoreWebView2 object that provides support for resizing, showing and hiding, focusing, and other functionality related to windowing and composition.
        ICoreWebView2Controller* {.pure.} = object
            lpVtbl*: ptr ICoreWebView2ControllerVtbl
        ICoreWebView2ControllerVtbl* {.pure, inheritable.} = object of IUnknownVtbl
            get_IsVisible*: proc(this : ptr ICoreWebView2Controller, isVisible : ptr bool) : HRESULT {.stdcall.}
            put_IsVisible*: proc(this : ptr ICoreWebView2Controller, isVisible : bool) : HRESULT {.stdcall.}
            get_Bounds*: proc(this : ptr ICoreWebView2Controller, bounds : ptr RECT) : HRESULT {.stdcall.}
            put_Bounds*: proc(this : ptr ICoreWebView2Controller, bounds : RECT) : HRESULT {.stdcall.}
            get_ZoomFactor*: proc(this : ptr ICoreWebView2Controller, zoomFactor : ptr float64) : HRESULT {.stdcall.}
            put_ZoomFactor*: proc(this : ptr ICoreWebView2Controller, zoomFactor : float64) : HRESULT {.stdcall.}
            add_ZoomFactorChanged*: proc(this : ptr ICoreWebView2Controller, eventHandler : WRLCallback[IUnknown], token : ptr EventRegistrationToken) : HRESULT {.stdcall.}
            remove_ZoomFactorChanged*: proc(this : ptr ICoreWebView2Controller, token : EventRegistrationToken) : HRESULT {.stdcall.}
            SetBoundsAndZoomFactor*: proc(this : ptr ICoreWebView2Controller, bounds : RECT, zoomFactor : float64) : HRESULT {.stdcall.}
            MoveFocus*: proc(this : ptr ICoreWebView2Controller, reason : COREWEBVIEW2_MOVE_FOCUS_REASON) : HRESULT {.stdcall.}
            add_MoveFocusRequested*: proc(this : ptr ICoreWebView2Controller, eventHandler : WRLCallback[IUnknown], token : ptr EventRegistrationToken) : HRESULT {.stdcall.}
            remove_MoveFocusRequested*: proc(this : ptr ICoreWebView2Controller, token : EventRegistrationToken) : HRESULT {.stdcall.}
            add_GotFocus*: proc(this : ptr ICoreWebView2Controller, eventHandler : WRLCallback[IUnknown], token : ptr EventRegistrationToken) : HRESULT {.stdcall.}
            remove_GotFocus*: proc(this : ptr ICoreWebView2Controller, token : EventRegistrationToken) : HRESULT {.stdcall.}
            add_LostFocus*: proc(this : ptr ICoreWebView2Controller, eventHandler : WRLCallback[IUnknown], token : ptr EventRegistrationToken) : HRESULT {.stdcall.}
            remove_LostFocus*: proc(this : ptr ICoreWebView2Controller, token : EventRegistrationToken) : HRESULT {.stdcall.}
            add_AcceleratorKeyPressed*: proc(this : ptr ICoreWebView2Controller, eventHandler : WRLCallback[IUnknown], token : ptr EventRegistrationToken) : HRESULT {.stdcall.}
            remove_AcceleratorKeyPressed*: proc(this : ptr ICoreWebView2Controller, token : EventRegistrationToken) : HRESULT {.stdcall.}
            get_ParentWindow*: proc(this : ptr ICoreWebView2Controller, parentWindow : ptr HWND) : HRESULT {.stdcall.}
            put_ParentWindow*: proc(this : ptr ICoreWebView2Controller, parentWindow : HWND) : HRESULT {.stdcall.}
            NotifyParentWindowPositionChanged*: proc(this : ptr ICoreWebView2Controller) : HRESULT {.stdcall.}
            Close*: proc(this : ptr ICoreWebView2Controller) : HRESULT {.stdcall.}
            get_CoreWebView2*: proc(this : ptr ICoreWebView2Controller, coreWebView : ptr ptr ICoreWebView2) : HRESULT {.stdcall.}

        ## WebView2 enables you to host web content using the latest Microsoft Edge browser and web technology.
        ICoreWebView2* {.pure.} = object
            lpVtbl*: ptr ICoreWebView2Vtbl
        ICoreWebView2Vtbl* {.pure, inheritable.} = object of IUnknownVtbl
            get_Settings*: proc(this : ptr ICoreWebView2, settings : ptr IUnknown) : HRESULT {.stdcall.}
            get_Source*: proc(this : ptr ICoreWebView2, uri : ptr LPWSTR) : HRESULT {.stdcall.}
            Navigate*: proc(this : ptr ICoreWebView2, uri : LPCWSTR) : HRESULT {.stdcall.}
            NavigateToString*: proc(this : ptr ICoreWebView2, htmlContent : LPCWSTR) : HRESULT {.stdcall.}
            add_NavigationStarting*: proc(this : ptr ICoreWebView2, eventHandler : WRLCallback[IUnknown], token : ptr EventRegistrationToken) : HRESULT {.stdcall.}
            remove_NavigationStarting*: proc(this : ptr ICoreWebView2, token : EventRegistrationToken) : HRESULT {.stdcall.}
            add_ContentLoading*: proc(this : ptr ICoreWebView2, eventHandler : WRLCallback[IUnknown], token : ptr EventRegistrationToken) : HRESULT {.stdcall.}
            remove_ContentLoading*: proc(this : ptr ICoreWebView2, token : EventRegistrationToken) : HRESULT {.stdcall.}
            add_SourceChanged*: proc(this : ptr ICoreWebView2, eventHandler : WRLCallback[IUnknown], token : ptr EventRegistrationToken) : HRESULT {.stdcall.}
            remove_SourceChanged*: proc(this : ptr ICoreWebView2, token : EventRegistrationToken) : HRESULT {.stdcall.}
            add_HistoryChanged*: proc(this : ptr ICoreWebView2, eventHandler : WRLCallback[IUnknown], token : ptr EventRegistrationToken) : HRESULT {.stdcall.}
            remove_HistoryChanged*: proc(this : ptr ICoreWebView2, token : EventRegistrationToken) : HRESULT {.stdcall.}
            add_NavigationCompleted*: proc(this : ptr ICoreWebView2, eventHandler : WRLCallback[IUnknown], token : ptr EventRegistrationToken) : HRESULT {.stdcall.}
            remove_NavigationCompleted*: proc(this : ptr ICoreWebView2, token : EventRegistrationToken) : HRESULT {.stdcall.}
            add_FrameNavigationStarting*: proc(this : ptr ICoreWebView2, eventHandler : WRLCallback[IUnknown], token : ptr EventRegistrationToken) : HRESULT {.stdcall.}
            remove_FrameNavigationStarting*: proc(this : ptr ICoreWebView2, token : EventRegistrationToken) : HRESULT {.stdcall.}
            add_FrameNavigationCompleted*: proc(this : ptr ICoreWebView2, eventHandler : WRLCallback[IUnknown], token : ptr EventRegistrationToken) : HRESULT {.stdcall.}
            remove_FrameNavigationCompleted*: proc(this : ptr ICoreWebView2, token : EventRegistrationToken) : HRESULT {.stdcall.}
            add_ScriptDialogOpening*: proc(this : ptr ICoreWebView2, eventHandler : WRLCallback[IUnknown], token : ptr EventRegistrationToken) : HRESULT {.stdcall.}
            remove_ScriptDialogOpening*: proc(this : ptr ICoreWebView2, token : EventRegistrationToken) : HRESULT {.stdcall.}
            add_PermissionRequested*: proc(this : ptr ICoreWebView2, eventHandler : WRLCallback[IUnknown], token : ptr EventRegistrationToken) : HRESULT {.stdcall.}
            remove_PermissionRequested*: proc(this : ptr ICoreWebView2, token : EventRegistrationToken) : HRESULT {.stdcall.}
            add_ProcessFailed*: proc(this : ptr ICoreWebView2, eventHandler : WRLCallback[IUnknown], token : ptr EventRegistrationToken) : HRESULT {.stdcall.}
            remove_ProcessFailed*: proc(this : ptr ICoreWebView2, token : EventRegistrationToken) : HRESULT {.stdcall.}
            AddScriptToExecuteOnDocumentCreated*: proc(this : ptr ICoreWebView2, javaScript : LPCWSTR, callback : WRLCallback[IUnknown]) : HRESULT {.stdcall.}
            RemoveScriptToExecuteOnDocumentCreated*: proc(this : ptr ICoreWebView2, id : LPCWSTR) : HRESULT {.stdcall.}
            ExecuteScript*: proc(this : ptr ICoreWebView2, javaScript : LPCWSTR, callback : WRLCallback[IUnknown]) : HRESULT {.stdcall.}
            CapturePreview*: proc(this : ptr ICoreWebView2, imageFormat : COREWEBVIEW2_CAPTURE_PREVIEW_IMAGE_FORMAT, callback : WRLCallback[IUnknown]) : HRESULT {.stdcall.}
            Reload*: proc(this : ptr ICoreWebView2) : HRESULT {.stdcall.}
            PostWebMessageAsJson*: proc(this : ptr ICoreWebView2, webMessageAsJson : LPCWSTR) : HRESULT {.stdcall.}
            PostWebMessageAsString*: proc(this : ptr ICoreWebView2, webMessageAsString : LPCWSTR) : HRESULT {.stdcall.}
            add_WebMessageReceived*: proc(this : ptr ICoreWebView2, eventHandler : WRLCallback[IUnknown], token : ptr EventRegistrationToken) : HRESULT {.stdcall.}
            remove_WebMessageReceived*: proc(this : ptr ICoreWebView2, token : EventRegistrationToken) : HRESULT {.stdcall.}
            CallDevToolsProtocolMethod*: proc(this : ptr ICoreWebView2, methodName : LPCWSTR, parametersAsJson : LPCWSTR, callback : WRLCallback[IUnknown]) : HRESULT {.stdcall.}
            get_BrowserProcessId*: proc(this : ptr ICoreWebView2, processId : ptr uint32) : HRESULT {.stdcall.}
            get_CanGoBack*: proc(this : ptr ICoreWebView2, canGoBack : ptr bool) : HRESULT {.stdcall.}
            get_CanGoForward*: proc(this : ptr ICoreWebView2, canGoForward : ptr bool) : HRESULT {.stdcall.}
            GoBack*: proc(this : ptr ICoreWebView2) : HRESULT {.stdcall.}
            GoForward*: proc(this : ptr ICoreWebView2) : HRESULT {.stdcall.}
            GetDevToolsProtocolEventReceiver*: proc(this : ptr ICoreWebView2, eventName : LPCWSTR, receiver : ptr ptr IUnknown) : HRESULT {.stdcall.}
            Stop*: proc(this : ptr ICoreWebView2) : HRESULT {.stdcall.}
            add_NewWindowRequested*: proc(this : ptr ICoreWebView2, eventHandler : WRLCallback[IUnknown], token : ptr EventRegistrationToken) : HRESULT {.stdcall.}
            remove_NewWindowRequested*: proc(this : ptr ICoreWebView2, token : EventRegistrationToken) : HRESULT {.stdcall.}
            add_DocumentTitleChanged*: proc(this : ptr ICoreWebView2, eventHandler : WRLCallback[IUnknown], token : ptr EventRegistrationToken) : HRESULT {.stdcall.}
            remove_DocumentTitleChanged*: proc(this : ptr ICoreWebView2, token : EventRegistrationToken) : HRESULT {.stdcall.}
            get_DocumentTitle*: proc(this : ptr ICoreWebView2, title : ptr LPWSTR) : HRESULT {.stdcall.}
            AddHostObjectToScript*: proc(this : ptr ICoreWebView2, name : LPCWSTR, obj : variant) : HRESULT {.stdcall.}
            RemoveHostObjectFromScript*: proc(this : ptr ICoreWebView2, name : LPCWSTR) : HRESULT {.stdcall.}
            OpenDevToolsWindow*: proc(this : ptr ICoreWebView2) : HRESULT {.stdcall.}
            add_ContainsFullScreenElementChanged*: proc(this : ptr ICoreWebView2, eventHandler : WRLCallback[IUnknown], token : ptr EventRegistrationToken) : HRESULT {.stdcall.}
            remove_ContainsFullScreenElementChanged*: proc(this : ptr ICoreWebView2, token : EventRegistrationToken) : HRESULT {.stdcall.}
            get_ContainsFullScreenElement*: proc(this : ptr ICoreWebView2, containsFullScreenElement : ptr bool) : HRESULT {.stdcall.}
            add_WebResourceRequested*: proc(this : ptr ICoreWebView2, eventHandler : WRLCallback[IUnknown], token : ptr EventRegistrationToken) : HRESULT {.stdcall.}
            remove_WebResourceRequested*: proc(this : ptr ICoreWebView2, token : EventRegistrationToken) : HRESULT {.stdcall.}
            AddWebResourceRequestedFilter*: proc(this : ptr ICoreWebView2, uri : LPCWSTR, resourceContext : COREWEBVIEW2_WEB_RESOURCE_CONTEXT) : HRESULT {.stdcall.}
            RemoveWebResourceRequestedFilter*: proc(this : ptr ICoreWebView2, uri : LPCWSTR, resourceContext : COREWEBVIEW2_WEB_RESOURCE_CONTEXT) : HRESULT {.stdcall.}
            add_WindowCloseRequested*: proc(this : ptr ICoreWebView2, eventHandler : WRLCallback[IUnknown], token : ptr EventRegistrationToken) : HRESULT {.stdcall.}
            remove_WindowCloseRequested*: proc(this : ptr ICoreWebView2, token : EventRegistrationToken) : HRESULT {.stdcall.}

    ## Get the browser version info including channel name if it is not the WebView2 Runtime.
    proc GetAvailableCoreWebView2BrowserVersionString*(browserExecutablePath : PCWSTR, versionInfo : ptr LPWSTR) : HRESULT {.stdcall.}

    ## Creates an evergreen WebView2 Environment using the installed WebView2 Runtime version.
    proc CreateCoreWebView2EnvironmentWithOptions*(browserExecutablePath : PCWSTR, userDataFolder : PCWSTR, environmentOptions : pointer, environmentCreatedHandler : WRLCallback[ICoreWebView2Environment]) : HRESULT {.stdcall.}