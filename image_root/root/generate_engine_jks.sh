#!/bin/bash

export WMSAPP_HOME="$( readlink /usr/local/WowzaStreamingEngine )"
export WSE_P12=${WMSAPP_HOME}/conf/keystore.p12
export WSE_JKS=${WMSAPP_HOME}/conf/keystore.jks
export WSE_KS_PASSWORD=${WMSAPP_HOME}/conf/keystore.passwd

if [ "x${WSE_TLS_CERT}" = "x" ]; then
    echo "No variable setting: WSE_TLS_CERT".
    exit 1
fi

if [ ! -f ${WSE_KS_PASSWORD} ]; then
    openssl rand -base64 15 > ${WSE_KS_PASSWORD}
fi
export PASS=`cat ${WSE_KS_PASSWORD}`

# Enable SSL for Wowza Streaming Engine
if [ -d ${WSE_TLS_CERT} ]; then

    if [ -f ${WSE_TLS_CERT}/tls.crt -a -f ${WSE_TLS_CERT}/tls.key ]; then

        rm -f ${WSE_P12} ${WSE_JKS}
        openssl pkcs12 -export -legacy -in ${WSE_TLS_CERT}/tls.crt -inkey ${WSE_TLS_CERT}/tls.key -out ${WSE_P12} -password pass:${PASS}
        ${WMSAPP_HOME}/java/bin/keytool -importkeystore \
            -destkeystore ${WSE_JKS} -deststoretype jks -deststorepass ${PASS} \
            -srckeystore ${WSE_P12} -srcstoretype pkcs12 -srcstorepass ${PASS}

        xmlstarlet edit --update "/Root/Server/RESTInterface/SSLConfig/Enable" --value "true" ${WMSAPP_HOME}/conf/Server.xml > /tmp/Server.xml.1
        xmlstarlet edit --update "/Root/Server/RESTInterface/SSLConfig/KeyStorePassword" --value "${PASS}" /tmp/Server.xml.1 > /tmp/Server.xml.2
        cat /tmp/Server.xml.2 | xmlstarlet fo -t | xmlstarlet c14n | sed 's/$/\r/' > ${WMSAPP_HOME}/conf/Server.xml
        rm -f /tmp/Server.xml.1 /tmp/Server.xml.2

        xmlstarlet ed --update '/Root/VHost/HostPortList/HostPort[Name="Default SSL Streaming"]/SSLConfig/KeyStorePassword' --value "${PASS}" ${WMSAPP_HOME}/conf/VHost.xml > /tmp/VHost.xml.1
        cat /tmp/VHost.xml.1 | xmlstarlet fo -t | xmlstarlet c14n | sed 's/$/\r/' > ${WMSAPP_HOME}/conf/VHost.xml

    fi
fi
