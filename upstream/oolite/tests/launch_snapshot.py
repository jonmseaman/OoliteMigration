import argparse
import socket
import subprocess
import time
import os
import select
import sys
import struct
import plistlib
import tempfile
import shutil

# --- PROTOCOL CONSTANTS ---
# See https://github.com/OoliteProject/oolite-debug-console/blob/master/ooliteConsoleServer/_protocol.py
# Using the exact string definitions required by the Oolite Debug Protocol
REQUEST_CONNECTION = "Request Connection"
APPROVE_CONNECTION = "Approve Connection"
PERFORM_COMMAND = "Perform Command"
PING = "Ping"
PONG = "Pong"
PACKET_TYPE_KEY = "packet type"
MESSAGE_KEY = "message"
CONSOLE_IDENTITY_KEY = "console identity"
OOLITE_VERSION_KEY = "Oolite version"

# --- CONFIGURATION ---
IS_WINDOWS = sys.platform == "win32" or (os.name == "nt")
PORT = 8563
HOST = "127.0.0.1"
MIN_FILE_SIZE_KB = 100  # Threshold for a valid render


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


def wait_until_ready(conn, ready_timeout=120, settle=None):
    """Block until Oolite is actually servicing the debug console, then let it draw some frames.

    Sleeping a fixed number of seconds after sending the approval measures the wrong clock. The
    approval is answered by the game's run loop, and until loading finishes there is no run loop
    to answer it: on a slow machine the entire sleep elapses during startup, the approval and the
    snapshot command are then consumed in the same poll, and the snapshot is taken on the first
    frame the game ever services - before anything has been drawn. That produces a black frame
    and looks like a rendering fault rather than a race.

    Ping is echoed back as Pong with the same message (see OODebugTCPConsoleProtocol.h), so
    readiness is directly observable instead of guessed at. Only once the game answers is it
    worth counting out frame time, and the settle below is measured from that point.
    """
    if settle is None:
        settle = float(os.environ.get("OO_SNAPSHOT_SETTLE", "5"))
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
            waited = time.time() - started
            print(f"[+] Oolite is servicing the console after {waited:.1f}s; settling {settle}s")
            time.sleep(settle)
            return True
        # Anything else (console output, configuration notes) is not an answer; keep waiting.

    print(f"[!] Failure: Oolite did not answer a Ping within {ready_timeout}s.")
    return False


def run_test(bin_name, test_output):
    # Setup TCP Server
    server_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server_sock.bind((HOST, PORT))
    server_sock.listen(1)
    server_sock.setblocking(False)

    print(f"[*] Console server listening on {PORT}")

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

    cmd = [f"./{bin_name}", "--no-splash"]

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
        timeout = time.time() + 20
        while time.time() < timeout:
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

        # Wait for the game itself, not for the clock. See wait_until_ready.
        if not wait_until_ready(conn):
            return False

        # 3. THE COMMAND
        print("[*] Requesting snapshot and quit...")
        cmd_packet = {
            PACKET_TYPE_KEY: PERFORM_COMMAND,
            MESSAGE_KEY: "takeSnapShot(); quit();",
        }
        send_plist_packet(conn, cmd_packet)

        # 4. WAIT FOR PROCESS EXIT
        print("[*] Waiting for process to exit...")
        try:
            proc.wait(timeout=15)

            # 5. VERIFY OUTPUT
            snaps = [f for f in os.listdir(test_output) if f.endswith(".png")]
            if snaps:
                snap_path = os.path.join(test_output, snaps[0])
                file_size_kb = os.path.getsize(snap_path) // 1024
                print(f"[*] Captured {snap_path} ({file_size_kb} KB)")

                if file_size_kb < MIN_FILE_SIZE_KB:
                    print(
                        f"[!] Failure: Snapshot is too small ({file_size_kb} KB). Likely a black frame."
                    )
                    return False

                print("[+] Success: Snapshot passed quality check.")
                return True
            else:
                print("[!] Error: Oolite exited but no snapshot was found.")
                return False

        except subprocess.TimeoutExpired:
            print("[!] Error: Oolite ignored the shutdown command.")
            return False

    finally:
        if conn:
            conn.close()
        server_sock.close()
        if proc.poll() is None:
            proc.kill()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Oolite Automation Tester")
    parser.add_argument(
        "--path", default="./", help="Path to the Oolite directory (default: ./)"
    )
    parser.add_argument(
        "--test_output", default="./test_output", help="Path to test output (default: ./test_output)"
    )
    args = parser.parse_args()

    # Determine binary name and original path
    bin_name = "oolite.exe" if IS_WINDOWS else "oolite"
    original_cwd = os.getcwd()
    target_dir = os.path.abspath(args.path)

    # If the user pointed to a file, get the containing directory
    if os.path.isfile(target_dir):
        bin_name = os.path.basename(target_dir)
        target_dir = os.path.dirname(target_dir)

    success = False
    try:
        print(f"[*] Moving to {target_dir}")
        os.chdir(target_dir)

        # Run the test from within the Oolite directory
        success = run_test(bin_name, args.test_output)

    except Exception as e:
        print(f"[!] Critical Error: {e}")
    finally:
        # ALWAYS return to the original path
        os.chdir(original_cwd)
        print(f"[*] Returned to {original_cwd}")

    sys.exit(0 if success else 1)
