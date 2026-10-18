#!/bin/bash
# Runs inside the container: install OCS, bring the daemons up, build the DRMAA
# client and sweep SGE_JAPI_EDTIME against a set of reporting flush_time values.
#
# Two things are being checked, and they are independent:
#
#   1. Which (flush_time, SGE_JAPI_EDTIME) pairs drmaa_init() rejects with
#      "event flush delay may not be greater than event delivery time".
#   2. How long drmaa_wait() takes to report a finished job in the pairs that
#      are accepted.
#
# Everything printed on stdout is the raw record of the run; the host side only
# tabulates it.

set -u

SGE_ROOT=/opt/ocs
ITERATIONS="${ITERATIONS:-3}"
EDTIMES="${EDTIMES:-unset 1 2 4 5 6 10 15 16 30}"
FLUSH_TIMES="${FLUSH_TIMES:-00:00:01 00:00:05 00:00:15}"

echo "### version: ${OCS_VERSION}"
echo "### date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Sources come in on a bind mount so the harness can be edited without
# rebuilding the image.
cp /repro/drmaa_latency.c /repro/jobscript.sh /root/
chmod +x /root/jobscript.sh

# ---------------------------------------------------------------- install ----
if [ ! -d "$SGE_ROOT/default/common" ]; then
    echo "### installing OCS ${OCS_VERSION}"
    sh /tmp/ocs.sh > /tmp/install.log 2>&1 || {
        echo "### INSTALL FAILED"
        tail -40 /tmp/install.log
        exit 1
    }
    echo "### install done"
fi

# settings.sh appends to MANPATH without a default, which trips nounset.
set +u
. "$SGE_ROOT/default/common/settings.sh"
set -u
ARCH="$($SGE_ROOT/util/arch)"
export LD_LIBRARY_PATH="$SGE_ROOT/lib/$ARCH${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

pgrep -x sge_qmaster > /dev/null || "$SGE_ROOT/default/common/sgemaster" start
pgrep -x sge_execd   > /dev/null || "$SGE_ROOT/default/common/sgeexecd" start

# Wait for a usable queue instance rather than a fixed sleep, so a slow start
# does not silently turn into a run full of queued jobs.
for _ in $(seq 60); do
    qstat -f 2>/dev/null | grep -q "all.q@" && break
    sleep 1
done

echo "### install default reporting_params: $(qconf -sconf | grep -A1 '^reporting_params' | tr -d '\\\\\n' | tr -s ' ')"
echo "### libdrmaa: $(ls -l "$SGE_ROOT/lib/$ARCH/libdrmaa.so" | awk '{print $5}') bytes"

# ------------------------------------------------------------------ build ----
gcc -O2 -o /root/drmaa_latency /root/drmaa_latency.c \
    -I"$SGE_ROOT/include" -L"$SGE_ROOT/lib/$ARCH" -ldrmaa -lpthread || {
    echo "### COMPILE FAILED"
    exit 1
}
mkdir -p /root/stamps

# qconf -mconf wants an editor; hand it a script that rewrites the one line we
# care about. This is the standard way to drive qconf non-interactively.
cat > /root/set_flush.sh <<'EOS'
#!/bin/sh
sed -i "s|^reporting_params .*|reporting_params              accounting=true reporting=false flush_time=${NEW_FLUSH_TIME} joblog=false sharelog=00:00:00|" "$1"
EOS
chmod +x /root/set_flush.sh

# ------------------------------------------------------------------- sweep ---
for flush in $FLUSH_TIMES; do
    NEW_FLUSH_TIME="$flush" EDITOR=/root/set_flush.sh qconf -mconf > /dev/null 2>&1
    confirmed="$(qconf -sconf | grep -A1 '^reporting_params' | tr -d '\\\n' | tr -s ' ' | grep -o 'flush_time=[0-9:]*')"
    echo "### flush_time requested=$flush confirmed=$confirmed"

    for ed in $EDTIMES; do
        if [ "$ed" = "unset" ]; then
            unset SGE_JAPI_EDTIME
        else
            export SGE_JAPI_EDTIME="$ed"
        fi

        out="$(/root/drmaa_latency "$ITERATIONS" /root/jobscript.sh /root/stamps 2>/tmp/err.log)"
        if echo "$out" | grep -q INITFAIL; then
            echo "MEASURE|${OCS_VERSION}|${flush}|${ed}|INITFAIL|$(echo "$out" | head -1 | cut -f3-)"
        elif [ -z "$out" ]; then
            echo "MEASURE|${OCS_VERSION}|${flush}|${ed}|ERROR|$(tail -2 /tmp/err.log | tr '\n' ' ')"
        else
            echo "$out" | while IFS=$'\t' read -r _tag iter jid s2w e2w rc; do
                echo "MEASURE|${OCS_VERSION}|${flush}|${ed}|OK|${iter}|${s2w}|${e2w}|${rc}"
            done
        fi
    done
done

echo "### sweep complete"
