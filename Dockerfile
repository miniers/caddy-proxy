FROM alpine:edge AS build-env

ENV GOPATH /gopath
ENV CADDY_REPO_OWNER mholt
ENV CADDY_REPO_NAME caddy

COPY plugins.txt /plugins

RUN apk add --no-cache musl build-base su-exec libcap tini go git musl \
	&& mkdir -p $GOPATH/src/github.com/$CADDY_REPO_OWNER \
	&& cd $GOPATH/src/github.com/$CADDY_REPO_OWNER \
	&& git clone https://github.com/$CADDY_REPO_OWNER/$CADDY_REPO_NAME \
	&& cd $CADDY_REPO_NAME \
	&& cd caddy/caddymain \
	&& export line="$(grep -n "// This is where other plugins get plugged in (imported)" < run.go | sed 's/^\([0-9]\+\):.*$/\1/')" \
	&& head -n ${line} run.go > newrun.go \
	&& cat /plugins >> newrun.go \
	&& line=`expr $line + 1` \
	&& tail -n +${line} run.go >> newrun.go \
	&& rm -f run.go \
	&& mv newrun.go run.go \
	&& go get github.com/$CADDY_REPO_OWNER/$CADDY_REPO_NAME/... \
	&& cp $GOPATH/bin/caddy /root/caddy \
	&& rm -rf $GOPATH/*

RUN mkdir -p $GOPATH/src/github.com/miniers/docker-gen  \
    && git clone https://github.com/miniers/docker-gen.git $GOPATH/src/github.com/miniers/docker-gen \
    && cd $GOPATH/src/github.com/miniers/docker-gen \
    && go get github.com/robfig/glock \
    && $GOPATH/bin/glock sync -n < GLOCKFILE \
    && go get github.com/miniers/docker-gen/... \
	&& cp $GOPATH/bin/docker-gen /root/docker-gen \
	&& rm -rf $GOPATH/*

FROM alpine:latest
MAINTAINER miniers <m@minier.cc>

ARG S6_OVERLAY_VERSION=v1.19.1.1 

ENV CADDY_OPTIONS ""
ENV DOCKER_HOST unix:///tmp/docker.sock

# install s6
RUN apk add --update --no-cache curl tzdata && \
    curl -sSL https://github.com/just-containers/s6-overlay/releases/download/${S6_OVERLAY_VERSION}/s6-overlay-amd64.tar.gz \
    | tar xfz - -C / && \
    cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone && \
    apk del tzdata && \
    rm -rf /var/cache/apk/*


# install caddy
COPY --from=build-env /root/caddy /usr/bin/caddy

# install docker-gen

COPY --from=build-env /root/docker-gen /usr/local/bin/docker-gen

ADD root /

EXPOSE 80 443 2015

ENTRYPOINT ["/init"]