#!/usr/bin/env python3
# Run a shell command on the phone's initramfs through busybox telnetd.
# usage: psh.py 'command...'   (host 172.16.42.1, override with PHONE=ip)
import os, socket, sys, time

HOST = os.environ.get("PHONE", "172.16.42.1")
TMO = float(os.environ.get("PSH_TIMEOUT", "30"))
IAC, DONT, DO, WONT, WILL, SB, SE = 255, 254, 253, 252, 251, 250, 240
END = "__PSH_END_%d__" % os.getpid()
BEG = "__PSH_BEG_%d__" % os.getpid()


def strip_iac(sock, data):
    out = bytearray()
    i = 0
    while i < len(data):
        b = data[i]
        if b == IAC and i + 1 < len(data):
            c = data[i + 1]
            if c in (DO, DONT, WILL, WONT) and i + 2 < len(data):
                # refuse every option so the session stays a plain byte stream
                reply = WONT if c in (DO, DONT) else DONT
                sock.sendall(bytes([IAC, reply, data[i + 2]]))
                i += 3
                continue
            if c == SB:
                j = data.find(bytes([IAC, SE]), i)
                i = len(data) if j < 0 else j + 2
                continue
            i += 2
            continue
        out.append(b)
        i += 1
    return bytes(out)


def main():
    cmd = " ".join(sys.argv[1:])
    s = socket.create_connection((HOST, 23), timeout=10)
    s.settimeout(1.0)
    time.sleep(0.5)
    try:
        strip_iac(s, s.recv(4096))
    except socket.timeout:
        pass
    # the marker is split in the sent text so the tty echo does not match it
    s.sendall(("echo %s%s; %s; echo %s%s\n" % (BEG[:6], '""' + BEG[6:], cmd, END[:6], '""' + END[6:])).encode())
    buf = b""
    deadline = time.time() + TMO
    while time.time() < deadline and END.encode() not in buf:
        try:
            d = s.recv(65536)
        except socket.timeout:
            continue
        if not d:
            break
        buf += strip_iac(s, d)
    s.close()
    text = buf.decode(errors="replace").replace("\r\n", "\n")
    # the tty echoes the command (with split markers); real output sits between the joined ones
    if BEG + "\n" in text:
        text = text[text.index(BEG + "\n") + len(BEG) + 1 :]
    if END in text:
        text = text[: text.index(END)]
    sys.stdout.write(text)


if __name__ == "__main__":
    main()
