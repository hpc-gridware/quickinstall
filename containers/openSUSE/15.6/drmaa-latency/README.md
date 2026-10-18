# DRMAA `drmaa_wait()` latency reproducer

Built to check the report behind CS-2447: that OCS 9.1.4 introduced a new
`SGE_JAPI_EDTIME` validation in libdrmaa, that the threshold tracks the
qmaster's `reporting_params flush_time`, and that `drmaa_wait()` consequently
needs 17-50 seconds to report a finished job.

Each OCS version is installed into its own throwaway container (qmaster, execd
and the DRMAA client on one node), and a C client sweeps `SGE_JAPI_EDTIME`
against several `flush_time` values, timing every round trip.

## Running it

```bash
./download-packages.sh     # caches the tarballs into pkg/ (about 350 MB)
./run.sh                   # 9.1.2, 9.1.3, 9.1.4
./run.sh 9.1.4             # or a single version
```

Raw output goes to `results/<version>.log`, tabulated by `./summarize.sh`.
Download URLs are taken from the repository `ocs.sh`, so a version that
`ocs.sh` supports works here without further changes.

## What is measured

A job that only stamps its own end time and exits. The client records when
`drmaa_wait()` returns, so the two useful numbers are separated:

| Column | Meaning |
|---|---|
| `submit_to_wait` | `drmaa_run_job()` returning to `drmaa_wait()` returning |
| `jobend_to_wait` | the job writing its end stamp to `drmaa_wait()` returning - the event delivery latency proper |

Both timestamps come from the same container, so they share a clock.

## Results

162 accepted measurements per full run, three OCS versions, `flush_time` of 1 s,
5 s and 15 s, `SGE_JAPI_EDTIME` unset and 1, 2, 4, 5, 6, 10, 15, 16, 30.

**The validation reproduces exactly.** `SGE_JAPI_EDTIME=1` fails in
`drmaa_init()` with the quoted wording:

```
event flush delay may not be greater than event delivery time
```

**It is not new in 9.1.4.** 9.1.2 and 9.1.3 reject and accept exactly the same
values. `event_client_verify()`, the function that emits the message, is
instruction-for-instruction identical in all three libraries - 505
instructions, differing only in `.rodata` string offsets and one GOT slot.

**The threshold does not track `flush_time`.** It sits at `SGE_JAPI_EDTIME >= 6`
whether `flush_time` is 1 s, 5 s or 15 s. The check compares the event
delivery time against the event client's own flush delay (client field 1157),
which libdrmaa sets for itself; the qmaster's `reporting_params flush_time` is
a different setting and does not feed into it. A site whose `flush_time`
happens to be 5 s will read the fixed threshold as if it tracked that value.
Lowering `flush_time` therefore does not permit a lower `SGE_JAPI_EDTIME`.

**The latency does not reproduce.** Every accepted configuration returns in
about 0.88 s, flat:

| version | `flush_time` | `SGE_JAPI_EDTIME` | `jobend_to_wait` |
|---|---|---|---|
| 9.1.2 / 9.1.3 / 9.1.4 | 1 s / 5 s / 15 s | unset | ~0.88 s |
| 9.1.2 / 9.1.3 / 9.1.4 | 1 s / 5 s / 15 s | 1, 2, 4, 5 | rejected in `drmaa_init()` |
| 9.1.2 / 9.1.3 / 9.1.4 | 1 s / 5 s / 15 s | 6, 10, 15, 16, 30 | ~0.88 s |

Across all 162 accepted measurements: min 0.784 s, median 0.880 s, max 0.896 s.
There is no correlation with `SGE_JAPI_EDTIME`, so the reported
`wall = EDTIME + 11 s` relationship does not appear here at all.

## Scope

Single node, one container, arm64, idle cluster, no shadow master, classic
spooling, `SCHEDD_CONF=3`. This is enough to settle whether the validation and
the EDTIME/latency coupling are properties of libdrmaa itself - they are not.
It cannot rule out something specific to a loaded 12-node cluster with a shadow
master, which is where the report's numbers were taken.

## Files

| File | Purpose |
|---|---|
| `download-packages.sh` | caches tarballs into `pkg/`, URLs read from the repository `ocs.sh` |
| `run.sh` | one fresh container per version, results into `results/` |
| `in-container.sh` | installs OCS, starts the daemons, builds the client, runs the sweep |
| `drmaa_latency.c` | the DRMAA client that does the timing |
| `jobscript.sh` | the job: stamps its end time and exits |
| `summarize.sh` | tabulates `results/*.log` |
