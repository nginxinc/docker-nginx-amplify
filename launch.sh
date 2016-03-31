#!/bin/sh
#
# This script launches nginx and the Amplify Agent.
#
# Unless already baked in the image, a real API_KEY is required for the
# Amplify Agent to be able to connect to the backend.
#
# If AMPLIFY_HOSTNAME is set, the script will use it to generate
# the 'hostname' to put in the /etc/amplify-agent/agent.conf
# If several instances use the same hostname, the metrics will
# be aggregated into a single object in Amplify. Otherwise Amplify
# will create separate objects for monitoring (an object per instance).
#

# Variables
agent_conf_file="/etc/amplify-agent/agent.conf"
api_key=""
amplify_hostname=""

# Launch nginx
echo "starting nginx.."
nginx -g "daemon off;" &

# Check for an older version of the agent running
if command -V pgrep > /dev/null 2>&1; then
    agent_pid=`pgrep amplify-agent`
else
    agent_pid=`ps aux | grep -i '[a]mplify-agent' | awk '{print $2}'`
fi

if [ -n "$agent_pid" ]; then
    echo "stopping old amplify-agent, pid ${agent_pid}"
    service amplify-agent stop > /dev/null 2>&1 < /dev/null
fi

test -n "${API_KEY}" && \
    api_key=${API_KEY}

test -n "${AMPLIFY_HOSTNAME}" && \
    amplify_hostname=${AMPLIFY_HOSTNAME}

if [ -n "${api_key}" -o -n "${amplify_hostname}" ]; then
    echo "updating ${agent_conf_file} .."

    if [ ! -f "${agent_conf_file}" ]; then
	test -f "${agent_conf_file}.default" && \
	cp -p "${agent_conf_file}.default" "${agent_conf_file}" || \
	{ echo "no ${agent_conf_file}.default found! exiting."; exit 1; }
    fi

    test -n "${api_key}" && \
    echo " ---> using api_key = ${api_key}" && \
    sh -c "sed -i.old -e 's/api_key.*$/api_key = $api_key/' \
	${agent_conf_file}"

    test -n "${amplify_hostname}" && \
    echo " ---> using hostname = ${amplify_hostname}" && \
    sh -c "sed -i.old -e 's/hostname.*$/hostname = $amplify_hostname/' \
	${agent_conf_file}"

    test -f "${agent_conf_file}" && \
    chmod 644 ${agent_conf_file} && \
    chown nginx ${agent_conf_file} > /dev/null 2>&1
fi

echo "starting amplify-agent.."
service amplify-agent start > /dev/null 2>&1 < /dev/null

echo "watching nginx master process.."
while ps axu | grep -i 'nginx[:] master' > /dev/null 2>&1; do
    sleep 60;
done

echo "no running nginx master process found, exiting."

exit 0
