#!/bin/bash
# Copyright (C) 2024 Gridware GmbH
# Preflight check: detect 10.100.0.0/16 subnet collisions on the host
# before running 'docker compose up'. The cluster network defined in
# docker-compose.yml will fail or route traffic incorrectly if the host
# already uses that range (e.g. VPN, corporate LAN, other docker networks).

set -e

SUBNET_PREFIX="10.100."
CLUSTER_NET_NAME="ocs-cluster"
conflict=0

echo "Preflight: checking for ${SUBNET_PREFIX}0.0/16 conflicts..."

# 1) Host routing table
routes=""
if command -v ip >/dev/null 2>&1; then
    routes=$(ip route 2>/dev/null | grep "${SUBNET_PREFIX}" || true)
elif command -v netstat >/dev/null 2>&1; then
    routes=$(netstat -rn 2>/dev/null | grep "${SUBNET_PREFIX}" || true)
else
    echo "  (skipped host route check: neither 'ip' nor 'netstat' available)"
fi

if [ -n "$routes" ]; then
    echo "WARNING: host routing table contains route(s) in ${SUBNET_PREFIX}0.0/16:"
    echo "$routes" | sed 's/^/  /'
    conflict=1
fi

# 2) Existing docker networks (excluding our own to avoid false positives on re-runs)
if command -v docker >/dev/null 2>&1; then
    overlapping=""
    while IFS= read -r net; do
        [ -z "$net" ] && continue
        case "$net" in
            *"${CLUSTER_NET_NAME}"*) continue ;;
        esac
        subnets=$(docker network inspect "$net" \
            --format '{{range .IPAM.Config}}{{.Subnet}} {{end}}' 2>/dev/null || true)
        if echo "$subnets" | grep -q "${SUBNET_PREFIX}"; then
            overlapping="${overlapping}${net}: ${subnets}\n"
        fi
    done < <(docker network ls --format '{{.Name}}' 2>/dev/null)

    if [ -n "$overlapping" ]; then
        echo "WARNING: existing docker network(s) use ${SUBNET_PREFIX}x.x:"
        printf "%b" "$overlapping" | sed 's/^/  /'
        conflict=1
    fi
else
    echo "  (skipped docker network check: docker not on PATH)"
fi

if [ "$conflict" -eq 1 ]; then
    echo ""
    echo "Resolve the conflict(s) above, or change the subnet in docker-compose.yml"
    echo "(networks.ocs-cluster.ipam.config.subnet) before running 'docker compose up'."
    exit 1
fi

echo "OK: no ${SUBNET_PREFIX}0.0/16 conflicts detected."
