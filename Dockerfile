FROM golang:alpine3.14 AS hapttic

RUN apk upgrade --update --no-cache && \
    apk add git && \
    git clone https://github.com/jsoendermann/hapttic.git && \
    cd hapttic/ && \
    go mod init github.com/jsoendermann/hapttic && \
    go build -o hapttic .

FROM alpine:3.14 AS docker-tc

COPY --from=hapttic /go/hapttic/hapttic /usr/bin/hapttic
RUN hapttic -version && \
    apk upgrade --update --no-cache && \
    apk add --no-cache --update \
        bash docker iproute2 iptables iperf iputils \
        curl jq \
        && \
    rm -rf /var/cache/apk/* && \
    mkdir -p /var/docker-tc && \
    chmod +x /usr/bin/hapttic

RUN arch=; case $(apk --print-arch) in x86_64|amd64) arch="amd64";; aarch64) arch="aarch64";; esac; curl -s -L https://github.com/just-containers/s6-overlay/releases/download/v2.2.0.3/s6-overlay-$arch.tar.gz -o /tmp/s6overlay.tar.gz && \
    tar xzf /tmp/s6overlay.tar.gz -C / && \
    rm /tmp/s6overlay.tar.gz && \
    rm -rf /etc/services.d /etc/cont-init.d /etc/cont-finish.d && \
    ln -sf /docker-tc/etc/services.d /etc && \
    ln -sf /docker-tc/etc/cont-init.d /etc && \
    ln -sf /docker-tc/etc/cont-finish.d /etc

ENTRYPOINT ["/init"]
EXPOSE 80/tcp
VOLUME ["/var/docker-tc"]
ARG VERSION=dev
ARG VCS_REF
ARG BUILD_DATE
ENV DOCKER_TC_VERSION="${VERSION:-dev}" \
    HTTP_BIND=127.0.0.1 \
    HTTP_PORT=4080 \
    S6_KILL_GRACETIME=0 \
    S6_KILL_FINISH_MAXTIME=0 \
    S6_KEEP_ENV=1 \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2
LABEL org.opencontainers.image.title="docker-tc" \
        org.opencontainers.image.description="Docker Traffic Control" \
        org.opencontainers.image.version=${VERSION} \
        org.opencontainers.image.revision=${VCS_REF} \
        org.opencontainers.image.created=${BUILD_DATE} \
        com.docker-tc.enabled=0 \
        com.docker-tc.self=1

ADD . /docker-tc