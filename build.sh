#!/bin/bash
# Patches the PICO-8 HTML export with online multiplayer overlay and scripts.
# Usage: After running `export clobber.html` in PICO-8, run this script.

set -e
cd "$(dirname "$0")"

if [ ! -f clobber.html ]; then
  echo "Error: clobber.html not found. Export from PICO-8 first."
  exit 1
fi

# Prevent double-patching
if grep -q 'wrapper.js' clobber.html; then
  echo "Error: clobber.html is already patched. Re-export from PICO-8 first."
  exit 1
fi

# Inject overlay HTML after the canvas tag
sed -i '' 's|</canvas>|</canvas>\
\
				<!-- Online play overlay -->\
				<div id="overlay" style="display:none; position:absolute; top:0; left:0; width:100%; height:100%;\
					align-items:center; justify-content:center; background:rgba(0,0,0,0.85); z-index:10;">\
					<div id="room-panel" style="background:#1d2b53; border:2px solid #7e7e7e; border-radius:8px;\
						padding:24px; color:#fff; font-family:monospace; text-align:center; max-width:280px;">\
						<h2 style="margin:0 0 16px; font-size:18px; color:#ff77a8;">Online Play</h2>\
						<button id="host-btn" style="background:#29adff; color:#000; border:none; padding:8px 16px;\
							font-family:monospace; font-size:14px; cursor:pointer; border-radius:4px;">Create Room</button>\
						<p id="room-code-display" style="display:none; margin:12px 0;">\
							Room Code: <span id="room-code" style="font-size:28px; font-weight:bold;\
								color:#ffec27; letter-spacing:6px;"></span>\
						</p>\
						<hr style="border:none; border-top:1px solid #555; margin:16px 0;">\
						<input id="join-input" placeholder="CODE" maxlength="4" style="background:#000; color:#fff;\
							border:1px solid #7e7e7e; padding:8px; font-family:monospace; font-size:16px;\
							text-align:center; text-transform:uppercase; letter-spacing:4px; width:100px; border-radius:4px;">\
						<button id="join-btn" style="background:#29adff; color:#000; border:none; padding:8px 16px;\
							font-family:monospace; font-size:14px; cursor:pointer; border-radius:4px; margin-left:4px;">Join</button>\
						<p id="status-text" style="margin-top:12px; font-size:12px; color:#83769c;"></p>\
					</div>\
				</div>|' clobber.html

# Inject PeerJS and wrapper.js before </body>
sed -i '' 's|</body>|<script src="https://unpkg.com/peerjs@1.5.4/dist/peerjs.min.js"></script>\
<script src="wrapper.js"></script>\
</body>|' clobber.html

echo "Done! clobber.html patched with online multiplayer support."
