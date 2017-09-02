#!/bin/sh
#
# Copyright (c) 2006 Eric Wong
#

PERL='@@PERL@@'
SHELL_PATH='@SHELL_PATH@'
OPTIONS_KEEPDASHDASH=
OPTIONS_STUCKLONG=
OPTIONS_SPEC="\
git instaweb [options] (--start | --stop | --restart)
--
l,local        only bind on 127.0.0.1
p,port=        the port to bind to
d,httpd=       the command to launch
b,browser=     the browser to launch
m,module-path= the module path (only needed for apache2)
 Action
stop           stop the web server
start          start the web server
restart        restart the web server
"

SUBDIRECTORY_OK=Yes
. git-sh-setup

fqgitdir="$GIT_DIR"
local="$(git config --bool --get instaweb.local)"
httpd="$(git config --get instaweb.httpd)"
root="$(git config --get instaweb.gitwebdir)"
port=$(git config --get instaweb.port)
module_path="$(git config --get instaweb.modulepath)"
action="browse"

conf="$GIT_DIR/gitweb/httpd.conf"

# Defaults:

# if installed, it doesn't need further configuration (module_path)
test -z "$httpd" && httpd='lighttpd -f'

# Default is @@GITWEBDIR@@
test -z "$root" && root='@@GITWEBDIR@@'

# any untaken local port will do...
test -z "$port" && port=1234

setup_httpd() {
	# First do the cheap check of whether $httpd is a basic name.
	if test -f "$httpdsdir/$httpd"
	then
		. "$httpdsdir/$httpd"
		return
	fi
	# Now we have to look in all of the files to see if they handle the
	# specified httpd.
	for f in "$httpdsdir"/*
	do
		( . "$f" ; handles_httpd "$httpd" "$f" )
		if test $? = 0
		then
			. "$f"
			return
		fi
	done
	echo "Unknown httpd specified: $httpd"
	exit 1
}

while test $# != 0
do
	case "$1" in
	--stop|stop)
		action="stop"
		;;
	--start|start)
		action="start"
		;;
	--restart|restart)
		action="restart"
		;;
	-l|--local)
		local=true
		;;
	-d|--httpd)
		shift
		httpd="$1"
		;;
	-b|--browser)
		shift
		browser="$1"
		;;
	-p|--port)
		shift
		port="$1"
		;;
	-m|--module-path)
		shift
		module_path="$1"
		;;
	--)
		;;
	*)
		usage
		;;
	esac
	shift
done

mkdir -p "$GIT_DIR/gitweb/tmp"
GIT_EXEC_PATH="$(git --exec-path)"
GIT_DIR="$fqgitdir"
GITWEB_CONFIG="$fqgitdir/gitweb/gitweb_config.perl"
export GIT_EXEC_PATH GIT_DIR GITWEB_CONFIG

httpdsdir=$(git --exec-path)/httpds
. "$httpdsdir/defaults"
setup_httpd

case "$action" in
stop)
	stop_httpd
	exit 0
	;;
start)
	start_httpd
	exit 0
	;;
restart)
	stop_httpd
	start_httpd
	exit 0
	;;
esac

gitweb_conf

resolve_full_httpd
mkdir -p "$fqgitdir/gitweb/$httpd_only"
conf="$fqgitdir/gitweb/$httpd_only.conf"

configure_httpd

start_httpd
url=http://127.0.0.1:$port

if test -n "$browser"; then
	httpd_is_ready && git web--browse -b "$browser" $url || echo $url
else
	httpd_is_ready && git web--browse -c "instaweb.browser" $url || echo $url
fi
