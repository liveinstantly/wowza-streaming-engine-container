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

# Arguments for build
ARG WSE_VER=4.8.21+6
ARG WSE_VER2=4-8-21+6

# An expired trial license as default license only for installer.
ENV WSE_LICENSEKEY=ET1E4-v8Qtp-QFK9v-4baBn-eepcV-vkGVa-6hj89f6HRZUy
# ONLY FOR SETUP: A temporary username/password as default Wowza WSE credential
# /usr/sbin/entrypoint.sh will override Wowza WSE credential.
ENV WSE_USERNAME=wowza
ENV WSE_PASSWORD=wowza

# Copy required files.
ADD ./image_root /
RUN chmod 755 /root/wse4_unattended_installer.exp \
    && chmod 755 /root/generate_engine_jks.sh \
    && chmod 755 /root/generate_manager_jks.sh \
    && chmod 755 /usr/sbin/entrypoint.sh \
    && chmod 644 /etc/supervisor/conf.d/WowzaStreamingEngine.conf \
    && chmod 644 /etc/supervisor/conf.d/WowzaStreamingEngineManager.conf
# Setup tools.
RUN apt update -y && apt upgrade -y \
    && apt install supervisor curl ca-certificates expect patch xmlstarlet apache2-utils -y \
    && apt-get autoremove -y \
    && update-ca-certificates \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Download Wowza Streaming Engine installer package.
RUN [ -f /root/WowzaStreamingEngine-${WSE_VER}-linux-x64-installer.run ] \
    || curl -f -o /root/WowzaStreamingEngine-${WSE_VER}-linux-x64-installer.run https://www.wowza.com/downloads/WowzaStreamingEngine-${WSE_VER2}/WowzaStreamingEngine-${WSE_VER}-linux-x64-installer.run
# NOTES: If you will get 404 error at here, please download a Wowza Streaming Engine Installer file and copy it to ./image_root/root directory.

# Setup Wowza Streaming Engine.
RUN mv /root/WowzaStreamingEngine-${WSE_VER}-linux-x64-installer.run /root/WowzaStreamingEngine-linux-x64-installer.run \
    && chmod +x /root/WowzaStreamingEngine-linux-x64-installer.run \
    && /root/wse4_unattended_installer.exp \
    && cd /root \
    && curl -O https://www.wowza.com/downloads/forums/restapidocumentation/RESTAPIDocumentationWebpage.zip \
    && cd /usr/local/WowzaStreamingEngine \
    && for i in `ls -1 /root/patches/${WSE_VER}/*.diff`; do patch -p0 < $i ; done \
    && cp /root/generate_engine_jks.sh ./bin/ \
    && cp /root/generate_manager_jks.sh ./manager/bin/ \
    && mkdir -p /root/wowza_backup_home/ \
    && mkdir -p /root/wowza_backup_home/manager/ \
    && cp -rp /usr/local/WowzaStreamingEngine/conf /root/wowza_backup_home/ \
    && cp -rp /usr/local/WowzaStreamingEngine/manager/conf /root/wowza_backup_home/manager \
    && apt remove curl expect patch -y \
    && rm -rf /root/patches/ /root/generate_engine_jks.sh /root/generate_manager_jks.sh /root/wse_unattended_install.exp \
    && rm -f /root/WowzaStreamingEngine-linux-x64-installer.run /root/WowzaStreamingEngine-*-linux-x64-installer.run \
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
