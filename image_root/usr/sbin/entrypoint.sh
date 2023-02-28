#!/bin/bash

WMSAPP_HOME="$( readlink /usr/local/WowzaStreamingEngine )"

print() {
        echo "ENTRYPOINT=> $1"
}

# ------------------------------------------------------------------------------
# Copy WSE configuration files from initial backup
# ------------------------------------------------------------------------------
if [ "$(ls -1 /usr/local/WowzaStreamingEngine/conf | wc -l)" = "0" ]; then
        print "Engine configuration files not found. Restoring initial configuration files..."
        cp -rp /root/wowza_backup_home/conf/* /usr/local/WowzaStreamingEngine/conf/
        print "Copied."
else
        print "Found Engine configuration files. Not copied."
fi
if [ "$(ls -1 /usr/local/WowzaStreamingEngine/manager/conf | wc -l)" = "0" ]; then
        print "Engine Manager configuration files not found. Restoring initial configuration files..."
        cp -rp /root/wowza_backup_home/manager/conf/* /usr/local/WowzaStreamingEngine/manager/conf/
        print "Copied."
else
        print "Found Engine Manager configuration files. Not copied."
fi


# ------------------------------------------------------------------------------
# Update conf/Server.license
# ------------------------------------------------------------------------------
if [ ! -z $WSE_LIC ]; then
print "Override Engine license file."
cat > ${WMSAPP_HOME}/conf/Server.license <<EOF
-----BEGIN LICENSE-----
${WSE_LIC}
-----END LICENSE-----
EOF
fi


# ------------------------------------------------------------------------------
# Update Wowza WSE credentials
# ------------------------------------------------------------------------------
print "Reset Engine credential (username/password)."
if [ -z $WSE_MGR_USER ]; then
        mgrUser="wowza"
else
        mgrUser=$WSE_MGR_USER
fi
if [ -z $WSE_MGR_PASS ]; then
        mgrPass="wowza"
else
        mgrPass=$WSE_MGR_PASS
fi
# Update Manager credentials
WSE_MGR_PASS_BCRYPT=`htpasswd -bnBC 10 "" "${WSE_MGR_PASS}" | sed 's/^://'`
grep -e "^#" ${WMSAPP_HOME}/conf/admin.password > ${WMSAPP_HOME}/conf/admin.password.new
echo -e "\n$mgrUser $WSE_MGR_PASS_BCRYPT admin|advUser bcrypt\n" >> ${WMSAPP_HOME}/conf/admin.password.new
mv ${WMSAPP_HOME}/conf/admin.password.new ${WMSAPP_HOME}/conf/admin.password
# Update JMX Remote credentials
echo -e "$mgrUser $mgrPass\n" > ${WMSAPP_HOME}/conf/jmxremote.password
echo -e "$mgrUser readwrite\n" > ${WMSAPP_HOME}/conf/jmxremote.access
# Update Publish credentials
#grep -e "^#" ${WMSAPP_HOME}/conf/publish.password > ${WMSAPP_HOME}/conf/publish.password.new
#echo -e "\n$mgrUser $mgrPass\n" >> ${WMSAPP_HOME}/conf/publish.password.new
#mv ${WMSAPP_HOME}/conf/publish.password.new ${WMSAPP_HOME}/conf/publish.password


# ------------------------------------------------------------------------------
# Update conf/Server.xml and conf/VHost.xml
# ------------------------------------------------------------------------------
if [[ ! -z $WSE_IP_PARAM ]]; then
        print "Change configuration files to replace localhost with user defined IP."
        #change localhost to some user defined IP
        cat "${WMSAPP_HOME}/conf/Server.xml" > Server.xml.tmp1
        sed 's|\(<IpAddress>localhost</IpAddress>\)|<IpAddress>'"$WSE_IP_PARAM"'</IpAddress> <!--changed for default install. \1-->|' <Server.xml.tmp1 >Server.xml.tmp2
        sed 's|\(<RMIServerHostName>localhost</RMIServerHostName>\)|<RMIServerHostName>'"$WSE_IP_PARAM"'</RMIServerHostName> <!--changed for default install. \1-->|' <Server.xml.tmp2 >Server.xml.tmp3
        cat Server.xml.tmp3 > ${WMSAPP_HOME}/conf/Server.xml
        rm Server.xml.tmp1 Server.xml.tmp2 Server.xml.tmp3

        cat "${WMSAPP_HOME}/conf/VHost.xml" > VHost.xml.tmp1
        sed 's|\(<IpAddress>${com.wowza.wms.HostPort.IpAddress}</IpAddress>\)|<IpAddress>'"$WSE_IP_PARAM"'</IpAddress> <!--changed for default cloud install. \1-->|' <VHost.xml.tmp1 >VHost.xml.tmp2
        cat VHost.xml.tmp2 >${WMSAPP_HOME}/conf/VHost.xml
        rm VHost.xml.tmp1 VHost.xml.tmp2
fi


# ------------------------------------------------------------------------------
# Run /usr/bin/supervisord
# ------------------------------------------------------------------------------
print "Start supervisord."
exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
