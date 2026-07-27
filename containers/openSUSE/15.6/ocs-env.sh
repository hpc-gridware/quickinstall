# Open Cluster Scheduler shell environment.
#
# Installed as /etc/profile.d/ocs.sh (read by login and ssh shells) and also
# sourced from the .bashrc of root and gridware: openSUSE does not read
# /etc/profile.d for the interactive non-login shell that
# "docker exec -it ocs-master bash" creates, so both paths are needed.
#
# Sourcing settings.sh must stay silent - OCS runs remote commands over ssh
# and any output on stdout breaks them. Only the banner prints, and only for
# interactive shells.

if [ -z "$SGE_ROOT" ] && [ -f /opt/ocs/default/common/settings.sh ]; then
    . /opt/ocs/default/common/settings.sh
fi

# Print the banner once per shell (this file can be read twice: via
# /etc/profile.d and again via ~/.bashrc).
if [ -z "$_ocs_banner_shown" ] && [ -f /etc/ocs-banner.sh ]; then
    case $- in
        *i*)
            _ocs_banner_shown=1
            . /etc/ocs-banner.sh
            ;;
    esac
fi
