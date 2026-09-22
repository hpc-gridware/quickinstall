# Welcome banner for interactive shells in the OCS containers.
# Sourced from /etc/profile.d/ocs.sh, which guarantees an interactive shell.
# Suppressed by ~/.hushlogin, like a normal login banner.

if [ ! -f "$HOME/.hushlogin" ]; then
    echo
    echo "  Open Cluster Scheduler on $(hostname)"
    if [ -n "$SGE_ROOT" ]; then
        echo "  Environment loaded from /opt/ocs/default/common/settings.sh"
    else
        echo "  NOT installed yet - follow: docker compose logs -f ocs-master"
    fi
    echo "  ----------------------------------------------------------------"
    echo "  qhost                     execution hosts and their load"
    echo "  qstat -f                  queues, running and pending jobs"
    echo "  echo 'sleep 60' | qsub    submit a job (or: qsub -b y sleep 60)"
    echo "  qrsh -l h=<hostname>      interactive job on a specific host"
    echo "  qdel <job-id>             remove a job"
    echo "  qacct -j <job-id>         accounting of a finished job"
    echo "  qconf -sel                list execution hosts"
    echo "  qconf -sq all.q           show the default queue"
    echo "  man qsub                  manual pages"

    if [ "$(id -u)" = "0" ] && id -u gridware >/dev/null 2>&1; then
        echo "  ----------------------------------------------------------------"
        echo "  You are root (cluster manager). Jobs are meant to be submitted"
        echo "  as the unprivileged user gridware (uid 1000, sudo, home shared"
        echo "  across all nodes):"
        echo "      su - gridware"
        echo "      docker exec -it -u gridware $(hostname) bash   # from the host"
    fi

    echo "  ----------------------------------------------------------------"
    echo "  hide this banner: touch ~/.hushlogin"
    echo
fi
