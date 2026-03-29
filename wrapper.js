// Clobber online wrapper — PeerJS + PICO-8 GPIO bridge

(function () {
  "use strict";

  // ICE server config for WebRTC
  var peerConfig = {
    config: {
      iceServers: [
        { urls: "stun:stun.l.google.com:19302" },
        { urls: "stun:stun1.l.google.com:19302" },
        { urls: "stun:stun2.l.google.com:19302" },
        { urls: "stun:stun3.l.google.com:19302" },
        { urls: "stun:stun4.l.google.com:19302" },
      ],
    },
  };

  // GPIO array is exposed by PICO-8's web export
  // pico8_gpio is a 128-element array shared with the cart
  let peer = null;
  let conn = null;
  let isHost = false;
  let roomCode = "";

  const overlay = document.getElementById("overlay");
  const roomPanel = document.getElementById("room-panel");
  const hostBtn = document.getElementById("host-btn");
  const joinBtn = document.getElementById("join-btn");
  const joinInput = document.getElementById("join-input");
  const roomCodeDisplay = document.getElementById("room-code-display");
  const roomCodeText = document.getElementById("room-code");
  const statusText = document.getElementById("status-text");

  function generateCode() {
    const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    let code = "";
    for (let i = 0; i < 4; i++) {
      code += chars[Math.floor(Math.random() * chars.length)];
    }
    return code;
  }

  function gpio() {
    return window.pico8_gpio || [];
  }

  function showOverlay() {
    overlay.style.display = "flex";
  }

  function hideOverlay() {
    overlay.style.display = "none";
  }

  function setStatus(msg) {
    statusText.textContent = msg;
  }

  function setupConnection(c) {
    conn = c;
    conn.on("open", function () {
      gpio()[0] = 2; // connected
      if (isHost) {
        gpio()[1] = 1; // host is black
        // send config to peer
        const boardSize = gpio()[16] || 0;
        conn.send({ type: "config", boardSize: boardSize, color: 2 });
      }
      setStatus("Connected!");
      setTimeout(hideOverlay, 500);
    });

    conn.on("data", function (data) {
      if (data.type === "move") {
        // incoming move from peer
        gpio()[3] = data.fx;
        gpio()[4] = data.fy;
        gpio()[5] = data.tx;
        gpio()[6] = data.ty;
        gpio()[2] = 1; // flag: new move
      } else if (data.type === "config") {
        // joiner receives config from host
        gpio()[1] = data.color; // our assigned color
        gpio()[7] = data.boardSize;
      }
    });

    conn.on("close", function () {
      gpio()[0] = 3; // disconnected
      setStatus("Opponent disconnected.");
      showOverlay();
    });

    conn.on("error", function (err) {
      setStatus("Connection error: " + err.message);
    });
  }

  hostBtn.addEventListener("click", function () {
    if (peer) { peer.destroy(); peer = null; }
    roomCode = generateCode();
    const peerId = "CLOB-" + roomCode;
    setStatus("Creating room...");
    hostBtn.disabled = true;

    peer = new Peer(peerId, peerConfig);
    isHost = true;

    peer.on("open", function () {
      roomCodeDisplay.style.display = "block";
      roomCodeText.textContent = roomCode;
      gpio()[0] = 1; // waiting
      setStatus("Waiting for opponent to join...");
    });

    peer.on("connection", function (c) {
      setupConnection(c);
    });

    peer.on("error", function (err) {
      if (err.type === "unavailable-id") {
        // room code collision, try again
        roomCode = generateCode();
        peer.destroy();
        hostBtn.disabled = false;
        hostBtn.click();
      } else {
        setStatus("Error: " + err.message);
        hostBtn.disabled = false;
      }
    });
  });

  joinBtn.addEventListener("click", function () {
    const code = joinInput.value.trim().toUpperCase();
    if (code.length !== 4) {
      setStatus("Enter a 4-character room code.");
      return;
    }

    const peerId = "CLOB-" + code;
    setStatus("Connecting...");
    joinBtn.disabled = true;

    peer = new Peer(peerConfig);

    peer.on("open", function () {
      const c = peer.connect(peerId);
      setupConnection(c);
    });

    peer.on("error", function (err) {
      if (err.type === "peer-unavailable") {
        setStatus("Room not found. Check the code.");
      } else {
        setStatus("Error: " + err.message);
      }
      joinBtn.disabled = false;
    });
  });

  // GPIO polling loop
  setInterval(function () {
    const g = gpio();
    if (!g.length) return;

    // Check pin 20 for overlay show/hide requests from PICO-8
    if (g[20] === 1) {
      showOverlay();
      g[20] = 0;
    } else if (g[20] === 2) {
      hideOverlay();
      g[20] = 0;
    }

    // Check pin 10 for outgoing moves
    if (g[10] === 1 && conn && conn.open) {
      conn.send({
        type: "move",
        fx: g[11],
        fy: g[12],
        tx: g[13],
        ty: g[14],
      });
      g[10] = 0; // acknowledge
    }
  }, 50);
})();
