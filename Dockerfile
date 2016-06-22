FROM debian:jessie

# Install runtime packages
RUN apt-get update && apt-get install -y gnutls-bin iptables libev4 libnl-route-3-200 libprotobuf-c1 libseccomp2 libwrap0 openssl --no-install-recommends && rm -rf /var/lib/apt/lists/* 

# NOT FOUND?
# 		libfreeradius-client-dev liblz4-dev libsystemd-daemon-dev
# Use included:
# 		libhttp-parser-dev libpcl1-dev libtalloc-dev

RUN buildDeps=" \
		autoconf \
		autogen \
		ca-certificates \
		curl \
		gcc \
		gperf \
		libev-dev \
		libgnutls28-dev \
		libnl-route-3-dev \
		libpam0g-dev \
		libprotobuf-c-dev \
		libreadline-dev \
		libseccomp-dev \
		libwrap0-dev \
		make \
		pkg-config \
		xz-utils \
	"; \
	set -x \
	&& apt-get update && apt-get install -y $buildDeps --no-install-recommends && rm -rf /var/lib/apt/lists/* \
	&& LZ4_VERSION=`curl "https://github.com/Cyan4973/lz4/releases/latest" | sed -n 's/^.*tag\/\(.*\)".*/\1/p'` \
	&& curl -SL "https://github.com/Cyan4973/lz4/archive/$LZ4_VERSION.tar.gz" -o lz4.tar.gz \
	&& mkdir -p /usr/src/lz4 \
	&& tar -xf lz4.tar.gz -C /usr/src/lz4 --strip-components=1 \
	&& rm lz4.tar.gz \
	&& cd /usr/src/lz4 \
	&& make -j"$(nproc)" \
	&& make install \
	&& curl -SL "ftp://ftp.freeradius.org/pub/freeradius/freeradius-client-1.1.7.tar.gz" -o freeradius-client.tar.gz \
	&& mkdir -p /usr/src/freeradius-client \
	&& tar -xzf freeradius-client.tar.gz -C /usr/src/freeradius-client --strip-components=1 \
	&& rm freeradius-client.tar.gz \
	&& cd /usr/src/freeradius-client \
	&& ./configure --prefix=/usr/local \
	&& make -j"$(nproc)" \
	&& make install \
	&& OC_VERSION=`curl "http://www.infradead.org/ocserv/download.html" | sed -n 's/^.*version is <b>\(.*$\)/\1/p'` \
	&& curl -SL "ftp://ftp.infradead.org/pub/ocserv/ocserv-$OC_VERSION.tar.xz" -o ocserv.tar.xz \
	&& curl -SL "ftp://ftp.infradead.org/pub/ocserv/ocserv-$OC_VERSION.tar.xz.sig" -o ocserv.tar.xz.sig \
	&& gpg --keyserver pgp.mit.edu --recv-key 96865171 \
	&& gpg --verify ocserv.tar.xz.sig \
	&& mkdir -p /usr/src/ocserv \
	&& tar -xf ocserv.tar.xz -C /usr/src/ocserv --strip-components=1 \
	&& rm ocserv.tar.xz* \
	&& cd /usr/src/ocserv \
	&& ./configure \
	&& make -j"$(nproc)" \
	&& make install \
	&& mkdir -p /etc/ocserv \
	&& cp /usr/src/ocserv/doc/sample.config /etc/ocserv/ocserv.conf \
	&& cd / \
	&& rm -fr /usr/src/lz4 \
	&& rm -fr /usr/src/ocserv \
	&& rm -fr /usr/src/freeradius-client \
	&& apt-get purge -y --auto-remove $buildDeps

# Setup config
COPY route.txt /tmp/
RUN set -x \
	&& sed -i 's/\.\.\/tests/\/etc\/ocserv/' /etc/ocserv/ocserv.conf \
	&& sed -i 's/#\(compression.*\)/\1/' /etc/ocserv/ocserv.conf \
	&& sed -i '/^ipv4-network = /{s/192.168.1.0/10.99.99.0/}' /etc/ocserv/ocserv.conf \
	&& sed -i 's/192.168.1.2/8.8.8.8/' /etc/ocserv/ocserv.conf \
	&& sed -i 's/^route/#route/' /etc/ocserv/ocserv.conf \
	&& sed -i 's/^no-route/#no-route/' /etc/ocserv/ocserv.conf \
	&& sed -i '/sample\.passwd/s/^/#/g' /etc/ocserv/ocserv.conf
	&& sed -i 's/^\#auth = \"radius.*/auth = \"radius\[config=\/usr\/local\/etc\/radiusclient\/radiusclient.conf,groupconfig=true\]\"/g' /etc/ocserv/ocserv.conf \
	&& sed -i 's/^\#acct = \"radius.*/acct = \"radius\[config=\/usr\/local\/etc\/radiusclient\/radiusclient.conf\]\"/g' /etc/ocserv/ocserv.conf \
	&& sed -i 's/^\#listen-host.*/listen-host = 192.168.0.10/g' /etc/ocserv/ocserv.conf \
	&& sed -i 's/max-clients = 16/#max-clients = 16/g' /etc/ocserv/ocserv.conf \
	&& sed -i 's/max-same-clients = 2/#max-same-clients = 2/g' /etc/ocserv/ocserv.conf \
	&& sed -i 's/443/4433/g' /etc/ocserv/ocserv.conf \
	&& cat /tmp/route.txt >> /etc/ocserv/ocserv.conf \
	&& rm -fr /tmp/route.txt

WORKDIR /etc/ocserv

COPY docker-entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 4433
CMD ["ocserv", "-c", "/etc/ocserv/ocserv.conf", "-f"]
