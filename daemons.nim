## This library makes your code run as a daemon process on Unix-like systems.
import os except sleep

when defined(nimdoc):
    proc daemonize*(pidfile: string = ""): int =
        ## Daemonize process, and stored process identifier in `pidfile`.
        ## 
        ## Returns `0` if process is daemonized child, `>0`, if
        ## process is parent, and `<0` if there error happens.
    
when defined(posix):
    import posix

    var
        pid: Pid
        pidFileInner: string
        fi, fo, fe: File
        si, so, se: string = "/dev/null"
        cd: string = "/"

    proc c_signal(sig: cint, handler: proc (a: cint) {.noconv.}) {.importc: "signal", header: "<signal.h>".}

    proc onStop(sig: cint) {.noconv.} =
        close(fi)
        close(fo)
        close(fe)
        removeFile(pidFileInner)

        quit(QuitSuccess)

    template daemonize*(pidfile, body: typed): void =
        ## deamonizer
        ##
        ## pidfile: path to file where pid will be stored
        ## si: standard input for daemonzied process
        ## so: standard output for daemonzied process
        ## se: standard ouput for daemonzied process
        ## cd: directory to switch to, nil or empty to stay
        ## 
        if fileExists(pidfile):
            raise newException(IOError, "pidfile " & pidfile & " already exist, daemon already running?")


        pid = fork()
        if pid > 0:
            quit(QuitSuccess)

        if not cd.len == 0:
            discard chdir(cd)
        discard setsid()
        discard umask(0)

        pid = fork()
        if pid > 0:
            quit(QuitSuccess)

        flushFile(stdout)
        flushFile(stderr)

        if not si.len == 0:
            fi = open(si, fmRead)
            discard dup2(getFileHandle(fi), getFileHandle(stdin))

        if not so.len == 0:
            fo = open(so, fmAppend)
            discard dup2(getFileHandle(fo), getFileHandle(stdout))

        if not se.len == 0:
            fe = open(se, fmAppend)
            discard dup2(getFileHandle(fe), getFileHandle(stderr))

        pidFileInner = pidfile

        c_signal(SIGINT, onStop)
        c_signal(SIGTERM, onStop)
        c_signal(SIGHUP, onStop)
        c_signal(SIGQUIT, onStop)

        pid = getpid()
        writeFile(pidfile, $pid)

        body

elif defined(windows):
    import winlean, os, strutils

    const
        DaemonEnvVariable = "NIM_DAEMONIZE"
        CREATE_NEW_PROCESS_GROUP = 0x00000200'i32
        DETACHED_PROCESS = 0x00000008'i32
  
    proc getEnvironmentVariableW(lpName, lpValue: WideCString, nSize: int32): int32 {.
        stdcall, dynlib: "kernel32", importc: "GetEnvironmentVariableW".}

    template daemonize*(pidfile: string, body: typed): void =
        var
            si: STARTUPINFO
            pi: PROCESS_INFORMATION
            sa: SECURITY_ATTRIBUTES
            evar: array[32, byte]
            res: int32

        var cmdLineW = getCommandLineW()
        res = getEnvironmentVariableW(newWideCString(DaemonEnvVariable), cast[WideCString](addr evar[0]), 16)
        if res > 0:
            quit(QuitSuccess)
        else:
            sa.nLength = int32(sizeof(SECURITY_ATTRIBUTES))
            sa.bInheritHandle = 1'i32
            var path = newWideCString("NUL")
            si.dwFlags = STARTF_USESTDHANDLES
            var handle = createFileW(path, GENERIC_WRITE or GENERIC_READ,
                               FILE_SHARE_READ or FILE_SHARE_WRITE, addr sa,
                               OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, Handle(0))

            if handle == INVALID_HANDLE_VALUE:
                raise newException(IOError, "Invalid handle")

            si.hStdInput = handle
            si.hStdOutput = handle
            si.hStdError = handle

            if setEnvironmentVariableW(newWideCString(DaemonEnvVariable),
                                        newWideCString("true")) == 0:
                raise newException(IOError, "Error setting environment variable")
            var flags = CREATE_NEW_PROCESS_GROUP or DETACHED_PROCESS or
                        CREATE_UNICODE_ENVIRONMENT
            res = winlean.createProcessW(nil, cmdLineW, nil, nil, 1, flags, nil,
                                        nil, si, pi)
            if res == 0:
                raise newException(IOError, "Create process failed")
            else:
                writeFile(pidfile, $pi.dwProcessId)

            body


when isMainModule:
    proc main() =
        var i = 0
        while true:
            i.inc()
            echo i
            discard sleep(1)
    when defined windows:
        daemonize(getTempDir() / "daemonize.pid"):
            main()
    elif defined posix:
        daemonize(getTempDir() / "daemonize.pid"):
            main()
