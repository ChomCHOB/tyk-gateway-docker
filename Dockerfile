FROM alpine:3.6

ENV ALPINE_VERSION="3.6" \
  GOLANG_VERSION="1.8.3"

LABEL \
  Description="Tyk Gateway docker image" \
  Vendor="Tyk" \
  Version=$TYKVERSION

# install go
# https://github.com/docker-library/golang
RUN apk add --no-cache ca-certificates

# https://golang.org/issue/14851 (Go 1.8 & 1.7)
# https://golang.org/issue/17847 (Go 1.7)
COPY *.patch /go-alpine-patches/

RUN set -eux; \
	apk add --no-cache --virtual .build-deps \
		bash \
		gcc \
		musl-dev \
		openssl \
    go \
	; \
	export \
    # set GOROOT_BOOTSTRAP such that we can actually build Go
		GOROOT_BOOTSTRAP="$(go env GOROOT)" \
    # ... and set "cross-building" related vars to the installed system's values so that we create a build targeting the proper arch
    # (for example, if our build host is GOARCH=amd64, but our build env/image is GOARCH=386, our build needs GOARCH=386)
		GOOS="$(go env GOOS)" \
		GOARCH="$(go env GOARCH)" \
		GO386="$(go env GO386)" \
		GOARM="$(go env GOARM)" \
		GOHOSTOS="$(go env GOHOSTOS)" \
		GOHOSTARCH="$(go env GOHOSTARCH)" \
	; \
	\
	wget -O go.tgz "https://golang.org/dl/go$GOLANG_VERSION.src.tar.gz"; \
	echo '5f5dea2447e7dcfdc50fa6b94c512e58bfba5673c039259fd843f68829d99fa6 *go.tgz' | sha256sum -c -; \
	tar -C /usr/local -xzf go.tgz; \
	rm go.tgz; \
	\
	cd /usr/local/go/src; \
	for p in /go-alpine-patches/*.patch; do \
		[ -f "$p" ] || continue; \
		patch -p2 -i "$p"; \
	done; \
	./make.bash; \
	\
  # clean up
  rm -rf /go-alpine-patches; \
  apk del .build-deps; \
  rm -rf /tmp/*; \
  \
  export PATH="/go/bin:/usr/local/go/bin:$PATH"; \
  mkdir -p "/go/src" "/go/bin" && chmod -R 777 "/go"; \
	go version;

ENV GOPATH="/go" \
    PATH="$GOPATH/bin:/usr/local/go/bin:$PATH"

# install python 3.4 and protobuf
# https://github.com/jfloff/alpine-python
ENV PACKAGES="\
  curl \
  musl \
  linux-headers \
  build-base \
  bash \
  git \
  openssl \
  autoconf \
  automake \
  libtool \
  python3.4 \
  python3.4-dev \
" \
  PROTOVERSION="3.3.2"
  
RUN set -ex; \
  # replacing default repositories with edge ones
  echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" > /etc/apk/repositories \
  && echo "http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories \
  && echo "http://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories; \
  \
  # Add the packages, with a CDN-breakage fallback if needed
  apk add --no-cache $PACKAGES || \
    (sed -i -e 's/dl-cdn/dl-4/g' /etc/apk/repositories && apk add --no-cache $PACKAGES); \
  \
  # turn back the clock -- so hacky!
  echo "http://dl-cdn.alpinelinux.org/alpine/v$ALPINE_VERSION/main" > /etc/apk/repositories; \
  echo "http://dl-cdn.alpinelinux.org/alpine/v$ALPINE_VERSION/community" >> /etc/apk/repositories; \
  \
  # make some useful symlinks that are expected to exist
  if [[ ! -e /usr/bin/python ]];        then ln -sf /usr/bin/python3.4 /usr/bin/python; fi \
  && if [[ ! -e /usr/bin/python-config ]]; then ln -sf /usr/bin/python3.4-config /usr/bin/python-config; fi \
  && if [[ ! -e /usr/bin/idle ]];          then ln -sf /usr/bin/idle3.4 /usr/bin/idle; fi \
  && if [[ ! -e /usr/bin/pydoc ]];         then ln -sf /usr/bin/pydoc3.4 /usr/bin/pydoc; fi \
  && if [[ ! -e /usr/bin/easy_install ]];  then ln -sf /usr/bin/easy_install-3.4 /usr/bin/easy_install; fi \
  \
  # Install and upgrade Pip
  && easy_install pip \
  && pip install --upgrade pip \
  && if [[ ! -e /usr/bin/pip ]]; then ln -sf /usr/bin/pip3.4 /usr/bin/pip; fi; \
  \
  # install protobuf
  if ! curl -fL -o /protobuf-$PROTOVERSION.tar.gz "https://github.com/google/protobuf/archive/v$PROTOVERSION.tar.gz"; then \
    echo >&2 "error: failed to download 'protobuf-$PROTOVERSION' from github"; \
    exit 1; \
  fi; \
  cd / && tar -xzf protobuf-$PROTOVERSION.tar.gz; \
  cd /protobuf-$PROTOVERSION/; \
  ./autogen.sh; \
  ./configure -prefix=/usr; \
  make; \
  make check; \
  make install; \
  \
  cd /protobuf-$PROTOVERSION/python \
    && python setup.py build --cpp_implementation \
    && python setup.py install --cpp_implementation \
  \
  # install grpcio
  python --version; \
  pip install grpcio; \
  \
  # clean up
  apk del $PACKAGES; \
  cd / && rm -rf /protobuf-$PROTOVERSION && rm -f /protobuf-python-$PROTOVERSION.tar.gz;


# install lua luarock
# https://github.com/akornatskyy/docker-library
ENV LUAROCKS_VERSION="2.4.2" \
  LUA_VERSION="5.1.5" 

RUN set -ex; \
  \
  apk add --no-cache --virtual .build-deps \
      make \
      gcc \
      libc-dev \
      openssl \
      curl \
      unzip \
  ; \
  \
  # install lua
  wget -c https://www.lua.org/ftp/lua-${LUA_VERSION}.tar.gz \
      -O - | tar -xzf - \
  \
  && cd lua-${LUA_VERSION} \
  && make -j"$(nproc)" posix \
  && make install \
  && cd .. \
  && rm -rf lua-${LUA_VERSION}; \
  \
  # install luarocks
  wget -c https://github.com/luarocks/luarocks/archive/v${LUAROCKS_VERSION}.tar.gz \
      -O - | tar -xzf - \
  \
  && cd luarocks-${LUAROCKS_VERSION} \
  && ./configure --with-lua=/usr/local \
  && make build \
  && make install \
  && cd .. \
  && rm -rf luarocks-${LUAROCKS_VERSION}; \
  \
  # install lua-cjson
  luarocks install lua-cjson; \
  \
  apk del .build-deps; \
  rm -rf ~/.cache/luarocks;

# build tyk-gateway
ENV TYKVERSION="2.3.8" \
  TYKLANG="" \
  TYKLISTENPORT="8080" \
  TYKSECRET="352d20ee67be67f6340b4c0605b044b7" \
  DEST_BUILD_DIR="/opt/tyk-gateway"

RUN set -ex; \
  apk add --no-cache --update \
    libstdc++ \
    tini \
  ; \
  \
  apk add --no-cache --virtual .build-deps \
    make \
    gcc \
    libc-dev \
    openssl \
    curl \
    unzip \
  ; \
  # if ! curl -fL -o /tmp/${TYKVERSION}.tar.gz "https://github.com/TykTechnologies/tyk/archive/v${TYKVERSION}.tar.gz"; then \
  #   echo >&2 "error: failed to download 'tyk-gateway-${TYKVERSION}' from github"; \
  #   exit 1; \
  # fi; \
  # tar -zxf /tmp/${TYKVERSION}.tar.gz -C /tmp; \
  # cd /tmp/tyk-${TYKVERSION}; \
  # \ 
#   # patch tyk for 2.3.8
#   sed -i '40 s/^/\/\//' main.go; \
#   sed -i '815 s/^/\/\//' main.go; \
#   sed -i '832 s/^/\/\//' main.go; \
#   sed -i '847 s/^/\/\//' main.go; \
#   sed -i '864 s/^/\/\//' main.go; \
#   sed -i '874 s/^/\/\//' main.go; \
#   sed -i '358,361 s/^/\/\//' plugins.go; \
#   \
#   # build tyk
#   go get -t -d -v; \    
#   go build -o build/tyk -v; \
#   cp build/tyk /usr/local/bin/tyk; \
  # deploy
  \
  mkdir -p ${DEST_BUILD_DIR} \
  && mkdir -p ${DEST_BUILD_DIR}/apps \
  && mkdir -p ${DEST_BUILD_DIR}/js \
  && mkdir -p ${DEST_BUILD_DIR}/middleware \
  && mkdir -p ${DEST_BUILD_DIR}/middleware/python \
  && mkdir -p ${DEST_BUILD_DIR}/middleware/lua \
  && mkdir -p ${DEST_BUILD_DIR}/event_handlers \
  && mkdir -p ${DEST_BUILD_DIR}/event_handlers/sample \
  && mkdir -p ${DEST_BUILD_DIR}/templates \
  && mkdir -p ${DEST_BUILD_DIR}/policies; \
#   \
#   cp ./build/tyk ${DEST_BUILD_DIR}/tyk \
#   && cp ./apps/app_sample.json ${DEST_BUILD_DIR}/apps/ \
#   && cp ./templates/*.json ${DEST_BUILD_DIR}/templates/ \
#   && cp ./middleware/*.js ${DEST_BUILD_DIR}/middleware/ \
#   && cp ./event_handlers/sample/*.js ${DEST_BUILD_DIR}/event_handlers/sample/ \
#   && cp ./js/*.js ${DEST_BUILD_DIR}/js/ \
#   && cp ./policies/*.json ${DEST_BUILD_DIR}/policies/ \
#   && cp ./tyk.conf.example ${DEST_BUILD_DIR}/ \
#   && cp ./tyk.conf.example ${DEST_BUILD_DIR}/tyk.conf \
#   && cp -R ./coprocess ${DEST_BUILD_DIR}/; \
  \
  # clean up
  apk del .build-deps; \
  rm -rf /usr/local/go/*; \
  rm -rf /go/*;

COPY ["tyk.conf", "entrypoint.sh", "/opt/tyk-gateway/"]

RUN chmod +x /opt/tyk-gateway/entrypoint.sh

# WORKDIR ${DEST_BUILD_DIR}/

EXPOSE $TYKLISTENPORT

ENTRYPOINT ["/sbin/tini", "--"]

CMD ["/opt/tyk-gateway/entrypoint.sh"]
