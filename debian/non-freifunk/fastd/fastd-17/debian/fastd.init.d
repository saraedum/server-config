#!/bin/sh -e

### BEGIN INIT INFO
# Provides:          fastd
# Required-Start:    $network $remote_fs $syslog
# Required-Stop:     $network $remote_fs $syslog
# Should-Start:      network-manager
# Should-Stop:       network-manager
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Fast and Secure Tunneling Daemon
# Description: This script will start fastd tunnels as specified
#              in /etc/default/fastd and /etc/fastd/*/fastd.conf
### END INIT INFO

# Derived from the OpenVPN init script
# Original version by Robert Leslie
# <rob@mars.org>, edited by iwj and cs
# Modified for openvpn by Alberto Gonzalez Iniesta <agi@inittab.org>
# Modified for restarting / starting / stopping single tunnels by Richard Mueller <mueller@teamix.net>
# Modified for fastd by Nils Schneider <nils@nilsschneider.net>

. /lib/lsb/init-functions

test $DEBIAN_SCRIPT_DEBUG && set -v -x

DAEMON=/usr/bin/fastd
DESC="Fast and Secure Tunneling Daemon"
CONFIG_DIR=/etc/fastd
test -x $DAEMON || exit 0
test -d $CONFIG_DIR || exit 0

# Source defaults file; edit that file to configure this script.
AUTOSTART="all"
if test -e /etc/default/fastd ; then
  . /etc/default/fastd
fi

start_vpn () {
    STATUS=0
    start-stop-daemon --start --quiet --oknodo \
        --pidfile /var/run/fastd.$NAME.pid \
	--make-pidfile \
	--background \
        --exec $DAEMON -- \
          --syslog-level info \
          --config $CONFIG_DIR/$NAME/fastd.conf \
        || STATUS=1
}

stop_vpn () {
  kill `cat $PIDFILE` || true
  rm -f $PIDFILE
  log_end_msg 0
}

case "$1" in
start)
  log_action_begin_msg "Starting $DESC"

  # autostart fastds
  if test -z "$2" ; then
    # check if automatic startup is disabled by AUTOSTART=none
    if test "x$AUTOSTART" = "xnone" -o -z "$AUTOSTART" ; then
      log_warning_msg "  Autostart disabled, no fastd will be started."
      exit 0
    fi
    if test -z "$AUTOSTART" -o "x$AUTOSTART" = "xall" ; then
      # all fastds shall be started automatically
      for CONFIG in `cd $CONFIG_DIR; ls */fastd.conf 2> /dev/null`; do
        NAME=${CONFIG%%/fastd.conf}
        log_daemon_msg "  Autostarting fastd '$NAME'"
        start_vpn
      done
    else
      # start only specified fastds
      for NAME in $AUTOSTART ; do
        if test -e $CONFIG_DIR/$NAME/fastd.conf ; then
          log_daemon_msg "  Autostarting fastd '$NAME'"
          start_vpn
        else
          log_failure_msg "  Autostarting fastd '$NAME': missing $CONFIG_DIR/$NAME/fastd.conf file !"
          STATUS=1
        fi
      done
    fi
  #start fastds from command line
  else
    while shift ; do
      [ -z "$1" ] && break
      NAME=$1
      if test -e $CONFIG_DIR/$NAME/fastd.conf ; then
        log_daemon_msg "  Starting fastd '$NAME'"
        start_vpn
      else
        log_failure_msg "  Starting fastd '$NAME': missing $CONFIG_DIR/$NAME/fastd.conf file !"
       STATUS=1
      fi
    done
  fi
  log_end_msg ${STATUS:-0}
  ;;
stop)
  log_action_begin_msg "Stopping $DESC"
  if test -z "$2" ; then
    PIDFILE=
    for PIDFILE in `ls /var/run/fastd.*.pid 2> /dev/null`; do
      NAME=`echo $PIDFILE | cut -c16-`
      NAME=${NAME%%.pid}
      log_daemon_msg "  Stopping fastd '$NAME'"
      stop_vpn
    done
    if test -z "$PIDFILE" ; then
      log_warning_msg "  No fastd is running."
    fi
  else
    while shift ; do
      [ -z "$1" ] && break
      if test -e /var/run/fastd.$1.pid ; then
        log_daemon_msg "  Stopping fastd '$1'"
        PIDFILE=`ls /var/run/fastd.$1.pid 2> /dev/null`
        NAME=`echo $PIDFILE | cut -c16-`
        NAME=${NAME%%.pid}
        stop_vpn
      else
        log_failure_msg "  Stopping fastd '$1': No such fastd is running."
      fi
    done
  fi
  ;;
restart)
  shift
  $0 stop ${@}
  sleep 1
  $0 start ${@}
  ;;
status)
  GLOBAL_STATUS=0
  if test -z "$2" ; then
    # We want status for all defined fastd.
    # Returns success if all autostarted fastds are defined and running
    if test "x$AUTOSTART" = "xnone" ; then
      # Consider it a failure if AUTOSTART=none
      log_warning_msg "No fastds autostarted"
      GLOBAL_STATUS=1
    else
      if ! test -z "$AUTOSTART" -o "x$AUTOSTART" = "xall" ; then
        # Consider it a failure if one of the autostarted fastd is not defined
        for VPN in $AUTOSTART ; do
          if ! test -f $CONFIG_DIR/$VPN/fastd.conf ; then
            log_warning_msg "fastd '$VPN' is in AUTOSTART but is not defined"
            GLOBAL_STATUS=1
          fi
        done
      fi
    fi
    for CONFIG in `cd $CONFIG_DIR; ls */fastd.conf 2> /dev/null`; do
      NAME=${CONFIG%%/fastd.conf}
      # Is it an autostarted fastd?
      if test -z "$AUTOSTART" -o "x$AUTOSTART" = "xall" ; then
        AUTOVPN=1
      else
        if test "x$AUTOSTART" = "xnone" ; then
          AUTOVPN=0
        else
          AUTOVPN=0
          for VPN in $AUTOSTART; do
            if test "x$VPN" = "x$NAME" ; then
              AUTOVPN=1
            fi
          done
        fi
      fi
      if test "x$AUTOVPN" = "x1" ; then
        # If it is autostarted, then it contributes to global status
        status_of_proc -p /var/run/fastd.${NAME}.pid fastd "fastd '${NAME}'" || GLOBAL_STATUS=1
      else
        status_of_proc -p /var/run/fastd.${NAME}.pid fastd "fastd '${NAME}' (non autostarted)" || true
      fi
    done
  else
    # We just want status for specified fastd.
    # Returns success if all specified fastds are defined and running
    while shift ; do
      [ -z "$1" ] && break
      NAME=$1
      if test -e $CONFIG_DIR/$NAME.conf ; then
        # Config exists
        status_of_proc -p /var/run/fastd.${NAME}.pid fastd "fastd '${NAME}'" || GLOBAL_STATUS=1
      else
        # Config does not exist
        log_warning_msg "fastd '$NAME': missing $CONFIG_DIR/$NAME.conf file !"
        GLOBAL_STATUS=1
      fi
    done
  fi
  exit $GLOBAL_STATUS
  ;;
*)
  echo "Usage: $0 {start|stop|reload|restart|force-reload|cond-restart|soft-restart|status}" >&2
  exit 1
  ;;
esac

exit 0

# vim:set ai sts=2 sw=2 tw=0:
