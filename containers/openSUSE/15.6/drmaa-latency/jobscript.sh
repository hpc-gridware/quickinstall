#!/bin/sh
# Stamp the job end time and exit. The job does no work on purpose: what is
# being measured is the delay between a job finishing and drmaa_wait()
# noticing, so any runtime of our own would only add noise.
date +%s.%N > "$1"
exit 0
