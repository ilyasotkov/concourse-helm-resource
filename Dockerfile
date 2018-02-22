FROM sk88ks/docker-helm:2.8.0

RUN apk add --update --upgrade --no-cache jq bash nodejs curl yarn

ENV KUBERNETES_VERSION 1.8.7
RUN curl -L -o /usr/local/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/v${KUBERNETES_VERSION}/bin/linux/amd64/kubectl; \
    chmod +x /usr/local/bin/kubectl

RUN helm init --client-only

# Install plugins
ARG PLUGIN_GCS_REPO=https://github.com/viglesiasce/helm-gcs.git
RUN helm plugin install ${PLUGIN_GCS_REPO}

ADD assets /opt/resource
RUN chmod +x /opt/resource/*

ENTRYPOINT [ "/bin/bash" ]
