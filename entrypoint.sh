#!/usr/bin/env sh
# vim:sw=4:ts=4:et:
#
# This script launches nginx and the NGINX Amplify Agent.
#
# Unless already baked in the image, a real API_KEY is required for the
# NGINX Amplify Agent to be able to connect to the backend.
#
# If AMPLIFY_IMAGENAME is set, the script will use it to generate
# the 'imagename' to put in the /etc/amplify-agent/agent.conf
#
# If several instances use the same imagename, the metrics will
# be aggregated into a single object in Amplify. Otherwise NGINX Amplify
# will create separate objects for monitoring (an object per instance).
#

agent_conf_file="/etc/amplify-agent/agent.conf"
nginx_status_conf="/etc/nginx/conf.d/stub_status.conf"

agent_pid=0
nginx_pid=0

_stop() {
    echo "=== stopping by $1" >&2
    if [ $agent_pid -ne 0 ]; then
        echo "=== stopping agent" >&2
        kill -TERM $agent_pid
        wait "$agent_pid"
    fi
    if [ $nginx_pid -ne 0 ]; then
        echo "=== stopping nginx" >&2
        kill -QUIT $nginx_pid
        wait "$nginx_pid"
    fi
    exit 0
}

for sig in TERM INT QUIT HUP; do
    trap "kill \${!}; _stop $sig" $sig
done

echo "=== starting nginx" >&2
/usr/sbin/nginx -c /etc/nginx/nginx.conf -g 'daemon off;' &
nginx_pid="$!"

if [ ! -f "${agent_conf_file}" ]; then
    if [ -f "${agent_conf_file}.default" ]; then
        cp -p "${agent_conf_file}.default" "${agent_conf_file}"
    else
        echo "no ${agent_conf_file}.default found! exiting." >&2
        exit 1
    fi
fi

if [ -n "${API_KEY}" ]; then
    echo "=== using api_key=${API_KEY}" >&2
    sed -i.old -e "s,api_key.*$,api_key = $API_KEY," ${agent_conf_file}
fi

if [ -n "${API_URL}" ]; then
    echo "=== using api_url=${API_URL}" >&2
    sed -i.old -e "s,api_url.*$,api_url = $API_URL," ${agent_conf_file}
fi

if [ -n "${AMPLIFY_IMAGENAME}" ]; then
    echo "=== using imagename=${AMPLIFY_IMAGENAME}" >&2
    sed -i.old -e "s,imagename.*$,imagename = $AMPLIFY_IMAGENAME," \
        ${agent_conf_file}
fi

if [ -n "${AMPLIFY_LOGLEVEL}" ]; then
    echo "=== using loglevel=${AMPLIFY_LOGLEVEL}" >&2
    sed -i.old -e "s,level =.*$,level = $AMPLIFY_LOGLEVEL," \
        ${agent_conf_file}
fi

test -f "${agent_conf_file}" && \
chmod 644 ${agent_conf_file} && \
chown nginx ${agent_conf_file} > /dev/null 2>&1

test -f "${nginx_status_conf}" && \
chmod 644 ${nginx_status_conf} && \
chown nginx ${nginx_status_conf} > /dev/null 2>&1

echo "=== starting amplify-agent" >&2
/usr/bin/nginx-amplify-agent.py start --foreground --config /etc/amplify-agent/agent.conf --log /dev/stdout &
agent_pid="$!"

while [ :: ]; do
    sleep 60 & wait ${!}
done
