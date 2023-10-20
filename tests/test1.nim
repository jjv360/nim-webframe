#
# Tests, which simply open a WebFrame and display some HTML content.

import ../src/webframe
import std/asyncdispatch

# Create web frame
var webview = WebFrame.init()

# Log engine version
echo "WebFrame engine: " & webview.engineVersion()

# Show the web frame
webview.show()

# Run asyncdispatch until everything has shut down
drain(int.high)