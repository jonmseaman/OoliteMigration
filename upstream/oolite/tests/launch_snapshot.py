"""Launch Oolite headless, drive it over the debug console, and capture one screenshot.

Everything that used to be a module constant is now an argument or an environment variable, so N
copies of ``run_test`` can run at once: each picks its own console port and its own artifact
directory, and nothing is shared between them except the binary. --load hands a saved commander
to the game's -load argument so a run can start docked instead of on the main-menu demo.

Three things here are not obvious and are the reason the file looks the way it does:

* The PORT is not something this script can simply choose. It is the GAME that dials out to the
  console, and it reads the port from `console-port` in debugConfig.plist (OODebugSupport.m:80,
  default kOOTCPConsolePort = 8563 in OODebugTCPConsoleProtocol.h:46). So a port is made real by
  writing a plist the game will merge, not by listening somewhere else. See _console_config_dir.

* Readiness is measured on the GAME's clock, never on this script's. See wait_until_rendering.

* The DESKTOP LOCK is taken by the command-line entry point, NOT by ``run_test`` (bug oo-ccy9).
  Running this file as a script is the build's single smoke launch, and one real window on the
  interactive desktop must exclude the GUI tier's. But ``run_test`` is the reusable half that the
  N-concurrent claim above is about, and an exclusive mutex inside it would serialise - or
  deadlock - exactly the fan-out it exists to support. So the lock wraps the single-launch CLI
  and leaves the library function alone.
"""

import argparse
import os
import plistlib
import select
import shutil
import socket
import struct
import subprocess
import sys
import tempfile
import time

# --- PROTOCOL CONSTANTS ---
# See https://github.com/OoliteProject/oolite-debug-console/blob/master/ooliteConsoleServer/_protocol.py
# Using the exact string definitions required by the Oolite Debug Protocol
REQUEST_CONNECTION = "Request Connection"
APPROVE_CONNECTION = "Approve Connection"
PERFORM_COMMAND = "Perform Command"
CONSOLE_OUTPUT = "Console Output"
PING = "Ping"
PONG = "Pong"
PACKET_TYPE_KEY = "packet type"
MESSAGE_KEY = "message"
CONSOLE_IDENTITY_KEY = "console identity"
OOLITE_VERSION_KEY = "Oolite version"

# --- CONFIGURATION ---
IS_WINDOWS = sys.platform == "win32" or (os.name == "nt")
DEFAULT_PORT = 8563  # kOOTCPConsolePort
DEFAULT_HOST = "127.0.0.1"
DEFAULT_OUTPUT = "./test_output"
MIN_FILE_SIZE_KB = 100  # Threshold for a valid render

# How much of the game's own clock must pass, after it starts answering, before a frame is worth
# capturing. Game time only advances when the run loop runs, so this counts rendered frames rather
# than wall-clock seconds and cannot be exhausted by a slow startup.
DEFAULT_SETTLE_GAME_SECONDS = 2.0


def send_plist_packet(sock, packet):
    """
    Implements the framing protocol from
    https://github.com/OoliteProject/oolite-debug-console/blob/master/ooliteConsoleServer/PropertyListPacketProtocol.py:
    1. Encodes the dictionary as an XML Property List.
    2. Calculates a 32-bit big-endian integer for the length.
    3. Prepends this 4-byte header to the data.
    """
    try:
        # Matches writePlistToString logic for Python 3
        data = plistlib.dumps(packet, fmt=plistlib.FMT_XML)
        length = len(data)

        # Header is 4 bytes, network-endian (Big-Endian)
        header = struct.pack(">I", length)

        sock.sendall(header + data)
        return True
    except Exception as e:
        print(f"[!] Failed to encode/send packet: {e}")
        return False


def receive_plist_packet(sock):
    """
    Implements the receiving state machine from:
    https://github.com/OoliteProject/oolite-debug-console/blob/master/ooliteConsoleServer/OoliteDebugConsoleProtocol.py
    1. Reads the 4-byte header to determine expected length.
    2. Reads the specific number of bytes for the XML payload.
    """
    try:
        header = sock.recv(4)
        if len(header) < 4:
            return None

        length = struct.unpack(">I", header)[0]
        data = b""
        while len(data) < length:
            chunk = sock.recv(length - len(data))
            if not chunk:
                break
            data += chunk

        return plistlib.loads(data)
    except Exception as e:
        print(f"[!] Error receiving packet: {e}")
        return None


