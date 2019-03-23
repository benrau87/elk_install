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

#Sources
add-apt-repository ppa:webupd8team/java
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

apt-get install -y nginx apache2-utils
    
htpasswd -b -c /etc/nginx/htpasswd.users $nginxUsername $passvar1 
    
cp /etc/nginx/sites-available/default /etc/nginx/sites-available/backup_default
sudo truncate -s 0 /etc/nginx/sites-available/default

HOSTIPADDR=$(ifconfig | awk '/inet addr/{print substr($2,6)}'| head -n 1)

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

nginx -t
systemctl restart nginx

#Extras if you want
#/usr/share/elasticsearch/bin/elasticsearch-plugin install --silent --batch ingest-geoip ingest-user-agent 
#/usr/share/logstash/bin/logstash-plugin install logstash-filter-dns --silent
