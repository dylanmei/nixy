# docker.artifactory.amer.gettywan.com/bowie/nixy:dev
FROM alpine:3.3

ENV NGINX_VERSION 1.9.11

ENV GPG_KEYS B0F4253373F8F6F510D42178520A9993A1C052F8
ENV CONFIG "\
	--prefix=/etc/nginx \
	--sbin-path=/usr/sbin/nginx \
	--conf-path=/etc/nginx/nginx.conf \
	--error-log-path=/var/log/nginx/error.log \
	--http-log-path=/var/log/nginx/access.log \
	--pid-path=/var/run/nginx.pid \
	--lock-path=/var/run/nginx.lock \
	--http-client-body-temp-path=/var/cache/nginx/client_temp \
	--http-proxy-temp-path=/var/cache/nginx/proxy_temp \
	--http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
	--http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
	--http-scgi-temp-path=/var/cache/nginx/scgi_temp \
	--user=nginx \
	--group=nginx \
	--with-http_ssl_module \
	--with-http_realip_module \
	--with-http_addition_module \
	--with-http_sub_module \
#	--with-http_dav_module \
#	--with-http_flv_module \
#	--with-http_mp4_module \
	--with-http_gunzip_module \
	--with-http_gzip_static_module \
	--with-http_random_index_module \
	--with-http_secure_link_module \
	--with-http_stub_status_module \
	--with-http_auth_request_module \
#	--with-mail \
#	--with-mail_ssl_module \
#	--with-file-aio \
#  --with-http_spdy_module \
	--with-ipv6 \
  --add-module=/usr/src/nginx-statsd-master \
	"

RUN addgroup -S nginx \
 && adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx \
 && apk add --no-cache --virtual .build-deps \
    gcc \
    libc-dev \
    make \
    openssl-dev \
    pcre-dev \
    zlib-dev \
    linux-headers \
    curl \
    gnupg \
 && curl -fSL http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz -o nginx.tar.gz \
 && curl -fSL http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz.asc  -o nginx.tar.gz.asc \
 && curl -fSL https://github.com/zebrafishlabs/nginx-statsd/archive/master.tar.gz -o nginx-statsd.tar.gz \
 && export GNUPGHOME="$(mktemp -d)" \
 && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$GPG_KEYS" \
 && gpg --batch --verify nginx.tar.gz.asc nginx.tar.gz \
 && rm -r "$GNUPGHOME" nginx.tar.gz.asc \
 && mkdir -p /usr/src \
 && tar -zxC /usr/src -f /nginx.tar.gz \
 && rm /nginx.tar.gz \
 && tar -zxC /usr/src -f /nginx-statsd.tar.gz \
 && rm /nginx-statsd.tar.gz \
 && cd /usr/src/nginx-$NGINX_VERSION \
 && ./configure $CONFIG --with-debug \
 && make \
 && mv objs/nginx objs/nginx-debug \
 && ./configure $CONFIG \
 && make \
 && make install \
 && rm -rf /etc/nginx/html/ \
 && mkdir /etc/nginx/conf.d/ \
 && mkdir -p /usr/share/nginx/html/ \
 && install -m644 html/index.html /usr/share/nginx/html/ \
 && install -m644 html/50x.html /usr/share/nginx/html/ \
 && install -m755 objs/nginx-debug /usr/sbin/nginx-debug \
 && strip /usr/sbin/nginx* \
 && runDeps="$( \
    scanelf --needed --nobanner /usr/sbin/nginx \
    | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
    | sort -u \
    | xargs -r apk info --installed \
    | sort -u \
    )" \
 && apk add --virtual .nginx-rundeps $runDeps \
 && apk del .build-deps \
 && rm -rf /usr/src/nginx-$NGINX_VERSION \
 && rm -rf /usr/src/nginx-statsd-master \
 && apk add --no-cache gettext \
 \
 # forward request and error logs to docker log collector
 && ln -sf /dev/stdout /var/log/nginx/access.log \
 && ln -sf /dev/stderr /var/log/nginx/error.log

RUN apk --update add --no-cache supervisor

#ENV NIXY_VERSION=0.4.9
# has trouble with dns; using release instead
#RUN apk -U add --no-cache go git \
# && mkdir -p /usr/src/go \
# && mkdir -p /etc/nixy \
# && git clone https://github.com/martensson/nixy /usr/src/go/src/github.com/martensson/nixy \
# && cd /usr/src/go/src/github.com/martensson/nixy \
# && git checkout v${NIXY_VERSION} \
# && export GOPATH=/usr/src/go \
# && go get -v \
# && go build -o /bin/nixy \
# && rm -rf /usr/src/go \
# && apk del --purge go git

#ADD https://github.com/martensson/nixy/releases/download/v${NIXY_VERSION}/nixy_${NIXY_VERSION}_linux_amd64.tar.gz /tmp
#RUN mkdir -p /etc/nixy \
# && tar -xzvf /tmp/nixy_${NIXY_VERSION}_linux_amd64.tar.gz -C /tmp/ \
# && mv /tmp/nixy_${NIXY_VERSION}_linux_amd64/nixy /bin/nixy \
# && chmod +x /bin/nixy \
# && rm -rf /tmp/*
COPY bin/nixy /bin/nixy

#CMD ["nginx", "-g", "daemon off;"]
CMD ["/nixy.sh"]

COPY nixy.sh          /nixy.sh
COPY nginx.conf       /etc/nginx/nginx.conf
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY nixy.toml        /etc/nixy/nixy.toml
COPY nginx.tmpl       /etc/nixy/nginx.tmpl