def perform(conn, js):
    """Fire a JS string into the game without waiting for anything back."""
    return send_plist_packet(conn, {PACKET_TYPE_KEY: PERFORM_COMMAND, MESSAGE_KEY: js})


def evaluate(conn, js, timeout=20):
    """Run a JS expression in the game and return its result as a string, or None on failure.

    The console answers a command with Console Output packets, so a value has to be sent back
    deliberately: the expression is wrapped and printed between a unique marker this call waits
    for. The marker is split in the source because the console echoes the command text back as
    Console Output before any result, and a marker appearing literally in the command would match
    that echo - the answer would then be read out of the wrong packet.
    """
    head = f"@@{os.getpid()}"
    tail = f"{int(time.time() * 1000) % 1000000}@@"
    marker = head + tail
    wrapped = (
        "(function(){ try { return String(%s); } catch (e) { return 'ERROR: ' + e; } })()" % js
    )
    # debugConsole.consoleMessage(colorCode, message) - OOJSConsole.m. It is a method on the
    # debugConsole global, not a bare function, and the colour key comes first. This route ends in
    # appendJSConsoleLine, which the TCP client forwards to us as a Console Output packet.
    if not perform(
        conn,
        'debugConsole.consoleMessage("command-result", '
        f'"{head}" + "{tail}" + {wrapped} + "{head}" + "{tail}");',
    ):
        return None

    deadline = time.time() + timeout
    while time.time() < deadline:
        readable, _, _ = select.select([conn], [], [], 1)
        if not readable:
            continue
        pkt = receive_plist_packet(conn)
        if pkt is None:
            print("[!] Console connection closed mid-command.")
            return None
        if pkt.get(PACKET_TYPE_KEY) != CONSOLE_OUTPUT:
            continue
        text = str(pkt.get(MESSAGE_KEY, ""))
        if text.count(marker) >= 2:
            return text.split(marker)[1]
    print(f"[!] No answer to {js!r} within {timeout}s.")
    return None


def wait_until_answering(conn, ready_timeout=120):
    """Block until Oolite is actually servicing the debug console.

    Sleeping a fixed number of seconds after sending the approval measures the wrong clock. The
    approval is answered by the game's run loop, and until loading finishes there is no run loop
    to answer it: on a slow machine the entire sleep elapses during startup, the approval and the
    snapshot command are then consumed in the same poll, and the snapshot is taken on the first
    frame the game ever services - before anything has been drawn. That produces a black frame and
    looks like a rendering fault rather than the race it is.

    Ping is echoed back as Pong with the same message (OODebugTCPConsoleProtocol.h), so readiness
    is directly observable instead of guessed at.
    """
    token = f"ready-{os.getpid()}-{time.time()}"
    started = time.time()
    deadline = started + ready_timeout

    while time.time() < deadline:
        if not send_plist_packet(conn, {PACKET_TYPE_KEY: PING, MESSAGE_KEY: token}):
            print("[!] Failure: could not send Ping.")
            return False
        # select rather than a socket timeout: receive_plist_packet reports every exception, and
        # a timeout per poll is normal here, not an error worth printing.
        readable, _, _ = select.select([conn], [], [], 2)
        if not readable:
            continue
        pkt = receive_plist_packet(conn)
        if pkt is None:
            print("[!] Failure: console connection closed while waiting for Oolite.")
            return False
        if pkt.get(PACKET_TYPE_KEY) == PONG and pkt.get(MESSAGE_KEY) == token:
            print(f"[+] Oolite is servicing the console after {time.time() - started:.1f}s")
            return True
        # Anything else (console output, configuration notes) is not an answer; keep waiting.

    print(f"[!] Failure: Oolite did not answer a Ping within {ready_timeout}s.")
    return False


