#!/usr/bin/env bash

ps -eo pid=,ppid=,pcpu=,rss=,comm= |\
awk '
function getroot(pid,    parentpid) {
    parentpid = parent[pid]
    while ((parentpid in cmd) && parentpid > 1) {
        pid = parentpid
        parentpid = parent[pid]
    }
    return pid
}
{
    pid = $1
    parent[pid] = $2
    cpu[pid] = $3 + 0
    rss[pid] = $4 + 0
    cmd[pid] = $5
}
END {
    for (pid in cmd) {
        root = getroot(pid)
        totalcpu[root] += cpu[pid]
        totalrss[root] += rss[pid]
    }
    for (pid in cmd) {
        if (getroot(pid) == pid) {
            printf "CPU %.1f MEM %.1f CMD %s\n", totalcpu[pid], totalrss[pid] / 1024, cmd[pid]
        }
    }
}' | sort -r -s -n -k 4 | head -5
