#!/bin/bash

# 更新系统
echo "更新系统..."
yum update -y

# 安装 Nginx
echo "安装 Nginx..."
yum install -y epel-release
yum install -y nginx
systemctl start nginx
systemctl enable nginx

# 安装 Remi 仓库
echo "添加 Remi 仓库..."
yum install -y yum-utils
yum install -y https://rpms.remirepo.net/enterprise/remi-release-7.rpm
yum-config-manager --enable remi-php74

# 安装 PHP 7.4 和扩展
echo "安装 PHP 7.4 和常用扩展..."
yum install -y php php-fpm php-mysqlnd php-gd php-mbstring php-xml php-xmlrpc php-opcache php-cli php-redis


# 配置 PHP-FPM
echo "配置 PHP-FPM..."
sed -i 's/^user = apache/user = nginx/' /etc/php-fpm.d/www.conf
sed -i 's/^group = apache/group = nginx/' /etc/php-fpm.d/www.conf
sed -i 's/^listen = 127.0.0.1:9000/listen = \/run\/php-fpm\/www.sock/' /etc/php-fpm.d/www.conf

# 确保 PHP-FPM Socket 权限
echo "调整 PHP-FPM Socket 权限..."
mkdir -p /run/php-fpm
chown nginx:nginx /run/php-fpm/www.sock
chmod 660 /run/php-fpm/www.sock

systemctl start php-fpm
systemctl enable php-fpm


# 下载并解压 WordPress
echo "下载并解压 WordPress..."
cd /var/www/
wget https://wordpress.org/latest.tar.gz
tar -xvf latest.tar.gz
mv wordpress /var/www/html/

# 设置 WordPress 文件权限
echo "设置 WordPress 文件权限..."
chown -R nginx:nginx /var/www/html/wordpress
chmod -R 755 /var/www/html/wordpress

# 配置 WordPress
echo "配置 WordPress..."
cd /var/www/html/wordpress

# 添加 Redis 配置到 wp-config.php
# cat <<EOL >> /var/www/html/wordpress/wp-config.php
echo "添加 Redis 配置到 wp-config.php..."
sed -i "/^\?>/i \
define('WP_REDIS_HOST', '127.0.0.1'); // Redis 主机\ndefine('WP_REDIS_PORT', 6379);        // Redis 端口\ndefine('WP_REDIS_PASSWORD', 'yourpassword'); // 如果有密码\ndefine('WP_REDIS_DATABASE', 0);      // Redis 数据库编号" /var/www/html/wordpress/wp-config.php

# define('WP_REDIS_HOST', '127.0.0.1'); // Redis 主机
# define('WP_REDIS_PORT', 6379);        // Redis 端口
# define('WP_REDIS_PASSWORD', 'yourpassword'); // 如果有密码
# define('WP_REDIS_DATABASE', 0);      // Redis 数据库编号
# EOL


# 配置 Nginx
echo "配置 Nginx..."
cat <<EOL > /etc/nginx/conf.d/wordpress.conf
server {
    listen       80;
    server_name  localhost;

    root   /var/www/html/wordpress;
    index  index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include       fastcgi_params;
        fastcgi_pass  unix:/run/php-fpm/www.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOL

# 测试并重启 Nginx
echo "重启 Nginx..."
nginx -t
systemctl restart nginx

# 调整防火墙
echo "调整防火墙..."
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --reload

echo "WordPress 安装完成！请在浏览器中访问 http://your_server_ip 完成安装配置。"
