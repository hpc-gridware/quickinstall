#!/bin/bash
# Tabulate results/*.log into one matrix: median jobend_to_wait per
# (version, flush_time, SGE_JAPI_EDTIME), or the rejection reason.

cd "$(dirname "$0")"

awk -F'|' '
$1 == "MEASURE" {
    key = $2 "|" $3 "|" $4
    if (!(key in seen)) { order[++n] = key; seen[key] = 1 }
    if ($5 == "OK") {
        vals[key] = vals[key] " " $8
        status[key] = "ok"
    } else {
        status[key] = $5
        note[key] = $6
    }
}
END {
    printf "%-8s %-10s %-8s %-10s %s\n", "version", "flush", "EDTIME", "status", "jobend_to_wait (s)"
    printf "%-8s %-10s %-8s %-10s %s\n", "-------", "-----", "------", "------", "------------------"
    for (i = 1; i <= n; i++) {
        k = order[i]
        split(k, p, "|")
        if (status[k] == "ok") {
            printf "%-8s %-10s %-8s %-10s %s\n", p[1], p[2], p[3], "ok", vals[k]
        } else {
            printf "%-8s %-10s %-8s %-10s %s\n", p[1], p[2], p[3], status[k], note[k]
        }
    }
}' results/*.log