def wait_until_rendering(conn, settle_game_seconds, timeout=120):
    """Wait until the game has actually drawn frames, counted on the game's own clock.

    Answering a Ping proves the run loop is alive; it does not prove anything has been drawn.
    clock.absoluteSeconds is UNIVERSE's time (OOJSClock.m), which only advances while the run loop
    steps, so requiring it to move forward is equivalent to requiring frames - and unlike a sleep
    on this script's clock it cannot be spent while the game is still loading.
    """
    first = evaluate(conn, "clock.absoluteSeconds")
    if first is None:
        return False
    try:
        start = float(first)
    except ValueError:
        print(f"[!] Failure: clock.absoluteSeconds returned {first!r}.")
        return False

    deadline = time.time() + timeout
    while time.time() < deadline:
        now = evaluate(conn, "clock.absoluteSeconds")
        if now is None:
            return False
        try:
            elapsed = float(now) - start
        except ValueError:
            print(f"[!] Failure: clock.absoluteSeconds returned {now!r}.")
            return False
        if elapsed >= settle_game_seconds:
            screen = evaluate(conn, "guiScreen") or "?"
            print(f"[+] {elapsed:.1f}s of game time drawn; guiScreen={screen}")
            return True
        time.sleep(0.5)

    print(f"[!] Failure: game time did not advance {settle_game_seconds}s within {timeout}s.")
    return False


