"""HTTPS for every web request Senada makes.

Python on Windows only trusts the root certificates already present in the Windows store,
and Windows installs most roots on demand (the first time a browser needs one). A fresh
Windows can therefore lack e.g. the Starfield root behind open.spotify.com, and every
request there fails with CERTIFICATE_VERIFY_FAILED. certifi's bundle (shipped with the
Windows build) is loaded on top of the system certificates to fill that gap; without
certifi the system certificates are used alone, which is enough on Linux.
"""

import ssl
import urllib.request


def _context() -> ssl.SSLContext:
    ctx = ssl.create_default_context()
    try:
        import certifi
        ctx.load_verify_locations(certifi.where())
    except (ImportError, OSError, ssl.SSLError):
        pass
    return ctx


SSL_CONTEXT = _context()


def urlopen(req, timeout: float):
    """urllib.request.urlopen with Senada's certificate store."""
    return urllib.request.urlopen(req, timeout=timeout, context=SSL_CONTEXT)
