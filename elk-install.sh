#!/bin/bash

KIBANA_VERSION="4.5.3"
ELASTICSEARCH_VERSION="2.3.4"
LOGSTASH_VERSION="2.3.4"
DOWNLOAD_DIRECTORY="/tmp/elk-download"
ELASTICSEARCH_CLUSTER_NAME="sweethome"
ELASTICSEARCH_DATA_DIRECTORY="/var/elk/data/"

#
# ---------- I N I T -----------------------------------------------
#

KIBANA="kibana-${KIBANA_VERSION}-linux-x64"
KIBANA_DIST_FILE="${KIBANA}-linux-x64.tar.gz"
ELASTICSEARCH="elasticsearch-${ELASTICSEARCH_VERSION}"
ELASTICSEARCH_DIST_FILE="${ELASTICSEARCH}.tar.gz"
ELASTICSEARCH_CONF_DIRECTORY="/etc/elasticsearch"
LOGSTASH="logstash-${LOGSTASH_VERSION}"
LOGSTASH_DIST_FILE="${LOGSTASH}.tar.gz"

print_done() {
	printf '\e[1;32mDone.\e[m\n%s\n' "${DIVIDER}"
}

print_message() {
	printf "%s: \e[1m%s\e[m\n" "${1}" "${2}"
}

print_major_message() {
	printf "==> %s: \e[1m%s\e[m\n" "${1}" "${2}"
}

print_minor_message() {
	printf "> %s: \e[1m%s\e[m\n" "${1}" "${2}"
}

print_green() {
	printf '\e[1;32m%s\e[m\n' "${1}"
}

print_red() {
	printf '\e[1;31m%s\e[m\n' "${1}"
}

print_bold() {
	printf '\e[1m%s\e[m\n' "${1}"
}

#
#-----------------------------------------------------------------------------
#


echo 
echo "*** Installing ELK on Raspberry Pi ***"
echo
[[ -d ${DOWNLOAD_DIRECTORY} ]] && print_minor_message "Using" "${DOWNLOAD_DIRECTORY}" || mkdir ${DOWNLOAD_DIRECTORY} && print_minor_message "Created" "${DOWNLOAD_DIRECTORY}" || exit 1


# 
# ---------- E L A S T I C S E A R C H ----------------------------------------
#
install_elasticsearch() {
	print_major_message "Installing" "${ELASTICSEARCH}"

	cd ${DOWNLOAD_DIRECTORY}

	if [[ ! $(dpkg -l elasticsearch) ]]
	then
	  [[ -s ${ELASTICSEARCH}.deb ]] && print_minor_message "Loaded" "${ELASTICSEARCH}.deb" || sudo wget https://download.elastic.co/elasticsearch/release/org/elasticsearch/distribution/deb/elasticsearch/${ELASTICSEARCH_VERSION}/${ELASTICSEARCH}.deb || exit 1
	  sudo dpkg -i ${ELASTICSEARCH}.deb || exit 1
	else
	   print_minor_message "Already installed" "elasticsearch"
	fi

    # allow connections from everywhere
	sudo sed -i "/# network.host:.*/a network.host: 0.0.0.0" /etc/elasticsearch/elasticsearch.yml || exit 1
	sudo systemctl start elasticsearch.service
	print_message "Start Elasticsearch via" "sudo systemctl start elasticsearch.service"
	print_green "Elasticsearch installed."
	sudo systemctl status elasticsearch.service

}

#
# ---------- L O G S T A S H --------------------------------------------------
#
install_logstash() {
cd ${DOWNLOAD_DIRECTORY}
	sudo wget https://download.elasticsearch.org/logstash/logstash/${LOGSTASH}.tar.gz
	sudo tar -zxvf ${LOGSTASH}.tar.gz
	sudo mv ${LOGSTASH} /opt

	sudo ln -s /opt/${LOGSTASH} /opt/logstash
	sudo mkdir -p /etc/logstash/conf.d
	#sudo cp /mnt/TimeCapsule1/raspberrypi/etc/logstash/conf.d/* /etc/logstash/conf.d/
	sudo mkdir -p /var/log/logstash/

	print_green "Logstash installed."
}

#
# ---------- N O D E . J S ------------------------------------------------
#
install_node() {
  print_major_message "Installing" "latest node for arm"
  cd ${DOWNLOAD_DIRECTORY}
  if [[ $(dpkg -l node) ]]
  then
    print_minor_message "Skipping:" "latest node for arm is already installed"
  else
    print_minor_message "Removing" "nodejs-legacy to avoid conflicts"
    apt-get remove -y nodejs-legacy
    sudo wget http://node-arm.herokuapp.com/node_latest_armhf.deb
    sudo dpkg -i node_latest_armhf.deb
    print_green "Node for arm installed"
    node -v
  fi
}

#
# ---------- K I B A N A --------------------------------------------------
#
install_kibana() {
  print_major_message "Installing" "${KIBANA}"
  cd ${DOWNLOAD_DIRECTORY}

  print_minor_message "Dowload and extract" "kibana-${KIBANA_VERSION}-linux-x64.tar.gz"
  sudo wget https://download.elasticsearch.org/kibana/kibana/kibana-${KIBANA_VERSION}-linux-x64.tar.gz
  sudo tar -zxvf ${KIBANA}.tar.gz
  sudo mv ${KIBANA} /opt
  sudo ln -s /opt/${KIBANA} /opt/kibana

  # make sure kibana uses latest node & npm version
  #
  print_minor_message "Setup" "make sure kibana uses latest node & npm version"
  sudo mv /opt/kibana/node/bin/node /opt/kibana/node/bin/node.orig
  sudo mv /opt/kibana/node/bin/npm /opt/kibana/node/bin/npm.orig
  sudo ln -s /usr/local/bin/node /opt/kibana/node/bin/node
  sudo ln -s /usr/local/bin/npm /opt/kibana/node/bin/npm

  print_message "Start Kibana" "/opt/kibana/bin/kibana"
  print_green "Kibana installed"

}

install_kibana_plugins() {
  print_major_message "Installing" "Kibaka plugins"

  if [[ ! $(dpkg -l zip) ]]
  then
    sudo apt-get install -y zip
  fi
  cd $DOWNLOAD_DIRECTORY
  print_minor_message "Installing" "gauge-sg"
  git clone https://github.com/sbeyn/kibana-plugin-gauge-sg.git gauge-sg || exit 1
  zip -r gauge-sg.zip gauge-sg
  sudo /opt/kibana/bin/kibana plugin --install gauge-sg -u file:///$DOWNLOAD_DIRECTORY/gauge-sg.zip || exit 1

  print_minor_message "Installing" "line-sg"
  git clone https://github.com/sbeyn/kibana-plugin-line-sg.git line-sg || exit 1
  zip -r line-sg.zip line-sg
  sudo /opt/kibana/bin/kibana plugin --install gauge-sg -u file:///$DOWNLOAD_DIRECTORY/line-sg.zip || exit 1

  print_minor_message "Installing" "traffic-sg"
  git clone https://github.com/sbeyn/kibana-plugin-traffic-sg.git traffic-sg || exit 1
  zip -r traffic-sg.zip traffic-sg
  sudo /opt/kibana/bin/kibana plugin --install traffic-sg -u file:///$DOWNLOAD_DIRECTORY/traffic-sg.zip || exit 1

  print_green "Kibana plugins installed. Kibana restart needed to take effect."
}

#
# ---------- M A I N --------------------------------------------------
#

install_elasticsearch
install_node
install_kibana
install_kibana_plugins
