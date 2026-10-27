# Jenkins controller for your laptop, with every tool the pipeline calls:
# python3/venv, ssh, rsync, curl, Terraform, Infracost and Conftest (OPA).
FROM jenkins/jenkins:lts-jdk17

ARG TF_VERSION=1.9.8
ARG INFRACOST_VERSION=0.10.39
ARG CONFTEST_VERSION=0.56.0

USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends python3 python3-pip python3-venv openssh-client rsync curl unzip git \
 && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    ARCH="$(dpkg --print-architecture)"; \
    curl -fsSLo /tmp/terraform.zip "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_${ARCH}.zip"; \
    unzip -q /tmp/terraform.zip -d /usr/local/bin; \
    curl -fsSL "https://github.com/infracost/infracost/releases/download/v${INFRACOST_VERSION}/infracost-linux-${ARCH}.tar.gz" | tar -xz -C /tmp; \
    mv "/tmp/infracost-linux-${ARCH}" /usr/local/bin/infracost; \
    if [ "$ARCH" = "amd64" ]; then CT_ARCH="x86_64"; else CT_ARCH="$ARCH"; fi; \
    curl -fsSL "https://github.com/open-policy-agent/conftest/releases/download/v${CONFTEST_VERSION}/conftest_${CONFTEST_VERSION}_Linux_${CT_ARCH}.tar.gz" | tar -xz -C /usr/local/bin conftest; \
    chmod +x /usr/local/bin/terraform /usr/local/bin/infracost /usr/local/bin/conftest; \
    rm -f /tmp/terraform.zip; \
    terraform -version && infracost --version && conftest --version

USER jenkins
