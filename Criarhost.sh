#!/bin/bash

# Pergunta o server name
read -p "Digite o server name: " server_name

# Pergunta o IP e porta do servidor
read -p "Digite o IP do servidor (ou pressione Enter para escutar em todos os endereços IP): " server_ip
read -p "Digite a porta do servidor (padrão: 80): " server_port

# Se o usuário não especificar o IP, usa o valor padrão
if [ -z "$server_ip" ]; then
    server_ip="";
else
    server_ip="$server_ip:";
fi

# Se o usuário não especificar a porta, usa o valor padrão
if [ -z "$server_port" ]; then
    echo "Porta não especificada, utilizando porta padrão 80."
    server_port="80";
else
    echo "Utilizando porta $server_port."
fi

# Pergunta os locations e proxy pass
read -p "Digite o número de locations: " num_locations

# Cria o arquivo de configuração do host
sudo tee /etc/nginx/sites-available/$server_name <<EOF
server {
    listen ${server_ip}${server_port};
    server_name $server_name;

    # Ativa o ModSecurity
    modsecurity on;
    modsecurity_rules_file /etc/nginx/modsec/main.conf;

    # Configura os logs de acesso e erro
    access_log /var/log/nginx/${server_name}_access.log;
    error_log /var/log/nginx/${server_name}_error.log;

EOF

# Loop para adicionar os locations e proxy pass
for ((i=1; i<=$num_locations; i++)); do
    read -p "Digite o location $i (ex: /api): " location

    # Pergunta o protocolo para o proxy pass
    echo "Selecione o protocolo para o proxy pass:"
    echo "1. HTTP"
    echo "2. HTTPS"
    read -p "Digite o número do protocolo: " protocolo

    # Verifica o protocolo selecionado
    case $protocolo in
        1) protocolo="http";;
        2) protocolo="https";;
        *) echo "Protocolo inválido. Usando HTTP como padrão."; protocolo="http";;
    esac

    # Pergunta o IP e porta do proxy pass
    read -p "Digite o IP e porta do proxy pass para o location $location (ex: 127.0.0.1:8080): " proxy_pass

    # Adiciona o location e proxy pass ao arquivo de configuração
    sudo tee -a /etc/nginx/sites-available/$server_name <<EOF
    location $location {
        proxy_pass $protocolo://$proxy_pass;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
EOF
done

# Pergunta se o usuário quer forçar o redirecionamento para HTTPS
read -p "Deseja forçar o redirecionamento para HTTPS? (s/n): " redirecionamento

# Verifica a resposta do usuário
if [ "$redirecionamento" = "s" ]; then
    # Adiciona os parâmetros para forçar o redirecionamento para HTTPS
    sudo tee -a /etc/nginx/sites-available/$server_name <<EOF
    return 301 https://\$host\$request_uri;
EOF
fi

# Explica o que é o HSTS
echo "O HSTS (HTTP Strict Transport Security) é uma tecnologia que força o navegador a usar apenas conexões seguras (HTTPS) para um determinado domínio."

# Pergunta se o usuário quer adicionar o HSTS
read -p "Deseja adicionar o HSTS? (s/n): " hsts

# Verifica a resposta do usuário
if [ "$hsts" = "s" ]; then
    # Adiciona os parâmetros para o HSTS
    sudo tee -a /etc/nginx/sites-available/$server_name <<EOF
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
EOF
fi

# Fecha o bloco do servidor
sudo tee -a /etc/nginx/sites-available/$server_name <<EOF
}
EOF

# Cria o link simbólico para o arquivo de configuração
sudo ln -s /etc/nginx/sites-available/$server_name /etc/nginx/sites-enabled/

# Verifica se o arquivo de configuração está correto
    sudo nginx -t
    if [ $? -eq 0 ]; then
        echo "Arquivo de configuração criado com sucesso!"
    else
        echo "Erro ao criar arquivo de configuração!"
    fi
