import std/asyncdispatch
import winim/com

## Generic WRL::Callback C++ class, created by us
type

    ## Callback vtbl
    WRLCallbackVtbl {.pure, inheritable.} = object of IUnknownVtbl
        Invoke: proc(this: ptr IUnknown, res: HRESULT, output: ptr IUnknown) : HRESULT {.stdcall.}

    ## Generic WRL::Callback C++ class
    WRLCallback* [T] {.pure.} = ref object
        lpVtbl: ptr WRLCallbackVtbl
        vtbl : WRLCallbackVtbl
        refCount: ULONG
        outputObject : ptr T
        resultCode : HRESULT
        isComplete : bool


## Create new WRLCallback
proc newWRLCallback* [T] () : WRLCallback[T] =

    # Create callback class
    var callback = WRLCallback[T]()
    callback.refCount = 0
    callback.isComplete = false
    callback.lpVtbl = callback.vtbl.addr
    callback.lpVtbl.QueryInterface = proc(this: ptr IUnknown, riid: REFIID, ppvObject: ptr pointer) : HRESULT {.stdcall.} =

        # TODO: Really we should be checking GUID's here...
        return S_OK

    callback.lpVtbl.AddRef = proc(this2: ptr IUnknown) : ULONG {.stdcall.} =

        # Increase reference counter
        var this = cast[WRLCallback[T]](this2)
        this.refCount += 1
        return this.refCount

    callback.lpVtbl.Release = proc(this2: ptr IUnknown) : ULONG {.stdcall.} =

        # Decrease reference counter
        var this = cast[WRLCallback[T]](this2)
        if this.refCount > 0: this.refCount -= 1

        # If we've hit zero, delete the object
        if this.refCount == 0:
            GC_unref(this)

        return this.refCount

    callback.lpVtbl.Invoke = proc(this2: ptr IUnknown, resultCode: HRESULT, outputObject: ptr IUnknown) : HRESULT {.stdcall.} =

        # Store result
        var this = cast[WRLCallback[T]](this2)
        this.outputObject = cast[ptr T](outputObject)
        this.resultCode = resultCode
        this.isComplete = true

        # Increase reference count on the returned object so it isn't immediately disposed by the owner
        discard outputObject.lpVtbl.AddRef(outputObject)
        return S_OK

    # Manually increase ref count so the object is not removed until the remote side is done with it
    GC_ref(callback)

    # Done
    return callback


## Check an HRESULT and throw an error if needed
proc checkHResult*(res : HRESULT, prefix : string = "") =

    # Handle known errors
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

    # Try to extract it from a system error
    var buffer : LPWSTR = nil
    var numChars = FormatMessageW(FORMAT_MESSAGE_ALLOCATE_BUFFER or FORMAT_MESSAGE_FROM_SYSTEM, nil, res, 0, buffer, 0, nil)
    if numChars > 0:

        # Copy string
        let msg = $buffer
        LocalFree(cast[HLOCAL](buffer))

        # Done
        raise newException(OSError, prefix & " Error 0x" & res.uint.toHex & ". " & msg)
    
    else:
    
        # Unable to get error text, just display the error code.
        raise newException(OSError, prefix & " Error 0x" & res.uint.toHex & ".")


## Wait for the callback to complete
proc getResult* [T] (this : WRLCallback[T]) : Future[ptr T] {.async.} = 

    # Wait for it to complete
    while not this.isComplete:
        await sleepAsync(10)

    # Check for error
    checkHResult(this.resultCode, "Async error.")

    # Done
    return this.outputObject