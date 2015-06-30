# Use phusion/baseimage as base image. To make your builds reproducible, make
# sure you lock down to a specific version, not to `latest`!
# See https://github.com/phusion/baseimage-docker/blob/master/Changelog.md for
# a list of version numbers.
# 
#This file based on  https://github.com/bobmaerten/docker-wallabag
#
FROM phusion/baseimage:0.9.16
MAINTAINER das-wunder <david.sander@web.de> 

# Set correct environment variables.
ENV HOME /root

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]

# Configure user nobody to match unRAID's settings
 RUN \
 usermod -u 99 nobody && \
 usermod -g 100 nobody && \
 usermod -d /home nobody && \
 chown -R nobody:users /home

# Disable SSH
RUN rm -rf /etc/service/sshd /etc/my_init.d/00_regen_ssh_host_keys.sh

# Install locales
ENV DEBIAN_FRONTEND noninteractive
RUN locale-gen cs_CZ.UTF-8
RUN locale-gen de_DE.UTF-8
RUN locale-gen es_ES.UTF-8
RUN locale-gen fr_FR.UTF-8
RUN locale-gen it_IT.UTF-8
RUN locale-gen pl_PL.UTF-8
RUN locale-gen pt_BR.UTF-8
RUN locale-gen ru_RU.UTF-8
RUN locale-gen sl_SI.UTF-8
RUN locale-gen uk_UA.UTF-8

# Install wallabag prereqs
RUN add-apt-repository ppa:nginx/stable \
    && apt-get update \
    && apt-get install -y \
			nginx \
			php5-cli php5-common php5-sqlite \
			php5-gd php5-mysql php5-curl php5-fpm \
			php5-json php5-tidy \
			wget unzip gettext git \
			mariadb-server \
			xmlstarlet \
			pwgen

# Tweak my.cnf
RUN sed -i -e 's#\(bind-address.*=\).*#\1 0.0.0.0#g' /etc/mysql/my.cnf && \
    sed -i -e 's#\(log_error.*=\).*#\1 /config/databases/mysql_safe.log#g' /etc/mysql/my.cnf && \
    sed -i -e 's/\(user.*=\).*/\1 nobody/g' /etc/mysql/my.cnf && \
    echo '[mysqld]' > /etc/mysql/conf.d/innodb_file_per_table.cnf && \
    echo 'innodb_file_per_table' >> /etc/mysql/conf.d/innodb_file_per_table.cnf



#Configure script which starts and the beginning of the container
COPY firstrun.sh /etc/my_init.d/firstrun.sh

# Configure php-fpm
RUN echo "cgi.fix_pathinfo = 0" >> /etc/php5/fpm/php.ini
COPY www.conf /etc/php5/fpm/pool.d/www.conf

#Configure php5-fpm start script
RUN mkdir /etc/service/php5-fpm
COPY php5-fpm.sh /etc/service/php5-fpm/run

#Configure nginx start script and set daemon mode off
RUN mkdir /etc/service/nginx
COPY nginx.sh /etc/service/nginx/run
RUN echo "daemon off;" >> /etc/nginx/nginx.conf
# Configure nginx to serve wallabag app
COPY nginx-wallabag /etc/nginx/sites-available/default

#Configure mariadb start script
RUN  mkdir /etc/service/mariadb
COPY mariadb.sh /etc/service/mariadb/run



# Wallabag version
ENV WALLABAG_VERSION 1.9

# Extract wallabag code
ADD https://github.com/wallabag/wallabag/archive/$WALLABAG_VERSION.zip /tmp/wallabag-$WALLABAG_VERSION.zip

#Using composer instead of vendor.zip for getting dependencies
RUN cd /tmp && \
    curl -sS https://getcomposer.org/installer | php && \
    mv composer.phar /usr/local/bin/composer

#Create directories for databases and webdata
RUN mkdir -p /var/www /config/databases

RUN cd /var/www \
    && unzip -q /tmp/wallabag-$WALLABAG_VERSION.zip \
    && mv wallabag-$WALLABAG_VERSION wallabag \
    && cd wallabag \ 
    && composer install

COPY wallabagCredentials.dtd /config/wallabagCredentials.dtd

#COPY 99_change_wallabag_config_salt.sh /etc/my_init.d/99_change_wallabag_config_salt.sh

#Remove unneeded downloaded data
RUN rm -f /tmp/wallabag-$WALLABAG_VERSION.zip

#Change permissions for the wallabag web directory
RUN chown -R www-data:www-data /var/www/wallabag
RUN chmod 755 -R /var/www/wallabag

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


#Expose ports for http and https
EXPOSE 80 443

#Export directories for database(config) wallabag(www) and nginx(nginx)
VOLUME ["/config","/var/www/","/etc/nginx"]


