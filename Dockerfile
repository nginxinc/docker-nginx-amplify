FROM docker.io/nginx:latest as nginx

LABEL maintainer="NGINX Packaging <nginx-packaging@f5.com>"

# Install the NGINX Amplify Agent
RUN apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y curl gnupg1 procps lsb-release ca-certificates debian-archive-keyring \
    && curl https://nginx.org/keys/nginx_signing.key | gpg1 --dearmor | tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null \
    && echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] https://packages.amplify.nginx.com/py3/debian/ $(lsb_release -cs) amplify-agent" > /etc/apt/sources.list.d/nginx-amplify.list \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y nginx-amplify-agent \
    && apt-mark hold nginx-amplify-agent \
    && apt-get remove --purge --auto-remove -y curl gnupg1 \
    && rm -f /etc/apt/sources.list.d/nginx-amplify.list \
    && rm -f /usr/share/keyrings/nginx-archive-keyring.gpg \
    && rm -rf /var/lib/apt/lists/*

# Keep the nginx logs inside the container
RUN unlink /var/log/nginx/access.log \
    && unlink /var/log/nginx/error.log \
    && touch /var/log/nginx/access.log \
    && touch /var/log/nginx/error.log \
    && chown nginx /var/log/nginx/*log \
    && chmod 644 /var/log/nginx/*log

# Adjust permissions so agent could write log under nginx user
RUN chown nginx /var/log/amplify-agent/ /var/log/amplify-agent/agent.log

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

# To set/override API_KEY and AMPLIFY_IMAGENAME when starting an instance:
# docker run --name my-nginx1 -e API_KEY='..effc' -e AMPLIFY_IMAGENAME="service-name" -d nginx-amplify

ENTRYPOINT ["/entrypoint.sh"]
