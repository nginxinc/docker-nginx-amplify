<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->


- [1. Overview](#1-overview)
  - [1.1. NGINX Amplify Agent Inside Docker Container](#11-nginx-amplify-agent-inside-docker-container)
  - [1.2. Standalone Mode](#12-standalone-mode)
  - [1.3. Aggregate Mode](#13-aggregate-mode)
  - [1.4. Current Limitations](#14-current-limitations)
- [2. How to Build and Run an Amplify-enabled NGINX image?](#2-how-to-build-and-run-an-amplify-enabled-nginx-image)
  - [2.1. Building an Amplify-enabled image with NGINX](#21-building-an-amplify-enabled-image-with-nginx)
  - [2.2. Running an Amplify-enabled NGINX Docker Container](#22-running-an-amplify-enabled-nginx-docker-container)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->


## 1. Overview

### 1.1. NGINX Amplify Agent Inside Docker Container 

The Amplify Agent can be deployed in a Docker environment. At this time there are still certain limitations related to how and what metrics are collected (see below), but overall the agent can be used to monitor NGINX instances running inside a Docker container.

The "agent inside the container" is currenly the only mode of operation. In other words, the agent should be running in the same container, next to the NGINX instance.

### 1.2. Standalone Mode

By default the agent will try to determine the OS' `hostname` on startup. The `hostname` is used to generate a unique UUID to uniquely identify the new object in the monitoring backend.

This means, that in the absence of the additional configuration steps, each new container started from an Amplify-enabled image, will be reported as a standalone system in the Amplify web user interface.

You can learn more about the agent's configuration options [here](https://github.com/nginxinc/nginx-amplify-doc/blob/master/amplify-guide.md#configuring-amplify-agent).

### 1.3. Aggregate Mode

When reporting a new object for monitoring, the agent honors the `hostname` configuration option in **/etc/amplify-agent/agent.conf** (see the Amplify [docs](https://github.com/nginxinc/nginx-amplify-doc/blob/master/amplify-guide.md#changing-the-hostname-and-uuid) for additional information).

Normally, the `hostname` is derived automatically through the standard means of obtaining the name of the OS object being monitored. It is possible to explicitly specify the same `hostname` for multiple instances. In this scenario, the metrics received from several agents will be aggregated internally on the backend side—with a single OS object created for monitoring. This way a combined view of various statistics can be obtained (e.g. for a "microservice"). For example, this combined view can display the total number of requests per second through all backend instances of a microservice.

Containers with a common `hostname` do not have to share the same local Docker image or NGINX configuration. Containers can be located on different physical hosts too.

To set a common `hostname` for several containers started from the Amplify-enabled image, you may either configure it explicitly in the Dockerfile—or use the `-e` option with `docker run`:

```
      $ docker run --name mynginx1 -e API_KEY=ecfdee2e010899135c258d741a6effc7 AMPLIFY_HOSTNAME=my-service-A -d nginx-amplify
```

### 1.4. Current Limitations 

The following list summarizes the limitations of Docker containers monitoring:

 * In order for the agent to collect [additional NGINX metrics](https://github.com/nginxinc/nginx-amplify-doc/blob/master/amplify-guide.md#additional-nginx-metrics) the NGINX logs should be kept inside the container (by default the NGINX logs are redirected to the Docker log collector). At this time the agent can obtain NGINX log files only directly from storage.
 * In "aggregate" mode, some of the OS metrics can be inaccurate. In addition, some of the metadata describing the OS might be irrelevant.
 * The agent can only monitor NGINX from inside the container. It is not currently possible to run the Amplify Agent in a separate container and monitor the neighboring container(s) running NGINX.
 
We'll be working on improving the support for Docker in the nearest future. Stay tuned!

## 2. How to Build and Run an Amplify-enabled NGINX image?

### 2.1. Building an Amplify-enabled image with NGINX

(**Note**: If you are really new to Docker, [here's](https://docs.docker.com/engine/installation/) how to install Docker Engine on various OS.)

Let's pick our official [NGINX Docker image](https://hub.docker.com/_/nginx/) as a good example. The Dockerfile that we're going to use for an Amplify-enabled image is [here](https://github.com/nginxinc/docker-nginx-amplify/blob/master/Dockerfile).

Here's how you can build the Docker image with the Amplify Agent inside, based on the official NGINX image:

```
    $ docker build -t nginx-amplify .
```

After the image is built, check the list of Docker images:

```
    $ docker images
    REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
    nginx-amplify       latest              c6e96dd94f49        18 seconds ago      269.8 MB
```

### 2.2. Running an Amplify-enabled NGINX Docker Container

To start a container from the new image, use the command below:

```
    $ docker run --name mynginx1 -e API_KEY=ecfdee2e010899135c258d741a6effc7 -d nginx-amplify
```

(again, if you'd like to aggregate metrics from several containers running identical image, add `-e AMPLIFY_HOSTNAME=<my-service-name>` as well)

After the container has started, you may check it's status with `docker ps`:

```
    $ docker ps
    CONTAINER ID        IMAGE               COMMAND                CREATED             STATUS              PORTS               NAMES
    9f4729d4c608        nginx-amplify       "/opt/bin/launch.sh"   3 seconds ago       Up 2 seconds        80/tcp, 443/tcp     mynginx1
```

and you can also check `docker logs`:

```
    $ docker logs 9f4729d4c608
    starting nginx..
    updating /etc/amplify-agent/agent.conf ..
     ---> using api_key = ecfdee2e010899135c258d741a6effc7
     ---> using hostname = 
    starting amplify-agent..
    watching nginx master process..
```

Check what processes have started:

```
    $ docker exec 9f4729d4c608 ps axu
    USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
    root         1  0.0  0.1   4328   676 ?        Ss   17:03   0:00 /bin/sh /opt/bin/launch.sh
    root         6  0.0  0.5  31596  2832 ?        S    17:03   0:00 nginx: master process nginx -g daemon off;
    nginx       11  0.0  0.3  31988  1968 ?        S    17:03   0:00 nginx: worker process
    nginx       52  2.6  8.9 110668 45032 ?        S    17:03   0:03 amplify-agent                                                                                                                              
    root       354  0.0  0.0   4228   348 ?        S    17:05   0:00 sleep 60
```

If you see the **amplify-agent** process, it all went smoothly, and you should see the new container in the Amplify web user interface in about a minute or so.

Check the Amplify Agent log:

```
    $ docker exec 9f4729d4c608 tail -2 /var/log/amplify-agent/agent.log
    2016-03-27 16:57:49,931 [56] supervisor agent started, version: 0.30-1
    2016-03-27 16:57:50,181 [56] nginx_config running nginx -t -c /etc/nginx/nginx.conf
```

When you're done with the container, you can stop it with:

```
    $ docker stop 9f4729d4c608
```

To check the status of all containers (running and stopped):

```
    $ docker ps --all
    CONTAINER ID        IMAGE               COMMAND                CREATED             STATUS                        PORTS               NAMES
    9f4729d4c608        nginx-amplify       "/opt/bin/launch.sh"   17 minutes ago      Exited (137) 12 minutes ago                       mynginx1
```
