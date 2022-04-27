# nim-daemons
Two merged nim libraries to daemonize a nim application on Windows and Posix systems. 

#### Install
```
nimble install https://github.com/af001/nim-daemons
```

#### Usage
```
when defined linux:
    let pidfile = getTempDir() / ".daemonized.pid"
    daemonize(pidfile):
        main()
elif defined windows:
    let pidfile = getTempDir() / "daemonized.pid"
    daemonize(pidfile):
        main()
```


#### References
This repo contains a combination of code from two projects. The windows daemon portion was obtained from nim-daemon, and the posix portion from nim-daemonize. 

[nim-daemon](https://github.com/status-im/nim-daemon/blob/master/daemon.nim)  
[nim-daemonize](https://github.com/OpenSystemsLab/daemonize.nim)
