FROM nginx:latest

RUN apt-get update && apt-get install -y \
    curl \
    apt-transport-https \
    apt-utils \
    python \
    lsb-release && \
    rm -rf /var/lib/apt/lists/*

# API_KEY is required for amplify-install.sh to generate the initial
# configuration file for the Amplify Agent.
# It have to be your real API key for Amplify here.
# Also the real API_KEY could be passed to the container via "docker run -e 'API_KEY=..'"

ARG API_KEY

# If AMPLIFY_HOSTNAME is set, the launch.sh script will use it to generate
# the 'hostname' to put in the /etc/amplify-agent/agent.conf
# If several instances use the same hostname, the metrics will
# be aggregated into a single object in Amplify. Otherwise Amplify
# will create separate objects for monitoring (an object per instance).
# AMPLIFY_HOSTNAME can also be passed to the instance through
# the use of ""docker run -e 'AMPLIFY_HOSTNAME=..'"

#ENV AMPLIFY_HOSTNAME my-docker-instance-123

# Copy nginx stub_status config
COPY ./conf.d/stub_status.conf /etc/nginx/conf.d
RUN chown nginx /etc/nginx/conf.d/stub_status.conf

# The /opt/bin/launch.sh script will launch nginx and the Amplify Agent.
# The script honors API_KEY and AMPLIFY_HOSTNAME environment
# variables, and updates /etc/amplify-agent/agent.conf accordingly.

RUN mkdir -p /opt/bin
COPY ./launch.sh /opt/bin/launch.sh
RUN chmod a+rx /opt/bin/launch.sh

# Install the Amplify Agent

RUN curl -L -o amplify-install.sh \
	       https://github.com/nginxinc/nginx-amplify-agent/raw/master/packages/install.sh && \
    sh ./amplify-install.sh && \
    rm -f ./amplify-install.sh

# launch.sh will start nginx and Amplify Agent
#
# TO set/override API_KEY and AMPLIFY_HOSTNAME when starting an instance:
# docker run --name my-nginx1 -e API_KEY='..effc' -e AMPLIFY_HOSTNAME="service-name" -d nginx-amplify

CMD ["/opt/bin/launch.sh"]
