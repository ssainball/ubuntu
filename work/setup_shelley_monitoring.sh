#!/bin/bash
#---------------------------------------------------------------------
# File:    setup_shelley_monitoring.sh
# Created: 2019/10/17
# Creator: ilap
#=====================================================================
# DESCRIPTION:
#
# This script downloads and configures the required files 
# for monitoring a Shelley node by using grafana/prometheus.
#

clean_up () {
    echo "Cleaning up...." >&2
    rm -rf "${TMP_DIR}"
    RES=$1
    exit ${RES:=127}
}

message() {
    echo -e "$*" >&2
    exit 127
}

get_idx () {
    case $OSTYPE in
        "darwin"*)
            IDX=0
        ;;
        "linux-gnu"*)
            if [[ $HOSTTYPE == *"x86_64"* ]]; then
                IDX=1
            elif [[ $HOSTTYPE == *"arm"* ]]; then
                IDX=2
            else
                message "The $HOSTTYPE  is not supported"
            fi
        ;;
        *)
            message "The \"$OSTYPE\" OS is not supported"
        ;;
    esac
    echo $IDX
}

dl() {
    DL_URL="${1}"
    OUTPUT="${TMP_DIR}/`basename \"${DL_URL}\"`"
    shift
    
    TO_DIR="${@}"
    
    case ${DL} in
        *"wget"*)
        wget --no-check-certificate --output-document="${OUTPUT}" "${DL_URL}";;
        *)
        ( cd ${TMP_DIR} && curl -JOL "${DL_URL}" --silent );;
    esac
}

#### MAIN
if [ -z "$1" ] ; then
    message "usage: `basename $0` <project path> # e.g. ... ./Shelley"
fi

PROJ_DIR="`pwd`/${1}"
PROJ_NAME="`basename ${1}`"

export TMP_DIR=`mktemp -d "/tmp/${PROJ_NAME}.XXXXXXXX"`

CURL=`which curl`
WGET=`which wget`
JCLI=`which jcli`
DL=${CURL:=$WGET}

if  [ -z "$DL" -o -z "`which pip3`" -o -z "$JCLI" ]; then
    message 'You need to have 'wget' or 'curl', 'jcli' and 'pip3' to be installed\nand accessable by PATH environment to continue...\nExiting.'
fi

# Obtain parameters.
IP=127.0.0.1
PORT=3301
export IP PORT

while :
do
    
    read -p "What is the ip of the node (default:${IP})? " ip
    read -p "What is the port of the REST api of the node running on ${IP:="${ip}"}'s (default: ${PORT})? " port
    echo "Is this correct? http://${ip:-"${IP}"}:${port:-"${PORT}"}"
    read -p "Do you want to continue? [Y/n/q] " answer
    
    case ${answer:="Y"} in
        [yY]*)
            IP=${ip:-"${IP}"}
            PORT=${port:-"${PORT}"}
            break;;
        [nN]* )
            continue;;
        [qQ]* )
            exit;;
        * )
            echo "Please enter [yY](es), [nN](o) or [qQ](quit).";;
    esac
done

ARCHS=("darwin-amd64" "linux-amd64"  "linux-armv6")
IDX=`get_idx`

PROM_VER=2.13.0
PROM_URL="https://github.com/prometheus/prometheus/releases/download/v${PROM_VER}/prometheus-${PROM_VER}.${ARCHS[IDX]}.tar.gz"

GRAF_VER=6.4.3
GRAF_URL="https://dl.grafana.com/oss/release/grafana-${GRAF_VER}.${ARCHS[IDX]}.tar.gz"

NIX_URL="https://raw.githubusercontent.com/input-output-hk/jormungandr-nix/master/nixos/jormungandr-monitor"

MON_PY="monitor.py"
GRAF_DB="grafana.json"

trap clean_up  SIGHUP SIGINT SIGQUIT SIGTRAP SIGABRT SIGTERM

echo -e "Downloading prometheus..." >&2
dl $PROM_URL

echo -e "Downloading grafana..." >&2
dl $GRAF_URL

echo -e "Downloading jormungandr monitoring scripts for prometheus" >&2
dl ${NIX_URL}/$MON_PY
dl ${NIX_URL}/$GRAF_DB

cd ${TMP_DIR} && mkdir -p "${PROJ_DIR}"/{exporters,prometheus,grafana}

PROM_DIR="${PROJ_DIR}/prometheus"
GRAF_DIR="${PROJ_DIR}/grafana"
tar zxC "${PROM_DIR}" -f *prome*gz --strip-components 1
tar zxC "${GRAF_DIR}" -f *graf*gz --strip-components 1

echo -e "Configuring components" >&2
cp -pr ${MON_PY} "${PROJ_DIR}"/exporters && chmod +x "${PROJ_DIR}"/exporters/*
cp -pr ${GRAF_DB} "${PROJ_DIR}"/
sed -i -e 's#@jcli@#'"$JCLI"'#g' "${PROJ_DIR}"/exporters/${MON_PY}
sed -i -e 's@\(/usr/bin/env python\)@\13@' "${PROJ_DIR}"/exporters/${MON_PY}
pip3 install ipython python-dateutil prometheus_client >/dev/null

cd ${PROJ_DIR}

EXPORTER_IP=localhost
EXPORTER_PORT=9100
sed -i -e 's@\(^scrape_configs:.*\)@\1\
  - job_name: '\''jormungandr'\''\
    static_configs:\
    - targets: ['\'${EXPORTER_IP}:${EXPORTER_PORT}\'']@g'  "${PROM_DIR}"/prometheus.yml

cat > start_all.sh <<EOF
#!/bin/bash

	#1. exporter
	PORT=${EXPORTER_PORT}
	JORMUNGANDR_API="http://${IP}:${PORT}/api"
	# Addresses to monitor e.g.
	# ADDRESSES="ta1..... ta1..... ta1...."
	ADDRESSES=""
	export PORT JORMUNGANDR_API ADDRESSES
	"${PROJ_DIR}"/exporters/monitor.py &
	sleep 3

	#2. Prometheus
	"${PROM_DIR}"/prometheus --config.file="${PROM_DIR}"/prometheus.yml &
	sleep 3

	#3. Grafana
	#vi conf/defaults.ini
	cd "${GRAF_DIR}"
	./bin/grafana-server web
EOF

chmod a+rx start_all.sh

echo -e "Installation completed

You need to do the following to configure grafana:
0. Start the required services by \"./${PROJ_NAME}/start_all.sh\"
  - Keep in mind this startup script is very simple and has limited capabilities
  - check the monitor script (http://${EXPORTER_IP}:${EXPORTER_PORT})
1. Login to grafana as admin/admin (http://localhost:3000)
2. Add "prometheus" (all lowercase) datasource (http://localhost:9090)
3. Create a new dashboard by importing 'grafana.json' (left plus sign).

Enjoy...
" >&2

clean_up 0
