ARG CBO_IMAGE_URL=armdocker.rnd.ericsson.se/proj-ldc/common_base_os_release/sles
# CBO PRA version
ARG CBO_VERSION
#####################################################################################################
# CBO base image
#####################################################################################################

FROM ${CBO_IMAGE_URL}:${CBO_VERSION} as cbos

####################################################################################################
# Builder image
# Initial stage which pulls prepares build dependencies and CLI tooling we need for our final image
# Also used as the image in CI jobs so needs all dependencies
####################################################################################################

FROM cbos as builder
ARG CBO_VERSION

# CBO ARM BASE URL
ARG ARM_URL="https://arm.sero.gic.ericsson.se/artifactory/proj-ldc-repo-rpm-local"

# GO_SDK Repo
ARG CBO_REPO="$ARM_URL/common_base_os/sles/$CBO_VERSION"
ARG GO_SDK_REPO="$ARM_URL/adp-dev/go-sdk/$CBO_VERSION"
ARG DEV_REPO="$ARM_URL/adp-dev/adp-build-env/$CBO_VERSION"

# NODE arguments
ARG CBO_NODE_VERSION
ARG CBO_NPM_VERSION
ARG CBO_YARN_VERSION

ARG NPM_REGISTRY=https://arm.seli.gic.ericsson.se/artifactory/api/npm/npm-remote/

RUN zypper addrepo --gpgcheck-strict -f $CBO_REPO COMMON_BASE_OS_SLES_REPO  \
    && zypper addrepo --gpgcheck-strict -f $GO_SDK_REPO GO_SDK_REPO \
    && zypper addrepo --gpgcheck-strict -f $DEV_REPO ADP_DEV_BUILD_ENV_REPO \
    && zypper --gpg-auto-import-keys refresh -f \
    # Installiing generic utilities
    && zypper install -l -y curl git sudo make \
    # Installiing Go libraries
    && zypper install -l -y go1.22* \
    # Installiing Node
    && zypper install -l -y nodejs18=${CBO_NODE_VERSION}* npm18=${CBO_NPM_VERSION}* \
    && npm install -g yarn@"${CBO_YARN_VERSION}" --registry "${NPM_REGISTRY}" \
    && zypper clean --all \
    && zypper rr COMMON_BASE_OS_SLES_REPO GO_SDK_REPO ADP_DEV_BUILD_ENV_REPO

WORKDIR /tmp

COPY hack/install.sh hack/tool-versions.sh ./
COPY hack/installers installers

RUN ./install.sh helm-linux && \
    INSTALL_PATH=/usr/local/bin ./install.sh kustomize

####################################################################################################
# Argo CD Base - used as the base for both the release and dev argocd images
####################################################################################################
FROM cbos AS argocd-base
ARG CBO_VERSION
ARG ARGO_CD_CONTAINER_NAME=eric-aiml-declarative-deployer-argo-cd
ARG ARGOCD_USER_ID

# CBO ARM BASE URL
ARG ARM_URL="https://arm.sero.gic.ericsson.se/artifactory/proj-ldc-repo-rpm-local"
# CBO Repos
ARG CBO_REPO="$ARM_URL/common_base_os/sles/$CBO_VERSION"
ARG DEV_REPO="$ARM_URL/adp-dev/adp-build-env/$CBO_VERSION"

COPY ["hack/gpg-wrapper.sh", "hack/git-verify-wrapper.sh", "entrypoint.sh", "/usr/local/bin/"]
COPY --from=builder ["/usr/local/bin/helm","/usr/local/bin/kustomize", "/usr/local/bin/" ]

RUN set -ex; \
    # 3pp installs packages git git-lfs tini gpg tzdata
    # no equivalent available for git-lfs in CBOS
    # for other packages equivalent in CBOs is git catatonit(preinstalled) gpg2 timezone
    zypper addrepo --gpgcheck-strict -f $CBO_REPO COMMON_BASE_OS_SLES_REPO  \
    && zypper addrepo --gpgcheck-strict -f $DEV_REPO ADP_DEV_BUILD_ENV_REPO \
    && zypper --gpg-auto-import-keys refresh -f \
    && zypper install -l -y git gpg2 timezone \
    && zypper clean --all \
    && zypper rr COMMON_BASE_OS_SLES_REPO ADP_DEV_BUILD_ENV_REPO; \
    # Add user and group for Argo CD
    echo "$ARGOCD_USER_ID:!::0:::::" >>/etc/shadow \
    && echo "$ARGOCD_USER_ID:x:$ARGOCD_USER_ID:0:An Identity for $ARGO_CD_CONTAINER_NAME:/nonexistent:/bin/false" >>/etc/passwd; \
    # keep uid_entrypoint.sh for backward compatibility
    ln -s /usr/local/bin/entrypoint.sh /usr/local/bin/uid_entrypoint.sh; \
    # support for mounting configuration from a configmap
    touch /app/config/ssh/ssh_known_hosts && ln -s /app/config/ssh/ssh_known_hosts /etc/ssh/ssh_known_hosts; \
    mkdir -p /app/config/tls /app/config/gpg/source /app/config/gpg/keys \ 
    && chown $ARGOCD_USER_ID /app/config/gpg/keys \
    && chmod 0700 /app/config/gpg/keys;

