# Copyright (C) 2011-2016 Nginx, Inc.
# All rights reserved.

# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.

# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

FROM nginx:mainline as builder

ARG ENABLED_MODULES

RUN set -ex \
    && if [ "$ENABLED_MODULES" = "" ]; then \
    echo "No additional modules enabled, exiting"; \
    exit 1; \
    fi

COPY ./ /modules/

RUN set -ex \
    && apt update \
    && apt install -y --no-install-suggests --no-install-recommends \
    patch make wget mercurial devscripts debhelper dpkg-dev \
    quilt lsb-release build-essential libxml2-utils xsltproc \
    equivs git g++ \
    && hg clone -r ${NGINX_VERSION}-${PKG_RELEASE%%~*} https://hg.nginx.org/pkg-oss/ \
    && cd pkg-oss \
    && mkdir /tmp/packages \
    && for module in $ENABLED_MODULES; do \
    echo "Building $module for nginx-$NGINX_VERSION"; \
    if [ -d /modules/$module ]; then \
    echo "Building $module from user-supplied sources"; \
    # check if module sources file is there and not empty
    if [ ! -s /modules/$module/source ]; then \
    echo "No source file for $module in modules/$module/source, exiting"; \
    exit 1; \
    fi; \
    # some modules require build dependencies
    if [ -f /modules/$module/build-deps ]; then \
    echo "Installing $module build dependencies"; \
    apt update && apt install -y --no-install-suggests --no-install-recommends $(cat /modules/$module/build-deps | xargs); \
    fi; \
    # if a module has a build dependency that is not in a distro, provide a
    # shell script to fetch/build/install those
    # note that shared libraries produced as a result of this script will
    # not be copied from the builder image to the main one so build static
    if [ -x /modules/$module/prebuild ]; then \
    echo "Running prebuild script for $module"; \
    /modules/$module/prebuild; \
    fi; \
    /pkg-oss/build_module.sh -v $NGINX_VERSION -f -y -o /tmp/packages -n $module $(cat /modules/$module/source); \
    BUILT_MODULES="$BUILT_MODULES $(echo $module | tr '[A-Z]' '[a-z]' | tr -d '[/_\-\.\t ]')"; \
    elif make -C /pkg-oss/debian list | grep -P "^$module\s+\d" > /dev/null; then \
    echo "Building $module from pkg-oss sources"; \
    cd /pkg-oss/debian; \
    make rules-module-$module BASE_VERSION=$NGINX_VERSION NGINX_VERSION=$NGINX_VERSION; \
    mk-build-deps --install --tool="apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends --yes" debuild-module-$module/nginx-$NGINX_VERSION/debian/control; \
    make module-$module BASE_VERSION=$NGINX_VERSION NGINX_VERSION=$NGINX_VERSION; \
    find ../../ -maxdepth 1 -mindepth 1 -type f -name "*.deb" -exec mv -v {} /tmp/packages/ \;; \
    BUILT_MODULES="$BUILT_MODULES $module"; \
    else \
    echo "Don't know how to build $module module, exiting"; \
    exit 1; \
    fi; \
    done \
    && echo "BUILT_MODULES=\"$BUILT_MODULES\"" > /tmp/packages/modules.env

FROM nginx:mainline
COPY --from=builder /tmp/packages /tmp/packages
RUN set -ex \
    && apt update \
    && . /tmp/packages/modules.env \
    && for module in $BUILT_MODULES; do \
    apt install --no-install-suggests --no-install-recommends -y /tmp/packages/nginx-module-${module}_${NGINX_VERSION}*.deb; \
    done \
    && rm -rf /tmp/packages \
    && rm -rf /var/lib/apt/lists/


# From here updated by SSKGo
# Prepare for amazon-kinesis-video-streams-producer-sdk-cpp
# More detail: https://github.com/awslabs/amazon-kinesis-video-streams-producer-sdk-cpp
ARG KVS_SDK_VERSION
COPY ./nginx/opt/ /opt/
RUN set -ex \
    && apt update && apt upgrade \
    && apt-get install -y cmake build-essential libpcre3 libpcre3-dev libssl-dev zlib1g-dev \
    && apt-get install -y libssl-dev libcurl4-openssl-dev liblog4cplus-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev gstreamer1.0-plugins-base-apps gstreamer1.0-plugins-bad gstreamer1.0-plugins-good gstreamer1.0-plugins-ugly gstreamer1.0-tools \
    && apt-get install -y m4 git jq \
    && if [ -z $KVS_SDK_VERSION ]; then \
    cd /opt ;\
    git clone https://github.com/awslabs/amazon-kinesis-video-streams-producer-sdk-cpp.git; \
    else \
    cd /opt ;\
    curl -LO "https://github.com/awslabs/amazon-kinesis-video-streams-producer-sdk-cpp/archive/refs/tags/v${KVS_SDK_VERSION}.tar.gz"; \
    tar -zxvf "v${KVS_SDK_VERSION}.tar.gz"; \
    rm "v${KVS_SDK_VERSION}.tar.gz"; \
    mv "amazon-kinesis-video-streams-producer-sdk-cpp-${KVS_SDK_VERSION}/" "amazon-kinesis-video-streams-producer-sdk-cpp/"; \
    fi; \
    mkdir -p "amazon-kinesis-video-streams-producer-sdk-cpp/build" \
    && cd "amazon-kinesis-video-streams-producer-sdk-cpp/build" \
    && cmake -DBUILD_GSTREAMER_PLUGIN=TRUE .. \
    && make \
    && chown nobody:nogroup /opt/kvs-streamer.sh \
    && chmod u+x /opt/kvs-streamer.sh \
    && mkdir -p /var/log/nginx
COPY ./nginx/nginx.conf /etc/nginx/nginx.conf
