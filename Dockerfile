FROM alpine:edge
MAINTAINER Lovro Predovan <lovro.predovan@gmail.com>

# Environments
ENV TIMEZONE            Europe/Zagreb
ENV PHP_MEMORY_LIMIT    512M
ENV MAX_UPLOAD          50M
ENV PHP_MAX_FILE_UPLOAD 200
ENV PHP_MAX_POST        100M

RUN	echo "http://dl-cdn.alpinelinux.org/alpine/v3.5/community/" >> /etc/apk/repositories && \
    apk update && \
	apk upgrade && \
	apk add --update tzdata && \
	cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime && \
	echo "${TIMEZONE}" > /etc/timezone && \
	apk add --update \
	    nginx \
    	bash \
    	supervisor \
    	curl \
	    git\
	    autoconf\
	    build-base\
	    php7 \
	    php7-dev \
		php7-mcrypt \
		php7-openssl \
		php7-pdo_odbc \
		php7-json \
		php7-dom \
		php7-pdo \
		php7-mysqli \
		php7-bcmath \
		php7-gd \
		php7-pdo_mysql \
		php7-mbstring \
		php7-curl \
		php7-ctype \
		php7-fpm \
		php7-phar \
		alpine-sdk

# Set configuration
RUN	sed -i "s|;*daemonize\s*=\s*yes|daemonize = no|g" /etc/php7/php-fpm.conf
RUN	sed -i "s|;*listen\s*=\s*127.0.0.1:9000|listen = 9000|g" /etc/php7/php-fpm.d/www.conf
RUN	sed -i "s|;*listen\s*=\s*/||g" /etc/php7/php-fpm.d/www.conf
RUN	sed -i "s|;*date.timezone =.*|date.timezone = ${TIMEZONE}|i" /etc/php7/php.ini
RUN	sed -i "s|;*memory_limit =.*|memory_limit = ${PHP_MEMORY_LIMIT}|i" /etc/php7/php.ini
RUN sed -i "s|;*upload_max_filesize =.*|upload_max_filesize = ${MAX_UPLOAD}|i" /etc/php7/php.ini
RUN sed -i "s|;*max_file_uploads =.*|max_file_uploads = ${PHP_MAX_FILE_UPLOAD}|i" /etc/php7/php.ini
RUN sed -i "s|;*post_max_size =.*|post_max_size = ${PHP_MAX_POST}|i" /etc/php7/php.ini
RUN sed -i "s|;*cgi.fix_pathinfo=.*|cgi.fix_pathinfo= 0|i" /etc/php7/php.ini

# Rename phpconfig to avoid namespace collisions
RUN cp ./usr/bin/php-config7 /usr/bin/php-config
RUN cp ./usr/bin/phpize7 /usr/bin/phpize

# Get composer
RUN rm /var/cache/apk/* && \
	curl -sS https://getcomposer.org/installer | php7 -- --install-dir=/usr/bin --filename=composer

RUN git clone --depth=1 git://github.com/phalcon/cphalcon.git /usr/local/src/cphalcon

#Compile phalcon
RUN cd /usr/local/src/cphalcon/build/php7/safe && \
    export CFLAGS="-O2 -fvisibility=hidden" && \
    phpize && \
    ./configure --enable-phalcon && \
    make && \
    make install

# Configure nginx
RUN rm /etc/nginx/conf.d/default.conf
COPY config/nginx.conf /etc/nginx/nginx.conf

# Configure PHP-FPM
COPY config/fpm-pool.conf /etc/php7/php-fpm.d/zzz_custom.conf
COPY config/php.ini /etc/php7/conf.d/zzz_custom.ini

# Configure supervisord
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

RUN mkdir -p /var/www/html
WORKDIR /var/www/html
VOLUME /var/www/html/

# Expose Ports
EXPOSE 443 80

# Start Supervisord
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]