def wait_until_docked(conn, timeout=60):
    """Confirm a --load run reached the docked screen rather than the main-menu demo."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        docked = evaluate(conn, "player.ship.docked")
        if docked is None:
            return False
        if docked.strip().lower() == "true":
            screen = evaluate(conn, "guiScreen") or "?"
            print(f"[+] Loaded save is docked; guiScreen={screen}")
            return True
        time.sleep(1)
    print(f"[!] Failure: the loaded save was not docked within {timeout}s.")
    return False


def _console_config_dir(host, port):
    """Create a throwaway resource root that tells the game which console port to dial.

    The game reads console-host/console-port out of debugConfig.plist, merged across every search
    path (OODebugSupport.m:67-80), so this is the only way to move it off 8563. A directory named
    in OO_ADDITIONALADDONSDIRS becomes a search root (OOOXZManager.m:286 -> ResourceManager
    userRootPaths), and a plain directory root needs no manifest.plist. The stock Debug OXP leaves
    both keys commented out, so whatever this writes wins the merge regardless of path order.

    Returned path must be removed by the caller.
    """
    root = tempfile.mkdtemp(prefix=f"oolite-console-{port}-")
    config = os.path.join(root, "Config")
    os.makedirs(config, exist_ok=True)
    with open(os.path.join(config, "debugConfig.plist"), "wb") as handle:
        plistlib.dump({"console-host": host, "console-port": port}, handle,
                      fmt=plistlib.FMT_XML)
    return root


def run_test(bin_name, test_output, port, host, load_save, settle_game_seconds, ready_timeout):
    # Setup TCP Server
    server_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server_sock.bind((host, port))
    server_sock.listen(1)
    server_sock.setblocking(False)

    print(f"[*] Console server listening on {host}:{port}")

    config_dir = _console_config_dir(host, port)

    # Environment configuration for pure headless software offscreen rendering
    env = os.environ.copy()
    if not IS_WINDOWS:
        env["SDL_VIDEODRIVER"] = "offscreen"
    env["LIBGL_ALWAYS_SOFTWARE"] = "1"
    env["GALLIUM_DRIVER"] = "llvmpipe"
    env["SDL_AUDIODRIVER"] = "dummy"

    env["ALSOFT_DRIVERS"] = "null"
    env["OO_SNAPSHOTSDIR"] = test_output

    env["OO_LOGSDIR"] = test_output

    # Prepended rather than replaced: a caller may already be pointing the game at add-ons.
    existing = env.get("OO_ADDITIONALADDONSDIRS")
    env["OO_ADDITIONALADDONSDIRS"] = f"{config_dir},{existing}" if existing else config_dir

    cmd = [f"./{bin_name}", "--no-splash"]
    if load_save:
        # src/SDL/main.m:167 - the argument after -load is taken as the commander to load, and it
        # must end in .oolite-save for the game to accept it.
        cmd += ["-load", load_save]

    print(f"[*] Executing: {' '.join(cmd)}")
    proc = subprocess.Popen(
        cmd,
        env=env,
        stdout=sys.stdout,
        stderr=sys.stderr,
    )

    conn = None
    try:
        # 1. Wait for Oolite to initiate connection
        timeout = time.time() + 60
        while time.time() < timeout:
            if proc.poll() is not None:
                print(f"[!] Failure: Oolite exited with {proc.returncode} before connecting.")
                return False
            readable, _, _ = select.select([server_sock], [], [], 1)
            if readable:
                conn, addr = server_sock.accept()
                conn.setblocking(True)
                print(f"[+] Oolite connected from {addr}")
                break

        if not conn:
            print("[!] Failure: Oolite failed to connect.")
            return False

        # 2. THE HANDSHAKE
        pkt = receive_plist_packet(conn)

        if pkt and pkt.get(PACKET_TYPE_KEY) == REQUEST_CONNECTION:
            print(
                f"[+] Handshake started. Oolite version: {pkt.get(OOLITE_VERSION_KEY)}"
            )

            # Respond with 'Approve Connection' and identity
            approval = {
                PACKET_TYPE_KEY: APPROVE_CONNECTION,
                CONSOLE_IDENTITY_KEY: "OoliteAutomationTester",
            }
            send_plist_packet(conn, approval)
            print("[*] Connection Approved.")
        else:
            print("[!] Handshake failed: Expected 'Request Connection'.")
            return False

        # Wait for the game itself, not for the clock. See wait_until_answering.
        if not wait_until_answering(conn, ready_timeout=ready_timeout):
            return False
        if not wait_until_rendering(conn, settle_game_seconds):
            return False
        if load_save and not wait_until_docked(conn):
            return False

        # 3. THE COMMAND. Snapshot and quit are separate, and the file is waited for: sending
        # both at once means the game may quit on the same frame it snapshots.
        print("[*] Requesting snapshot...")
        before = set(f for f in os.listdir(test_output) if f.endswith(".png"))
        perform(conn, "takeSnapShot();")

        snap_path = None
        deadline = time.time() + 30
        while time.time() < deadline:
            new = [f for f in os.listdir(test_output) if f.endswith(".png") and f not in before]
            if new:
                snap_path = os.path.join(test_output, sorted(new)[0])
                # The PNG is written by the game; wait for its size to stop changing.
                size = -1
                while size != os.path.getsize(snap_path):
                    size = os.path.getsize(snap_path)
                    time.sleep(0.3)
                break
            time.sleep(0.3)

        print("[*] Requesting quit...")
        perform(conn, "quit();")

        # 4. WAIT FOR PROCESS EXIT
        print("[*] Waiting for process to exit...")
        try:
            proc.wait(timeout=30)
        except subprocess.TimeoutExpired:
            print("[!] Error: Oolite ignored the shutdown command.")
            return False

        # 5. VERIFY OUTPUT
        if snap_path is None:
            print("[!] Error: Oolite exited but no snapshot was found.")
            return False

        file_size_kb = os.path.getsize(snap_path) // 1024
        print(f"[*] Captured {snap_path} ({file_size_kb} KB)")

        if file_size_kb < MIN_FILE_SIZE_KB:
            print(
                f"[!] Failure: Snapshot is too small ({file_size_kb} KB). Likely a black frame."
            )
            return False

        print("[+] Success: Snapshot passed quality check.")
        return True

    finally:
        if conn:
            conn.close()
        server_sock.close()
        if proc.poll() is None:
            proc.kill()
        shutil.rmtree(config_dir, ignore_errors=True)


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description="Oolite Automation Tester")
    parser.add_argument(
        "--path",
        default=os.environ.get("OO_APP_DIR", "./"),
        help="Path to the Oolite directory or binary (default: $OO_APP_DIR, else ./)",
    )
    parser.add_argument(
        "--output",
        "--test_output",
        dest="output",
        default=os.environ.get("OO_TEST_OUTPUT", DEFAULT_OUTPUT),
        help="Artifact directory for the snapshot and Latest.log; one per instance "
        f"(default: $OO_TEST_OUTPUT, else {DEFAULT_OUTPUT})",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=int(os.environ.get("OO_CONSOLE_PORT", DEFAULT_PORT)),
        help=f"Debug-console port this instance uses (default: $OO_CONSOLE_PORT, else {DEFAULT_PORT})",
    )
    parser.add_argument(
        "--host",
        default=os.environ.get("OO_CONSOLE_HOST", DEFAULT_HOST),
        help=f"Address to listen on (default: $OO_CONSOLE_HOST, else {DEFAULT_HOST})",
    )
    parser.add_argument(
        "--load",
        metavar="FILE.oolite-save",
        default=os.environ.get("OO_LOAD_SAVE") or None,
        help="Saved commander to hand to the game's -load argument, so the run starts docked",
    )
    parser.add_argument(
        "--settle-frames",
        type=float,
        default=float(os.environ.get("OO_SNAPSHOT_SETTLE", DEFAULT_SETTLE_GAME_SECONDS)),
        help="Seconds of the GAME's clock that must pass before snapshotting "
        f"(default: $OO_SNAPSHOT_SETTLE, else {DEFAULT_SETTLE_GAME_SECONDS})",
    )
    parser.add_argument(
        "--ready-timeout",
        type=float,
        default=float(os.environ.get("OO_READY_TIMEOUT", "120")),
        help="Seconds to wait for the game to start answering the console (default: 120)",
    )
    return parser.parse_args(argv)


def _desktop_lock_helper():
    """tools/desktop_lock from the OUTER repository, or None when there is none.

    This file lives in a subtree that is also pushed to the fork on its own, where tools/ does
    not exist; there is no fleet to collide with there, so a missing helper is not an error. When
    the outer repository IS around us, its tools/gui-lock is the desktop mutex every launcher on
    this machine shares, and this launcher must take it (bug oo-ccy9).
    """
    here = os.path.dirname(os.path.abspath(__file__))
    while True:
        tools = os.path.join(here, "tools")
        if os.path.isfile(os.path.join(tools, "gui-lock")) and os.path.isfile(
            os.path.join(tools, "desktop_lock.py")
        ):
            if tools not in sys.path:
                sys.path.insert(0, tools)
            import desktop_lock  # noqa: F401  - located at runtime, on purpose

            return desktop_lock
        parent = os.path.dirname(here)
        if parent == here:
            print(
                "[!] no tools/desktop_lock.py above this checkout; "
                "launching WITHOUT the desktop mutex"
            )
            return None
        here = parent


if __name__ == "__main__":
    args = parse_args()

    # Determine binary name and original path
    bin_name = "oolite.exe" if IS_WINDOWS else "oolite"
    original_cwd = os.getcwd()
    target_dir = os.path.abspath(args.path)

    # If the user pointed to a file, get the containing directory
    if os.path.isfile(target_dir):
        bin_name = os.path.basename(target_dir)
        target_dir = os.path.dirname(target_dir)

    # Resolved before the chdir below, so relative paths mean what the caller meant.
    test_output = os.path.abspath(args.output)
    os.makedirs(test_output, exist_ok=True)
    load_save = os.path.abspath(args.load) if args.load else None
    if load_save and not os.path.isfile(load_save):
        print(f"[!] Failure: no save file at {load_save}")
        sys.exit(1)

    success = False
    try:
        print(f"[*] Moving to {target_dir}")
        os.chdir(target_dir)

        # THE DESKTOP LOCK (bug oo-ccy9). This is the smoke test, and it launches ONE game -
        # which on Windows means one real window on the interactive desktop, because
        # SDL_VIDEODRIVER=offscreen is deliberately not set there. Two games on the desktop at
        # once steal each other's foreground, so it queues behind the GUI tier rather than
        # racing it.
        #
        # The lock lives in the OUTER repository (tools/gui-lock), not in this subtree, and this
        # file must keep working when the subtree is pushed to the fork on its own - so the
        # helper is located at runtime and a missing one is a warning, not a failure. It is also
        # taken around run_test only: acquiring before the chdir above would hold the desktop
        # while resolving paths, which is free but says the wrong thing about what the lock
        # protects.
        lock_helper = _desktop_lock_helper()
        if lock_helper is None:
            success = run_test(
                bin_name,
                test_output,
                args.port,
                args.host,
                load_save,
                args.settle_frames,
                args.ready_timeout,
            )
        else:
            with lock_helper.desktop_lock("smoke", start=__file__, stream=sys.stdout):
                # Run the test from within the Oolite directory
                success = run_test(
                    bin_name,
                    test_output,
                    args.port,
                    args.host,
                    load_save,
                    args.settle_frames,
                    args.ready_timeout,
                )

    except Exception as e:
        print(f"[!] Critical Error: {e}")
    finally:
        # ALWAYS return to the original path
        os.chdir(original_cwd)
        print(f"[*] Returned to {original_cwd}")

    sys.exit(0 if success else 1)
