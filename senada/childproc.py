"""Start helper programs (mpv) so they end together with Senada.

Senada stops mpv when it quits normally, but after a crash, a kill or a logout mpv would
keep running on its own (it waits idle forever). So the child is tied to Senada:
- Linux: the kernel sends the child SIGTERM when Senada's main thread dies (PR_SET_PDEATHSIG).
- Windows: the child goes into a job object that kills it when Senada's handle to the job
  closes, which Windows does when Senada exits in any way (JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE).
Elsewhere, or if this fails, the child simply starts untied.
"""

import ctypes
import os
import signal
import subprocess
import sys

PR_SET_PDEATHSIG = 1
JOB_OBJECT_EXTENDED_LIMIT_INFORMATION = 9
JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = 0x2000


def _linux_preexec():
    """preexec_fn for Popen: set up in the parent (no library loading after fork)."""
    try:
        prctl = ctypes.CDLL(None, use_errno=True).prctl
    except (OSError, AttributeError):
        return None
    parent = os.getpid()

    def tie():  # runs in the child, between fork and exec
        prctl(PR_SET_PDEATHSIG, signal.SIGTERM)
        if os.getppid() != parent:  # Senada already died before the tie was made
            os.kill(os.getpid(), signal.SIGTERM)
    return tie


class _IoCounters(ctypes.Structure):
    _fields_ = [(name, ctypes.c_ulonglong) for name in (
        "ReadOperationCount", "WriteOperationCount", "OtherOperationCount",
        "ReadTransferCount", "WriteTransferCount", "OtherTransferCount")]


class _BasicLimits(ctypes.Structure):
    _fields_ = [("PerProcessUserTimeLimit", ctypes.c_int64), ("PerJobUserTimeLimit", ctypes.c_int64),
                ("LimitFlags", ctypes.c_uint32), ("MinimumWorkingSetSize", ctypes.c_size_t),
                ("MaximumWorkingSetSize", ctypes.c_size_t), ("ActiveProcessLimit", ctypes.c_uint32),
                ("Affinity", ctypes.c_size_t), ("PriorityClass", ctypes.c_uint32),
                ("SchedulingClass", ctypes.c_uint32)]


class _ExtendedLimits(ctypes.Structure):
    _fields_ = [("BasicLimitInformation", _BasicLimits), ("IoInfo", _IoCounters),
                ("ProcessMemoryLimit", ctypes.c_size_t), ("JobMemoryLimit", ctypes.c_size_t),
                ("PeakProcessMemoryUsed", ctypes.c_size_t), ("PeakJobMemoryUsed", ctypes.c_size_t)]


def _windows_job(proc):
    """A job that kills `proc` once Senada is gone; the handle must be kept open."""
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.CreateJobObjectW.restype = ctypes.c_void_p
    kernel32.CreateJobObjectW.argtypes = [ctypes.c_void_p, ctypes.c_wchar_p]
    kernel32.SetInformationJobObject.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p, ctypes.c_uint32]
    kernel32.AssignProcessToJobObject.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
    kernel32.CloseHandle.argtypes = [ctypes.c_void_p]
    job = kernel32.CreateJobObjectW(None, None)
    if not job:
        return None
    info = _ExtendedLimits()
    info.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
    ok = kernel32.SetInformationJobObject(job, JOB_OBJECT_EXTENDED_LIMIT_INFORMATION,
                                          ctypes.byref(info), ctypes.sizeof(info))
    if ok and kernel32.AssignProcessToJobObject(job, int(proc._handle)):
        return job
    kernel32.CloseHandle(job)
    return None


def popen_tied(cmd, **kwargs):
    """subprocess.Popen(cmd, **kwargs) for a child that must not outlive Senada.
    Returns (process, keep): hold on to `keep` as long as the process runs (Windows job)."""
    if sys.platform.startswith("linux"):
        tie = _linux_preexec()
        if tie:
            kwargs["preexec_fn"] = tie
    proc = subprocess.Popen(cmd, **kwargs)
    keep = None
    if sys.platform == "win32":
        try:
            keep = _windows_job(proc)
        except (OSError, AttributeError, ValueError):
            keep = None
    return proc, keep
