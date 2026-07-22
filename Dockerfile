FROM ubuntu:noble

LABEL maintainer="You <you@email.com>"

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

#ENV LANG en_US.UTF-8
ENV DEBIAN_FRONTEND=noninteractive
# Environment variables
ENV LANG=en_US.UTF-8 \
    PYTHONUNBUFFERED=1 \
    PIP_BREAK_SYSTEM_PACKAGES=1

ARG TARGETARCH

# ----------------------------------------------------
# Install system dependencies
# ----------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-dev \
    python3-pip \
    python3-venv \
    build-essential \
    git \
    libpq-dev \
    libldap2-dev \
    libsasl2-dev \
    libssl-dev \
    libxml2-dev \
    libxslt1-dev \
    libjpeg-dev \
    zlib1g-dev \
    libffi-dev \
    libtiff-dev \
    libopenjp2-7-dev \
    liblcms2-dev \
    libwebp-dev \
    xz-utils \
    curl \
    ca-certificates \
    gnupg \
    dirmngr \
    npm \
    node-less \
    fonts-noto-cjk && \
#RUN apt-get update && \
#    DEBIAN_FRONTEND=noninteractive \
#    apt-get install -y --no-install-recommends \
#        ca-certificates \
#        curl \
#        dirmngr \
#        fonts-noto-cjk \
#        gnupg \
#        libssl-dev \
#        node-less \
#        npm \
#        python3-magic \
#        python3-num2words \
#        python3-odf \
#        python3-pdfminer \
#        python3-pip \
#        python3-phonenumbers \
#        python3-pyldap \
#        python3-qrcode \
#        python3-renderpm \
#        python3-setuptools \
#        python3-slugify \
#        python3-vobject \
#        python3-watchdog \
#        python3-xlrd \
#        python3-xlwt \
#        python3 \
#        python3-venv \
#        python3-dev \
#        build-essential \
#        libpq-dev \
#        git \
#        libldap2-dev \
#        libsasl2-dev \
#        xz-utils && \
    if [ -z "${TARGETARCH}" ]; then \
        TARGETARCH="$(dpkg --print-architecture)"; \
    fi; \
    WKHTMLTOPDF_ARCH=${TARGETARCH} && \
    case ${TARGETARCH} in \
    "amd64") WKHTMLTOPDF_ARCH=amd64 && WKHTMLTOPDF_SHA=967390a759707337b46d1c02452e2bb6b2dc6d59  ;; \
    "arm64")  WKHTMLTOPDF_SHA=90f6e69896d51ef77339d3f3a20f8582bdf496cc  ;; \
    "ppc64le" | "ppc64el") WKHTMLTOPDF_ARCH=ppc64el && WKHTMLTOPDF_SHA=5312d7d34a25b321282929df82e3574319aed25c  ;; \
    esac \
    && curl -o wkhtmltox.deb -sSL https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_${WKHTMLTOPDF_ARCH}.deb \
    && echo ${WKHTMLTOPDF_SHA} wkhtmltox.deb | sha1sum -c - \
    && apt-get install -y --no-install-recommends ./wkhtmltox.deb \
    && rm -rf /var/lib/apt/lists/* wkhtmltox.deb

# install latest postgresql-client
RUN echo 'deb http://apt.postgresql.org/pub/repos/apt/ noble-pgdg main' > /etc/apt/sources.list.d/pgdg.list \
    && GNUPGHOME="$(mktemp -d)" \
    && export GNUPGHOME \
    && repokey='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8' \
    && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "${repokey}" \
    && gpg --batch --armor --export "${repokey}" > /etc/apt/trusted.gpg.d/pgdg.gpg.asc \
    && gpgconf --kill all \
    && rm -rf "$GNUPGHOME" \
    && apt-get update  \
    && apt-get install --no-install-recommends -y postgresql-client \
    && rm -f /etc/apt/sources.list.d/pgdg.list \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g rtlcss

# ----------------------------------------------------
# Create odoo user
# ----------------------------------------------------
RUN useradd -m -d /opt/odoo -U -r -s /bin/bash odoo

WORKDIR /opt/odoo

# ----------------------------------------------------
# Clone Odoo source
# ----------------------------------------------------
ENV ODOO_VERSION=18.0

#RUN git clone https://github.com/odoo/odoo.git --depth 1 --branch $ODOO_VERSION .
COPY ./odoo /opt/odoo
#COPY ./.venv /opt/odoo/venv
RUN python3 -m venv /opt/odoo/venv
ENV PATH="/opt/odoo/venv/bin:$PATH"
# ----------------------------------------------------
# Python dependencies
# ----------------------------------------------------
RUN pip install --upgrade pip wheel setuptools
RUN pip install -r requirements.txt
#RUN pip3 install --no-cache-dir -r requirements.txt

# ----------------------------------------------------
# Directories
# ----------------------------------------------------
RUN mkdir /var/lib/odoo \
    && mkdir /mnt/extra-addons \
    && chown -R odoo:odoo /opt/odoo /var/lib/odoo /mnt/extra-addons

VOLUME ["/var/lib/odoo", "/mnt/extra-addons"]

# ----------------------------------------------------
# Config file
# ----------------------------------------------------
COPY ./container/config/odoo.conf /etc/odoo.conf
RUN chown odoo:odoo /etc/odoo.conf

USER odoo

EXPOSE 8069 8071 8072

CMD ["python", "/opt/odoo/odoo-bin", "-c", "/etc/odoo.conf"]
