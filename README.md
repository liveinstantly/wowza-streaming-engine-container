# Custom Container for Wowza Streaming Engine

## Overview

This is a repository for building a Wowza Streaming Engine contaienr image from scratch, which can be applied to your custom container image of Wowza Streaming Engine instance. This container image is based on Ubuntu 22.04 (Jammy) release.

Although there is official public container images from Wowza at Docker Hub ([https://hub.docker.com/r/wowzamedia/wowza-streaming-engine-linux](https://hub.docker.com/r/wowzamedia/wowza-streaming-engine-linux)), this repository gives you a chance to optimize your own container image for Wowza Streaming Engine. For example, you can reduce or optimize a footprint of container image, and your custom logics and configurations can be pre-installed to your own container image.

This container image supports SSL/TLS enablement, which can be combined with Cert Manager in the Kubernetes deployment.

## Quick Start

### 1. Use our public container image

We have pushed our custom container image for Wowza Streaming Engine (Linux) at GitHub Container Registy.
You can use the following container images:

* `ghcr.io/liveinstantly/wowza-streaming-engine-ubuntu:latest`

Here is a sample command to pull an image for your Docker environment.

```shell
docker pull ghcr.io/liveinstantly/wowza-streaming-engine-ubuntu:latest
```

### 2. Run a container image

This section introduces how to run the Wowza Streaming Engine container in your Docker environment.

Wowza Streaming Engine configured by this container setup listens the following ports as default:

| Port | Service Description             |
| ---- | ------------------------------- |
| 1935 | WSE HTTP Default Streaming      |
| 8086 | WSE Administration (HTTP)       |
| 8087 | WSE REST API Interface (HTTP)   |
| 8088 | WSE Manager Web Portal (HTTP)   |

The following environment values are for customizing container startup parameters:

| Environment Variables | Description |
| --------------------- | ----------- |
| WSE_MGR_USER          | Specify a username for Wowza Streaming Engine Manager. If this parameter isn't used, the default username is `wowza`. |
| WSE_MGR_PASS          | Specify a password for Wowza Streaming Engine Manager. If this parameter isn't used, the ddefault password is `wowza`. |
| WSE_LIC               | Specify your Wowza Streaming Engine license string. If this parameter isn't used, Wowza's default trial license key is used. |
| WSE_IP_PARAM          | Specify an internal IP address for the container. If this parameter isn't used, the default parameter `localhost` is used. |
| WSE_TLS_CERT          | Specify a mount-point directory of SSL/TLS private key (`tls.key`) and certificate (`tls.crt`) for Wowza Streaming Engine. |
| WSE_MGR_TLS_CERT      | Specify a mount-point directory of SSL/TLS private key (`tls.key`) and certificate (`tls.crt`) for Wowza Streaming Engine Manager. |

Here is a sample command for running a container instance.
You may need to create docker volumes to mount the volumes for storing your own configuration files and server working files (e.g. logs, stats).

```shell
docker run -d --rm \
    // for Default Streaming Engine
    --expose 1935/tcp --expose 8086/tcp --expose 8087/tcp \
    --publish 1935:1935 --publish 8086:8086 --publish 8087:8087 \
    // for SSL/TLS Streaming Engine
    --expose 443/tcp --publish 443:443 \
    // for Non-SSL Manager
    --expose 8088/tcp  --publish 8088:8088 \
    // for SSL/TLS Manager
    --expose 8090/tcp  --publish 8090:8090 \
    --volume wse-engine-logs:/usr/local/WowzaStreamingEngine/logs \
    --volume wse-manager-logs:/usr/local/WowzaStreamingEngine/manager/logs \
    --volume supervisor-logs:/var/log/supervisor/ \
    --volume wse-engine-conf:/usr/local/WowzaStreamingEngine/conf \
    --volume wse-manager-conf:/usr/local/WowzaStreamingEngine/manager/conf \
    --volume wse-engine-content:/usr/local/WowzaStreamingEngine/manager/content \
    --volume wse-engine-keys:/usr/local/WowzaStreamingEngine/manager/keys \
    --volume wse-engine-apps:/usr/local/WowzaStreamingEngine/applications \
    --volume wse-engine-stats:/usr/local/WowzaStreamingEngine/stats \
    --volume sample-tls-1:/etc/cert-engine \
    --volume sample-tls-2:/etc/cert-engine \
    --env WSE_MGR_USER=[username] \
    --env WSE_MGR_PASS=[password] \
    --env WSE_LIC=[license] \
    --env WSE_IP_PARAM=[wowza-ip-address] \
    --env WSE_TLS_CERT=/etc/cert-engine \
    --env WSE_TLS_CERT=/etc/cert-manager \
    ghcr.io/liveinstantly/wowza-streaming-engine-ubuntu:latest
```

You can also do a test run with the following command:

```shell
yarn run start
```

To stop a test run, please run the following command:

```shell
yarn run stop
```

## Build your own custom container image

### Details of build scripts

The build scripts in this repository will give you a way to build a container image from scratch with public Linux container image. This will use `ubuntu:jammy` container image as base Linux image for Wowza Streaming Engine.

The build scripts will download Wowza Streaming Engine Installer binary from Wowza's public website, do unattended installation, and change server configuration files.

> NOTE: From 4.8.21 or later version of Wowza Streaming Engine, Wowza seems not to deliver installer binaries at thier public website. Your will need to download from Wowza Portal after logging in with your Wowza account. Please copy the installer to `image_root/root` folder before building your own container image.

The changes of server configuration files are as below:

* conf/Server.xml
  * Allow REST API Interface access from everywhere (`*`) instead of localhost only (`127.0.0.1`)
* conf/Tune.xml
  * Change heap size from Development mode (`TuningHeapSizeDevelopment`) to Production mode (`TuningHeapSizeProduction`)
* conf/live/Application.xml
  * 1. Add `cmafstreamingpacketizer` to `Streams/LiveStreamPacketizers`.
  * 2. Add all VOD Caption Providers to `TimedText/VODTimedTextProviders`.
  * 3. Add the following properties to `LiveStreamPacketizer`.
    * `cupertinoChunkDurationTarget` = 2000 ms
    * `cupertinoMaxChunkCount` = 60
    * `cupertinoPlaylistChunkCount` = 30
    * `mpegdashChunkDurationTarget` = 2000 ms
    * `mpegdashMaxChunkCount` = 60
    * `mpegdashPlaylistChunkCount` = 30
    * `cmafSegmentDurationTarget` = 2000 ms
    * `cmafMaxSegmentCount` = 60
    * `cmafPlaylistSegmentCount` = 30
    * `cupertinoCreateAudioOnlyRendition` = true
    * `cupertinoCreateVideoOnlyRendition` = true
    * `cupertinoPacketizeAllStreamsAsTS` = true
  * 4. Add the following properties to `HTTPStreamer`.
    * `cupertinoExtXVersion` = 5 (use version 5)
    * `cupertinoCodecStringFormatId` = 2 (use new codec id format)
  * 5. Add the following Custom properties.
    * `mpegdashMinBufferTime` = 6000 ms
* conf/vod/Application.xml
  * 1. Add all VOD Caption Providers to `TimedText/VODTimedTextProviders`.
  * 2. Add the following properties to `HTTPStreamer`.
    * `cupertinoChunkDurationTarget` = 2000 ms
    * `mpegdashSegmentDurationTarget` = 2000 ms
  * 3. Add the following Custom properties.
    * `mpegdashMinBufferTime` = 6000 ms
* bin/startup.sh
  * Change startup service for supervisord.
* manager/bin/startmgr.sh
  * Change startup service for supervisord.

### Run a build command

If you want to build your own container image, you can run the following command. This will create a container image named with `local/wowza-streaming-engine-ubuntu:latest`.

```shell
yarn run test:build
```

### Run and Debug a container instance

You can run the following command to start your own container instance.

```shell
yarn run test:start
```

And run the following command to debug a running instance interally by logging in with `bash`.

```shell
docker exec -it <container_id> bash
```

To stop a test run, please run the following command:

```shell
yarn run test:stop
```

## References

* [Wowza Streaming Engine](https://www.wowza.com/streaming-engine)
* [Download Wowza Streaming Engine](https://www.wowza.com/pricing/installer)
* [Latest software updates for Wowza Streaming Engine](https://www.wowza.com/docs/wowza-streaming-engine-software-updates)
* [Wowza Streaming Engine 4.8.21 Release Notes](https://www.wowza.com/docs/wowza-streaming-engine-4-8-21-release-notes)
* [Wowza Streaming Engine release history](https://www.wowza.com/docs/wowza-streaming-engine-release-history)