# Modified this
ENV USER=$ARGOCD_USER_ID

USER $ARGOCD_USER_ID
WORKDIR /argocd

####################################################################################################
# Argo CD UI stage
####################################################################################################

FROM builder as argocd-ui

WORKDIR /src
COPY ["ui/package.json", "ui/yarn.lock", "./"]

RUN yarn install --network-timeout 200000 && \
    yarn cache clean

COPY ["ui/", "."]

ARG ARGO_VERSION=latest
ENV ARGO_VERSION=$ARGO_VERSION
ARG TARGETARCH
RUN HOST_ARCH=$TARGETARCH NODE_ENV='production' NODE_ONLINE_ENV='online' NODE_OPTIONS=--max_old_space_size=8192 yarn build

####################################################################################################
# Argo CD Build stage which performs the actual build of Argo CD binaries
####################################################################################################
FROM builder AS argocd-build

WORKDIR /go/src/github.com/argoproj/argo-cd

COPY go.* ./
RUN go mod download

# Perform the build
COPY . .
COPY --from=argocd-ui /src/dist/app /go/src/github.com/argoproj/argo-cd/ui/dist/app
ARG TARGETOS
ARG TARGETARCH
# These build args are optional; if not specified the defaults will be taken from the Makefile
ARG GIT_TAG
ARG BUILD_DATE
ARG GIT_TREE_STATE
ARG GIT_COMMIT
RUN GIT_COMMIT=$GIT_COMMIT \
    GIT_TREE_STATE=$GIT_TREE_STATE \
    GIT_TAG=$GIT_TAG \
    BUILD_DATE=$BUILD_DATE \
    GOOS=$TARGETOS \
    GOARCH=$TARGETARCH \
    make argocd-all

####################################################################################################
# Final image
####################################################################################################
FROM argocd-base as argo-cd-final-image

ARG IMAGE_PRODUCT_NUMBER
ARG IMAGE_PRODUCT_TITLE
ARG ARGO_CD_VERSION
ARG APP_VERSION
ARG RSTATE
ARG BUILD_DATE
ARG COMMIT

LABEL \
    org.opencontainers.image.title=$IMAGE_PRODUCT_TITLE \
    org.opencontainers.image.created=$BUILD_DATE \
    org.opencontainers.image.revision=$COMMIT \
    org.opencontainers.image.vendor=Ericsson \
    org.opencontainers.image.version=$APP_VERSION \    
    com.ericsson.product-number=$IMAGE_PRODUCT_NUMBER \
    com.ericsson.product-revision=$RSTATE \
    com.ericsson.product-3pp-name="argoproj/argo-cd" \
    com.ericsson.product-3pp-version=$ARGO_CD_VERSION

COPY --from=argocd-build /go/src/github.com/argoproj/argo-cd/dist/argocd* /usr/local/bin/

USER root
RUN ln -s /usr/local/bin/argocd /usr/local/bin/argocd-server && \
    ln -s /usr/local/bin/argocd /usr/local/bin/argocd-repo-server && \
    ln -s /usr/local/bin/argocd /usr/local/bin/argocd-cmp-server && \
    ln -s /usr/local/bin/argocd /usr/local/bin/argocd-application-controller && \
    ln -s /usr/local/bin/argocd /usr/local/bin/argocd-dex && \
    ln -s /usr/local/bin/argocd /usr/local/bin/argocd-notifications && \
    ln -s /usr/local/bin/argocd /usr/local/bin/argocd-applicationset-controller && \
    ln -s /usr/local/bin/argocd /usr/local/bin/argocd-k8s-auth

USER $ARGOCD_USER_ID
ENTRYPOINT ["/usr/bin/catatonit", "--"]
