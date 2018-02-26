FROM sk88ks/docker-helm:2.8.0

RUN apk add --update --upgrade --no-cache jq bash nodejs curl yarn

ENV KUBERNETES_VERSION 1.8.7
ENV CLOUD_SDK_VERSION 189.0.0

RUN curl -L -o /usr/local/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/v${KUBERNETES_VERSION}/bin/linux/amd64/kubectl; \
    chmod +x /usr/local/bin/kubectl

RUN helm init --client-only

# Install plugins
ARG PLUGIN_GCS_REPO=https://github.com/viglesiasce/helm-gcs.git
RUN helm plugin install ${PLUGIN_GCS_REPO}

ADD assets /opt/resource
RUN chmod +x /opt/resource/*

ENV PATH /google-cloud-sdk/bin:$PATH
RUN apk --no-cache add \
        curl \
        python \
        py-crcmod \
        bash \
        libc6-compat \
        openssh-client \
        git \
    && curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${CLOUD_SDK_VERSION}-linux-x86_64.tar.gz && \
    tar xzf google-cloud-sdk-${CLOUD_SDK_VERSION}-linux-x86_64.tar.gz && \
    rm google-cloud-sdk-${CLOUD_SDK_VERSION}-linux-x86_64.tar.gz && \
    gcloud config set core/disable_usage_reporting true && \
    gcloud config set component_manager/disable_update_check true && \
    gcloud config set metrics/environment github_docker_image && \
    gcloud --version

ENTRYPOINT [ "/bin/bash" ]
