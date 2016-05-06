#
# Cookbook Name:: apache2
# Recipe:: default
#

ssl_node = 'apache-chef'
cert_dir = '/etc/apache2/ssl'
hostname = 'localhost'

package 'apache2' do
  action :install
end

directory '/var/www/html' do
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

# template '/var/www/html/index.html' do
#   source 'index.html.erb'
#   owner 'root'
#   group 'root'
#   mode '0644'
# end

file '/var/www/html/index.html' do
  content '<html>
  <body>
    <h1>hello world</h1>
  </body>
  </html>'
  action :create
end

service 'apache2' do
  supports :status => true
  action [:start, :enable]
end

directory "#{cert_dir}" do
  owner 'root'
  group 'root'
  mode '0600'
  action :create
end

script 'generate ssl cert' do
  interpreter 'bash'
  user 'root'
  cwd "#{cert_dir}"
  code <<-EOH

    openssl req \
       -newkey rsa:2048 -sha256 -nodes -keyout #{ssl_node}.key \
       -x509 -days 9000 -out #{ssl_node}.crt \
       -subj "/C=US/ST=California/L=Los Angeles/O=js/CN=#{hostname}"
  EOH
  not_if { ::File.exists?("#{cert_dir}/#{ssl_node}.crt") }
end

script 'enable apache ssl module' do
  interpreter 'bash'
  user 'root'
  cwd '/tmp'
  code <<-EOH
    a2enmod ssl
  EOH
  not_if { ::File.exists?('/etc/apache2/mods-enabled/ssl.conf') }
end

script 'enable apache rewrite module' do
  interpreter 'bash'
  user 'root'
  cwd '/tmp'
  code <<-EOH
    a2enmod rewrite
  EOH
  not_if { ::File.exists?('/etc/apache2/mods-enabled/rewrite.load') }
end

file '/etc/apache2/sites-enabled/default-ssl.conf' do
  action :create
  owner 'root'
  group 'root'
  mode '0644'
  content "<IfModule mod_ssl.c>
    <VirtualHost *:80>
        ServerName #{hostname}
        # Redirect permanent / https://#{hostname}:443
        RewriteEngine On
        RewriteCond %{HTTPS} !on
        RewriteCond %{SERVER_PORT} !443
        RewriteRule ^(/(.*))?$ https://%{HTTP_HOST}/$1 [R=301,L]
    </VirtualHost>

    <VirtualHost _default_:443>
        SSLEngine On
        SSLCertificateFile #{cert_dir}/#{ssl_node}.crt
        SSLCertificateKeyFile #{cert_dir}/#{ssl_node}.key

        ServerAdmin admin@example.com
        ServerName #{hostname}:443
        DocumentRoot /var/www/html
        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined
    </VirtualHost>
</IfModule>"
    notifies :restart, 'service[apache2]'
end

