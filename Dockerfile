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
	&& go get github.com/$CADDY_REPO_OWNER/$CADDY_REPO_NAME/...

FROM alpine:latest
MAINTAINER miniers <m@minier.cc>

ARG S6_OVERLAY_VERSION=v1.19.1.1 

ENV DOCKER_GEN_VERSION 0.7.3
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
COPY --from=build-env /gopath/bin/caddy /usr/bin/caddy

RUN chmod 0755 /usr/bin/caddy \
 && /usr/bin/caddy -version

# install docker-gen
RUN curl -sL docker-gen-linux-amd64-$DOCKER_GEN_VERSION.tar.gz https://github.com/jwilder/docker-gen/releases/download/$DOCKER_GEN_VERSION/docker-gen-linux-amd64-$DOCKER_GEN_VERSION.tar.gz | \
    tar -C /usr/local/bin -xvzf -

ADD root /

EXPOSE 80 443 2015

ENTRYPOINT ["/init"]