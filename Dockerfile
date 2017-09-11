FROM alpine:3.6

ENV GOLANG_VERSION="1.8" \
  TYK_VERSION="2.3.8" \
  TYK_LANG="" \
  TYK_LISTEN_PORT="8080" \
  TYK_SECRET="352d20ee67be67f6340b4c0605b044b7" \
  TYK_DEST_DIR="/opt/tyk-gateway"

LABEL \
  Description="Tyk Gateway docker image" \
  Vendor="Tyk" \
  Version=$TYK_VERSION

RUN set -eux; \
  apk add --no-cache tini; \
	apk add --no-cache --virtual .build-deps \
		bash \
		gcc \
		musl-dev \
    ca-certificates \
		openssl \
    go \
    git \
	; \
  \
  # check golang version
  (go version | grep "$GOLANG_VERSION") \
    || (echo >&2 "error: Golang version mismatch" && exit 1); \
  \
  # build tyk-gateway
  wget -O /tmp/${TYK_VERSION}.tar.gz "https://github.com/TykTechnologies/tyk/archive/v${TYK_VERSION}.tar.gz"; \
  tar -zxf /tmp/${TYK_VERSION}.tar.gz -C /tmp; \
  cd /tmp/tyk-${TYK_VERSION}; \
  \
  # patch tyk for 2.3.8
  sed -i '40 s/^/\/\//' main.go; \
  sed -i '815 s/^/\/\//' main.go; \
  sed -i '832 s/^/\/\//' main.go; \
  sed -i '847 s/^/\/\//' main.go; \
  sed -i '864 s/^/\/\//' main.go; \
  sed -i '874 s/^/\/\//' main.go; \
  sed -i '358,361 s/^/\/\//' plugins.go; \
  \
  # build tyk
  go get -t -d -v; \    
  go build -o build/tyk -v; \
  cp build/tyk /usr/local/bin/tyk; \
  \
  # deploy
  mkdir -p ${TYK_DEST_DIR} \
  && mkdir -p ${TYK_DEST_DIR}/apps \
  && mkdir -p ${TYK_DEST_DIR}/js \
  && mkdir -p ${TYK_DEST_DIR}/middleware \
  && mkdir -p ${TYK_DEST_DIR}/middleware/python \
  && mkdir -p ${TYK_DEST_DIR}/middleware/lua \
  && mkdir -p ${TYK_DEST_DIR}/event_handlers \
  && mkdir -p ${TYK_DEST_DIR}/event_handlers/sample \
  && mkdir -p ${TYK_DEST_DIR}/templates \
  && mkdir -p ${TYK_DEST_DIR}/policies; \
  \
  cp ./build/tyk ${TYK_DEST_DIR}/tyk \
  && cp ./apps/app_sample.json ${TYK_DEST_DIR}/apps/ \
  && cp ./templates/*.json ${TYK_DEST_DIR}/templates/ \
  && cp ./middleware/*.js ${TYK_DEST_DIR}/middleware/ \
  && cp ./event_handlers/sample/*.js ${TYK_DEST_DIR}/event_handlers/sample/ \
  && cp ./js/*.js ${TYK_DEST_DIR}/js/ \
  && cp ./policies/*.json ${TYK_DEST_DIR}/policies/ \
  && cp ./tyk.conf.example ${TYK_DEST_DIR}/ \
  && cp ./tyk.conf.example ${TYK_DEST_DIR}/tyk.conf \
  && cp -R ./coprocess ${TYK_DEST_DIR}/; \
  \
  # clean up
  rm -rf /go-alpine-patches; \
  apk del .build-deps; \
  rm -rf /tmp/*; \
  rm -rf /usr/local/go/*; \
  rm -rf /go/*; \
  rm -rf /root/go/*;

COPY ["tyk.conf", "entrypoint.sh", "/opt/tyk-gateway/"]

RUN chmod +x /opt/tyk-gateway/entrypoint.sh

WORKDIR ${TYK_DEST_DIR}

EXPOSE $TYK_LISTEN_PORT

ENTRYPOINT ["/sbin/tini", "--", "/opt/tyk-gateway/entrypoint.sh"]
