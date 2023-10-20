#
# Nim WebFrame - Provides a simple WebView UI for Nim, compatible with asyncdispatch.

# Shared imports

# Platform-specific imports:
when defined(windows):
    import ./webframe/windows
    export windows