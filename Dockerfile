# syntax=docker/dockerfile:1
FROM ubuntu:jammy AS builder

# Option 1) Build from Ubuntu image (replace the line above with:)
#FROM ubuntu:focal AS builder
#FROM ubuntu:jammy AS builder
#FROM ubuntu:focal-[YYYYMDMDD] AS builder
#FROM ubuntu:jammy-[YYYYMDMDD] AS builder

# Option 2) Build from scratch with Ubuntu root partition kits.
#FROM scratch AS builder
#ADD ubuntu-focal-oci-amd64-root.tar.gz /
#ADD ubuntu-jammy-oci-amd64-root.tar.gz /

LABEL "vendor"="Wowza Media Systems" "maintainer"="LiveInstantly, LLC."

# An expired trial license as default license only for installer.
ENV WSE_LICENSEKEY=ET1E4-v8Qtp-QFK9v-4baBn-eepcV-vkGVa-6hj89f6HRZUy
# ONLY FOR SETUP: A temporary username/password as default Wowza WSE credential
# /usr/sbin/entrypoint.sh will override Wowza WSE credential.
ENV WSE_USERNAME=wowza
ENV WSE_PASSWORD=wowza

# Copy required files.
ADD ./image_root /
RUN chmod 755 /root/wse4_unattended_installer.exp \
    && chmod 755 /usr/sbin/entrypoint.sh \
    && chmod 644 /etc/supervisor/conf.d/WowzaStreamingEngine.conf \
    && chmod 644 /etc/supervisor/conf.d/WowzaStreamingEngineManager.conf
# Setup tools.
RUN apt update -y && apt upgrade -y \
    && apt install supervisor curl expect patch -y \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*
# Download Wowza Streaming Engine installer package.
#RUN curl -o /root/WowzaStreamingEngine-linux-x64-installer.run \
#    https://www.wowza.com/downloads/WowzaStreamingEngine-4-8-20+1/WowzaStreamingEngine-4.8.20+1-linux-x64-installer.run
# Use Downloaded Wowza Streaming Engine installer package.
RUN mv /root/WowzaStreamingEngine-4.*-linux-x64-installer.run /root/WowzaStreamingEngine-linux-x64-installer.run
# Setup Wowza Streaming Engine.
RUN chmod +x /root/WowzaStreamingEngine-linux-x64-installer.run \
    && /root/wse4_unattended_installer.exp \
    && cd /root \
    && rm -f /root/WowzaStreamingEngine-linux-x64-installer.run \
    && curl -O https://www.wowza.com/downloads/forums/restapidocumentation/RESTAPIDocumentationWebpage.zip \
    && cd /usr/local/WowzaStreamingEngine \
    && patch -p0 < /root/patches/wowza-streaming-engine-scripts.diff \
    && patch -p0 < /root/patches/conf-live-Application.xml.diff \
    && patch -p0 < /root/patches/conf-vod-Application.xml.diff \
    && patch -p0 < /root/patches/conf-Server.xml.diff \
    && patch -p0 < /root/patches/conf-Tune.xml.diff \
    && apt remove curl expect patch -y \
    && mkdir -p /root/wowza_backup_home/ \
    && mkdir -p /root/wowza_backup_home/manager/ \
    && cp -rp /usr/local/WowzaStreamingEngine/conf /root/wowza_backup_home/ \
    && cp -rp /usr/local/WowzaStreamingEngine/manager/conf /root/wowza_backup_home/manager \
    && rm -f /root/WowzaStreamingEngine-linux-x64-installer.run /root/wse_unattended_install.exp \
    && rm -f '/usr/local/WowzaStreamingEngine/Uninstall Wowza Streaming Engine.desktop' \
    && rm -f /usr/local/WowzaStreamingEngine/uninstall \
    && rm -f /usr/local/WowzaStreamingEngine/uninstall.dat \
    && rm -rf /usr/local/WowzaStreamingEngine/rollbackBackupDirectory

# Copy user-defined default conf/Server.license.
RUN [ -f /root/conf/Server.license ] && cp /root/conf/Server.license /usr/local/WowzaStreamingEngine/conf/

VOLUME /usr/local/WowzaStreamingEngine/conf
VOLUME /usr/local/WowzaStreamingEngine/manager/conf
VOLUME /usr/local/WowzaStreamingEngine/content

FROM scratch AS imaging
COPY --from=builder / /
#CMD ["bash"]
ENTRYPOINT ["/usr/sbin/entrypoint.sh"]
