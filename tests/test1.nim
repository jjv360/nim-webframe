#
# Tests, which simply open a WebFrame and display some HTML content.

import ../src/webframe
import std/asyncdispatch

# Create web frame
var webview = WebFrame.init()
webview.url = "https://google.com"
webview.setSize(600, 800, true)
webview.show()

# Log engine version
echo "WebFrame engine: " & webview.engineVersion()

# Run asyncdispatch until everything has shut down
drain(int.high)