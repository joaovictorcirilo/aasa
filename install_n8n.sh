#!/bin/bash

# Função para exibir mensagens de status
status() {
    echo -e "\n\e[1m$1\e[0m\n"
}

# Atualizar pacotes do Ubuntu
status "Atualizando pacotes do Ubuntu..."
sudo apt update
sudo apt upgrade -y

# Solicitação do subdomínio
read -p "Por favor, insira o subdomínio para instalar o n8n: " subdominio

# Instalação do Node.js 18
status "Instalando Node.js 18..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Instalação do npm patch-package
status "Instalando npm patch-package..."
sudo npm install -g patch-package

# Instalação do n8n
status "Instalando n8n..."
sudo npm install n8n@latest -g

# Criação do arquivo ecosystem.config.js
status "Configurando n8n..."
sudo tee /usr/lib/node_modules/n8n/ecosystem.config.js <<EOF
module.exports = {
    apps : [{
        name   : "n8n",
        script : "n8n",
        cwd    : "/usr/lib/node_modules/n8n",
        env: {
            N8N_PROTOCOL: "https",
            WEBHOOK_TUNNEL_URL: "https://$subdominio/",
            N8N_HOST: "$subdominio"
        }
    }]
}
EOF

# Instalação do PM2
status "Instalando PM2..."
sudo npm install pm2@latest -g

# Instalação do Nginx
status "Instalando Nginx..."
sudo apt-get install -y nginx

# Configuração do Nginx
status "Configurando Nginx..."
sudo tee /etc/nginx/sites-available/n8n <<EOF
server {
    listen 80;
    server_name $subdominio;

    location / {
        proxy_pass http://localhost:5678;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/

# Reinicie o Nginx para aplicar as alterações
status "Reiniciando Nginx..."
sudo systemctl restart nginx

# Instalação do Certbot e plugins do Nginx
status "Instalando Certbot e plugins do Nginx..."
sudo apt-get install -y certbot python3-certbot-nginx

# Solicitação do email para o certificado SSL
read -p "Por favor, insira seu endereço de e-mail para instalar o certificado SSL: " email

# Solicitação e configuração do certificado SSL com o Certbot
status "Configurando certificado SSL..."
sudo certbot --nginx -d $subdominio --email $email

# Iniciar o n8n com PM2
status "Iniciando n8n com PM2..."
pm2 start /usr/lib/node_modules/n8n/ecosystem.config.js

# Mensagem final
clear
echo -e "\n\e[32mInstalação concluída com sucesso!\e[0m"
echo "-------------------------------------"
echo "Você pode acessar o n8n através da seguinte URL:"
echo -e "\n\e[34mhttps://$subdominio\e[0m\n"
