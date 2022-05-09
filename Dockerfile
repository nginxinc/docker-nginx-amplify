FROM nginx:mainline
LABEL org.opencontainers.image.authors="NGINX Amplify Engineering"

# Install the NGINX Amplify Agent
RUN apt-get update \
    && apt-get install -qqy curl python apt-transport-https apt-utils gnupg1 procps lsb-release \
    && codename=`lsb_release -cs` \
    && os=`lsb_release -is | tr '[:upper:]' '[:lower:]'` \
    && echo "deb http://packages.amplify.nginx.com/py3/${os}/ ${codename} amplify-agent" > \
    /etc/apt/sources.list.d/nginx-amplify.list \
    && curl -fs https://nginx.org/keys/nginx_signing.key | apt-key add - > /dev/null 2>&1 \
    && apt-get update \
    && apt-get install -qqy nginx-amplify-agent \
    && apt-get purge -qqy curl apt-transport-https apt-utils gnupg1 \
    && rm -rf /etc/apt/sources.list.d/nginx-amplify.list \
    && rm -rf /var/lib/apt/lists/*

# Keep the nginx logs inside the container
RUN unlink /var/log/nginx/access.log \
    && unlink /var/log/nginx/error.log \
    && touch /var/log/nginx/access.log \
    && touch /var/log/nginx/error.log \
    && chown nginx /var/log/nginx/*log \
    && chmod 644 /var/log/nginx/*log

# Copy nginx stub_status config
COPY ./conf.d/stub_status.conf /etc/nginx/conf.d

# API_KEY is required for configuring the NGINX Amplify Agent.
# It could be your real API key for NGINX Amplify here if you wanted
# to build your own image to host it in a private registry.
# However, including private keys in the Dockerfile is not recommended.
# Use the environment variables at runtime as described below.

#ENV API_KEY 1234567890

# If AMPLIFY_IMAGENAME is set, the startup wrapper script will use it to
# generate the 'imagename' to put in the /etc/amplify-agent/agent.conf
# If several instances use the same 'imagename', the metrics will
# be aggregated into a single object in NGINX Amplify. Otherwise Amplify
# will create separate objects for monitoring (an object per instance).
# AMPLIFY_IMAGENAME can also be passed to the instance at runtime as
# described below.

#ENV AMPLIFY_IMAGENAME my-docker-instance-123

# The /entrypoint.sh script will launch nginx and the Amplify Agent.
# The script honors API_KEY and AMPLIFY_IMAGENAME environment
# variables, and updates /etc/amplify-agent/agent.conf accordingly.

COPY ./entrypoint.sh /entrypoint.sh

# TO set/override API_KEY and AMPLIFY_IMAGENAME when starting an instance:
# docker run --name my-nginx1 -e API_KEY='..effc' -e AMPLIFY_IMAGENAME="service-name" -d nginx-amplify

ENTRYPOINT ["/entrypoint.sh"]
