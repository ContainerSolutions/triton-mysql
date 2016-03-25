FROM percona:5.6

RUN apt-get update \
    && apt-get install -y \
    python \
    python-dev \
    gcc \
    curl \
    percona-xtrabackup \
    && rm -rf /var/lib/apt/lists/*

# get Python drivers MySQL, Consul, and Manta
RUN curl -Ls -o get-pip.py https://bootstrap.pypa.io/get-pip.py && \
    python get-pip.py && \
    pip install \
        PyMySQL==0.6.7 \
        python-Consul==0.4.7 \
        manta==2.5.0

## get Containerbuddy release
#RUN export CB=containerbuddy-0.1.1 &&\
#   curl -Lo /tmp/${CB}.tar.gz \
#   https://github.com/joyent/containerbuddy/releases/download/0.1.1/${CB}.tar.gz && \
#   tar -xf /tmp/${CB}.tar.gz && \
#   mv /containerbuddy /bin/

ADD ./containerbuddy /bin/
RUN chmod +x /bin/containerbuddy

# configure Containerbuddy and MySQL
COPY bin/* /bin/
COPY etc/* /etc/

ADD ./cacert.pem  /usr/local/share/ca-certificates/mantl.crt
RUN update-ca-certificates

# override the parent entrypoint
ENTRYPOINT []

# use --console to get error logs to stderr
CMD [ "/bin/containerbuddy", \
      "mysqld", \
      "--console", \
      "--log-bin=mysql-bin", \
      "--log_slave_updates=ON", \
      "--gtid-mode=ON", \
      "--enforce-gtid-consistency=ON" \
]
