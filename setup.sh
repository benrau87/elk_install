if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi

apt update && apt upgrade -y

#Java
apt install -y openjdk-8-jre apt-transport-https wget nginx

#Elasticsearch
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
sudo apt-get install apt-transport-https
echo "deb https://artifacts.elastic.co/packages/6.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-6.x.list
sudo apt-get update && sudo apt-get install elasticsearch -y
systemctl daemon-reload
systemctl enable elasticsearch.service
systemctl start elasticsearch.service

#Logstash
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
echo "deb https://artifacts.elastic.co/packages/6.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-6.x.list
apt-get update && sudo apt-get install kibana -y
systemctl enable kibana.service
systemctl start kibana.service

#Kibana
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
echo "deb https://artifacts.elastic.co/packages/6.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-6.x.list
apt-get update && sudo apt-get install logstash -y
sed -i 's/#server.host: "localhost"/server.host: "0.0.0.0"/g' /etc/kibana/kibana.yml
systemctl enable logstash.service
systemctl start logstash.service

#Filebeat
curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-6.6.0-amd64.deb
sudo dpkg -i filebeat-6.6.0-amd64.deb
systemctl enable filebeat.service
systemctl start filebeat.service
filebeat modules enable iis
filebeat setup -e

mkdir /logs
chmod 755 /logs

apt install samba -y

echo "[global]" > /etc/samba/smb.conf
echo "workgroup = WORKGROUP" >> /etc/samba/smb.conf
echo "server string = SOF-ELK Server %v" >> /etc/samba/smb.conf
echo "netbios name = sof-elk" >> /etc/samba/smb.conf
echo "security = user" >> /etc/samba/smb.conf
echo "map to guest = bad user" >> /etc/samba/smb.conf
echo "dns proxy = no" >> /etc/samba/smb.conf
echo "[Logs]" >> /etc/samba/smb.conf
echo "path = /logs" >> /etc/samba/smb.conf
echo "browsable =yes" >> /etc/samba/smb.conf
echo "writable = yes" >> /etc/samba/smb.conf
echo "guest ok = yes" >> /etc/samba/smb.conf
echo "read only = no" >> /etc/samba/smb.conf

systemctl enable smb.service
systemctl enable nmb.service
systemctl start smb.service
systemctl start nmb.service

reboot
