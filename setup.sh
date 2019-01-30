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

#Logstash
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
echo "deb https://artifacts.elastic.co/packages/6.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-6.x.list
apt-get update && sudo apt-get install kibana -y
systemctl daemon-reload
systemctl enable kibana.service

#Kibana
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
echo "deb https://artifacts.elastic.co/packages/6.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-6.x.list
apt-get update && sudo apt-get install logstash -y
systemctl daemon-reload
systemctl start logstash.service

#Filebeat
curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-6.6.0-amd64.deb
sudo dpkg -i filebeat-6.6.0-amd64.deb
systemctl daemon-reload
systemctl start filebeat.service
filebeat modules enable iis
filebeat setup -e

mkdir /iislogs
chmod 777 /iislogs

apt install samba -y

echo "[global]" > /etc/samba/smb.conf
echo "workgroup = WORKGROUP" >> /etc/samba/smb.conf
echo "server string = SOF-ELK Server %v" >> /etc/samba/smb.conf
echo "netbios name = sof-elk" >> /etc/samba/smb.conf
echo "security = user" >> /etc/samba/smb.conf
echo "map to guest = bad user" >> /etc/samba/smb.conf
echo "dns proxy = no" >> /etc/samba/smb.conf
echo "[Anonymous]" >> /etc/samba/smb.conf
echo "path = /iislogs" >> /etc/samba/smb.conf
echo "browsable =yes" >> /etc/samba/smb.conf
echo "writable = yes" >> /etc/samba/smb.conf
echo "guest ok = yes" >> /etc/samba/smb.conf
echo "read only = no" >> /etc/samba/smb.conf
firewall-cmd --permanent --zone=public --add-service=samba
firewall-cmd --reload
systemctl enable smb.service
systemctl enable nmb.service
systemctl start smb.service
systemctl start nmb.service

reboot
