FROM alpine:3.6

ENV GOLANG_VERSION="1.8.3" \
  TYK_VERSION="2.3.8" \
  TYK_LANG="" \
  TYK_LISTEN_PORT="8080" \
  TYK_SECRET="352d20ee67be67f6340b4c0605b044b7" \
  TYK_DEST_DIR="/opt/tyk-gateway"

LABEL \
  Description="Tyk Gateway docker image" \
  Vendor="Tyk" \
  Version=$TYK_VERSION

# install go
# https://github.com/docker-library/golang

# https://golang.org/issue/14851 (Go 1.8 & 1.7)
# https://golang.org/issue/17847 (Go 1.7)
COPY *.patch /go-alpine-patches/

RUN set -eux; \
	apk add --no-cache --virtual .build-deps \
		bash \
		gcc \
		musl-dev \
    ca-certificates \
		openssl \
    go \
    git \
	; \
	# export \
  #   # set GOROOT_BOOTSTRAP such that we can actually build Go
	# 	GOROOT_BOOTSTRAP="$(go env GOROOT)" \
  #   # ... and set "cross-building" related vars to the installed system's values so that we create a build targeting the proper arch
  #   # (for example, if our build host is GOARCH=amd64, but our build env/image is GOARCH=386, our build needs GOARCH=386)
	# 	GOOS="$(go env GOOS)" \
	# 	GOARCH="$(go env GOARCH)" \
	# 	GO386="$(go env GO386)" \
	# 	GOARM="$(go env GOARM)" \
	# 	GOHOSTOS="$(go env GOHOSTOS)" \
	# 	GOHOSTARCH="$(go env GOHOSTARCH)" \
	# ; \
	# \
	# wget -O go.tgz "https://golang.org/dl/go$GOLANG_VERSION.src.tar.gz"; \
	# echo '5f5dea2447e7dcfdc50fa6b94c512e58bfba5673c039259fd843f68829d99fa6 *go.tgz' | sha256sum -c -; \
	# tar -C /usr/local -xzf go.tgz; \
	# rm go.tgz; \
	# \
	# cd /usr/local/go/src; \
	# for p in /go-alpine-patches/*.patch; do \
	# 	[ -f "$p" ] || continue; \
	# 	patch -p2 -i "$p"; \
	# done; \
	# ./make.bash; \
	# \
  # mkdir -p "/go/src" "/go/bin" && chmod -R 777 "/go"; \
  # export GOPATH="/go"; \
  # export PATH="$GOPATH/bin:/usr/local/go/bin:$PATH"; \
	go version; \
  \
  # build tyk-gateway
  wget -O /tmp/${TYK_VERSION}.tar.gz "https://github.com/TykTechnologies/tyk/archive/v${TYK_VERSION}.tar.gz"; \
  tar -zxf /tmp/${TYK_VERSION}.tar.gz -C /tmp; \
  cd /tmp/tyk-${TYK_VERSION}; \
  \ 
   # # patch tyk for 2.3.8
  # sed -i '40 s/^/\/\//' main.go; \
  # sed -i '815 s/^/\/\//' main.go; \
  # sed -i '832 s/^/\/\//' main.go; \
  # sed -i '847 s/^/\/\//' main.go; \
  # sed -i '864 s/^/\/\//' main.go; \
  # sed -i '874 s/^/\/\//' main.go; \
  # sed -i '358,361 s/^/\/\//' plugins.go; \
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
  rm -rf /go/*;

COPY ["tyk.conf", "entrypoint.sh", "/opt/tyk-gateway/"]

RUN chmod +x /opt/tyk-gateway/entrypoint.sh

WORKDIR ${TYK_DEST_DIR}

EXPOSE $TYK_LISTEN_PORT

CMD ["/opt/tyk-gateway/entrypoint.sh"]
