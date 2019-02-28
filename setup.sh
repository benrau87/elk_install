if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

#Sources
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
echo "deb https://artifacts.elastic.co/packages/6.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-6.x.list

apt update && apt upgrade -y

#Java and deps
apt install -y openjdk-8-jre apt-transport-https wget nginx

#Elasticsearch
apt install -y elasticsearch
systemctl daemon-reload
systemctl enable elasticsearch.service
systemctl start elasticsearch.service

#Logstash
apt install -y kibana
systemctl enable kibana.service
systemctl start kibana.service

#Kibana
apt install -y logstash
sed -i 's/#server.host: "localhost"/server.host: "0.0.0.0"/g' /etc/kibana/kibana.yml
systemctl enable logstash.service
systemctl start logstash.service

#Filebeat for Local Logs
curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-6.6.0-amd64.deb
sudo dpkg -i filebeat-6.6.0-amd64.deb
filebeat setup
systemctl enable filebeat.service
systemctl start filebeat.service
rm filebeat-6.6.0-amd64.deb

#Extras if you want
#/usr/share/elasticsearch/bin/elasticsearch-plugin install --silent --batch ingest-geoip ingest-user-agent 
#/usr/share/logstash/bin/logstash-plugin install logstash-filter-dns --silent
