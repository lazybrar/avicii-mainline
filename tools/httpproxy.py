#!/usr/bin/env python3
# Minimal forward HTTP proxy (plain GET/HEAD/POST and CONNECT) so the phone, which only has the
# USB link to this PC, can fetch packages. No root needed. Bind to the USB interface address only.
# usage: httpproxy.py [bind_ip] [port]      phone side: export http_proxy=http://172.16.42.2:3128
import select, socket, sys, threading
from urllib.parse import urlsplit

BIND = sys.argv[1] if len(sys.argv) > 1 else "172.16.42.2"
PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 3128


def pump(a, b):
    socks = [a, b]
    try:
        while True:
            r, _, x = select.select(socks, [], socks, 300)
            if x or not r:
                return
            for s in r:
                d = s.recv(65536)
                if not d:
                    return
                (b if s is a else a).sendall(d)
    except OSError:
        pass
    finally:
        a.close()
        b.close()


def handle(c):
    try:
        buf = b""
        while b"\r\n\r\n" not in buf:
            d = c.recv(65536)
            if not d:
                c.close()
                return
            buf += d
        head, rest = buf.split(b"\r\n\r\n", 1)
        lines = head.split(b"\r\n")
        method, target, ver = lines[0].decode("latin1").split(" ", 2)
        if method == "CONNECT":
            host, _, port = target.partition(":")
            up = socket.create_connection((host, int(port or 443)), timeout=30)
            c.sendall(b"HTTP/1.1 200 Connection established\r\n\r\n")
            if rest:
                up.sendall(rest)
        else:
            u = urlsplit(target)
            up = socket.create_connection((u.hostname, u.port or 80), timeout=30)
            path = (u.path or "/") + ("?" + u.query if u.query else "")
            hdrs = [l for l in lines[1:] if not l.lower().startswith((b"proxy-connection:", b"connection:"))]
            req = ("%s %s %s\r\n" % (method, path, ver)).encode("latin1") + b"\r\n".join(hdrs)
            up.sendall(req + b"\r\nConnection: close\r\n\r\n" + rest)
        up.settimeout(None)
        c.settimeout(None)
        pump(c, up)
    except Exception:
        try:
            c.close()
        except OSError:
            pass


def main():
    s = socket.socket()
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind((BIND, PORT))
    s.listen(64)
    while True:
        c, _ = s.accept()
        threading.Thread(target=handle, args=(c,), daemon=True).start()


if __name__ == "__main__":
    main()
