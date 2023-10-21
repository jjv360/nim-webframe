# Nim WebFrame
![Status: Incomplete](https://img.shields.io/badge/status-incomplete-red.svg)
![Platforms: Windows](https://img.shields.io/badge/platforms-windows-blue.svg)

This library lets you display web content from Nim, using the OS's built-in WebViews. The goal is a simple API and a _very_ small footprint. For example, the test binary on Windows compiles to 660KB!

It also aims to be compatible with Nim's asyncdispatch without creating threads.

## Usage Examples

### Simple usage

```nim
import std/asyncdispatch
import webframe

# Create web frame
var webview = WebFrame.init()
webview.url = "https://test.com"
webview.show()

# Run asyncdispatch until everything has shut down
drain(int.high)
```

### All APIs

```nim
# Set the window size
webview.setSize(800, 600, center = true)

# Set window position
webview.setPosition(200, 200)

# Get current document title
echo webview.documentTitle

# Show and hide the window
webview.show()
webview.hide()

# Get the engine version
echo webview.engineVersion

# Bundle a directory into the binary and load the index.html file
# Path is relative to the source file which calls this function.
webview.loadBundle("./web")

# Post a message to the window, see https://developer.mozilla.org/en-US/docs/Web/API/Window/postMessage
webview.postMessage("hello")

# Listen for when the web content posts a message to the "opener", eg. `window.opener.postMessage("hello")`
webview.onMessage = proc(msg: string) =
    echo "Message from web content: ", msg
```