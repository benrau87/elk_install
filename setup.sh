if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

echo "Enter credentials for accessing the web ELK console"

read -p 'Username: ' nginxUsername

while true; do
    read -p 'Password: ' passvar1
    echo
    read -p 'Verify Password: ' passvar2
    echo
    [ "$passvar1" == "$passvar2" ] && break
    echo "Passwords do not match..."
done

for iface in $(ifconfig | cut -d ' ' -f1| tr '\n' ' ')
do 
  addr=$(ip -o -4 addr list $iface | awk '{print $4}' | cut -d/ -f1)
  printf "$iface\t$addr\n"
done
echo -e "What is the IP or hostname you wish link to Kibana?(ex: 0.0.0.0)"
read HOSTIPADDR

#Sources
add-apt-repository ppa:webupd8team/java -y
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-6.x.list
echo debconf shared/accepted-oracle-license-v1-1 select true | \
debconf-set-selections
apt update

#Java and deps
apt install -y apt-transport-https wget nginx apache2-utils openjdk-11-jre-headless samba cifs-utils
#openjdk-8-jre

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
curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.3.1-amd64.deb
sudo dpkg -i filebeat-7.3.1-amd64.deb
filebeat setup
systemctl enable filebeat.service
systemctl start filebeat.service
rm filebeat-*
    
htpasswd -b -c /etc/nginx/htpasswd.users $nginxUsername $passvar1 
    
cp /etc/nginx/sites-available/default /etc/nginx/sites-available/backup_default
sudo truncate -s 0 /etc/nginx/sites-available/default


sed -i '226s/.*/subjectAltName = IP: '"$HOSTIPADDR"'/' /etc/ssl/openssl.cnf
# Generate SSL Certificates
mkdir -p /etc/pki/tls/certs
mkdir /etc/pki/tls/private
cd /etc/pki/tls; sudo openssl req -subj '/CN='$HOSTIPADDR'/' -x509 -days 3650 -batch -nodes -newkey rsa:2048 -keyout private/ELK-Stack.key -out certs/ELK-Stack.crt

newDefault="
    server {
        listen 80 default_server; # Listen on port 80
        server_name ""$HOSTIPADDR""; # Bind to the IP address of the server
        return         301 https://\$server_name\$request_uri; # Redirect to 443/SSL
   }
    server {
        listen 443 default ssl; # Listen on 443/SSL
        # SSL Certificate, Key and Settings
        ssl_certificate /etc/pki/tls/certs/ELK-Stack.crt ;
        ssl_certificate_key /etc/pki/tls/private/ELK-Stack.key;
        ssl_session_cache shared:SSL:10m;
        # Basic authentication using the account created with htpasswd
        auth_basic \"Restricted Access\";
        auth_basic_user_file /etc/nginx/htpasswd.users;
        location / {
     # Proxy settings pointing to the Kibana instance
            proxy_pass http://localhost:5601;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_cache_bypass \$http_upgrade;
        }
    }
"
echo "$newDefault" >> /etc/nginx/sites-available/default


systemctl restart nginx

mkdir /logstash
mkdir /logstash/eventlogs
chmod 777 /logstash/eventlogs
cp -pf /etc/samba/smb.conf /etc/samba/smb.conf.bak
cat /dev/null > /etc/samba/smb.conf

echo "[global]" > /etc/samba/smb.conf
echo "workgroup = WORKGROUP" >> /etc/samba/smb.conf
echo "server string = SOF-ELK Server %v" >> /etc/samba/smb.conf
echo "netbios name = sof-elk" >> /etc/samba/smb.conf
echo "security = user" >> /etc/samba/smb.conf
echo "map to guest = bad user" >> /etc/samba/smb.conf
echo "dns proxy = no" >> /etc/samba/smb.conf
echo "[Anonymous]" >> /etc/samba/smb.conf
echo "path = /logstash" >> /etc/samba/smb.conf
echo "browsable =yes" >> /etc/samba/smb.conf
echo "writable = yes" >> /etc/samba/smb.conf
echo "guest ok = yes" >> /etc/samba/smb.conf
echo "read only = no" >> /etc/samba/smb.conf

service smbd restart
#Extras if you want
#/usr/share/elasticsearch/bin/elasticsearch-plugin install --silent --batch ingest-geoip ingest-user-agent 
#/usr/share/logstash/bin/logstash-plugin install logstash-filter-dns --silent
