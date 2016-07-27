FROM nginx:latest
MAINTAINER NGINX Amplify Engineering

# Install the NGINX Amplify Agent
RUN apt-get update \
    && apt-get install -qqy curl python apt-transport-https apt-utils \
    && echo 'deb https://packages.amplify.nginx.com/debian/ jessie amplify-agent' > /etc/apt/sources.list.d/nginx-amplify.list \
    && curl -fs https://nginx.org/keys/nginx_signing.key | apt-key add - > /dev/null 2>&1 \
    && apt-get update \
    && apt-get install -qqy nginx-amplify-agent \
    && apt-get purge -qqy curl apt-transport-https apt-utils \
    && rm -rf /var/lib/apt/lists/*

# Copy nginx stub_status config
COPY ./conf.d/stub_status.conf /etc/nginx/conf.d

# API_KEY is required for configuration  the NGINX Amplify Agent.
# It could be your real API key for Amplify here if you wanted to build
# your own image to host in a private registry. However, including
# private keys is not recommended. Rather, providing sensitive keys
# as environment variables at runtime as described below.

#ENV API_KEY 1234567890

# If AMPLIFY_HOSTNAME is set, the startup wrapper script will use it to
# generate the 'imagename' to put in the /etc/amplify-agent/agent.conf
# If several instances use the same imagename, the metrics will
# be aggregated into a single object in Amplify. Otherwise Amplify
# will create separate objects for monitoring (an object per instance).
# AMPLIFY_HOSTNAME can also be passed to the instance at runtime as
# described below.

#ENV AMPLIFY_HOSTNAME my-docker-instance-123

# The /entrypoint.sh script will launch nginx and the Amplify Agent.
# The script honors API_KEY and AMPLIFY_HOSTNAME environment
# variables, and updates /etc/amplify-agent/agent.conf accordingly.

COPY ./launch.sh /entrypoint.sh

# TO set/override API_KEY and AMPLIFY_HOSTNAME when starting an instance:
# docker run --name my-nginx1 -e API_KEY='..effc' -e AMPLIFY_HOSTNAME="service-name" -d nginx-amplify

ENTRYPOINT ["/entrypoint.sh"]
