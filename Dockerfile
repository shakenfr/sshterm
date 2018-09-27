FROM debian as compiler
RUN apt update
RUN apt install git autoconf musl gcc musl-tools make wget bzip2 -y
RUN cd / && git clone https://github.com/mkj/dropbear.git
COPY localoptions.h /dropbear
RUN cd /dropbear && autoconf 
RUN cd /dropbear && autoheader 
RUN cd /dropbear && CC=musl-gcc ./configure --enable-static --disable-zlib
RUN cd /dropbear && make PROGRAMS="dbclient dropbearkey dropbearconvert"
RUN cd /dropbear && chmod +x dbclient
RUN cd / && wget https://busybox.net/downloads/busybox-1.29.3.tar.bz2
RUN cd / && tar jxvf busybox-1.29.3.tar.bz2
COPY bbox /busybox-1.29.3/.config
RUN cd /busybox-1.29.3 && make
RUN mkdir /busybox-1.29.3/sysbin && cd /busybox-1.29.3 && make CONFIG_PREFIX=./sysbin install

# nano builder based on
# https://github.com/andrew-d/static-binaries/blob/master/nano/Dockerfile
FROM debian:jessie as nano
MAINTAINER Andrew Dunham <andrew@du.nham.ca>

# Install build tools
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -yy && \
    DEBIAN_FRONTEND=noninteractive apt-get install -yy \
        automake            \
        build-essential     \
        curl                \
        git                 \
        pkg-config
RUN mkdir /output
RUN mkdir /build
ADD . /build

# This builds the program and copies it to /output
RUN /build/nano.sh


FROM scratch
COPY --from=compiler /busybox-1.29.3/sysbin /
COPY --from=compiler /dropbear/dbclient /bin/ssh
COPY --from=compiler /dropbear/dropbearconvert /bin/convert
COPY --from=nano /nano /bin/nano
RUN mkdir /root
RUN echo "cat /etc/motd && ssh -h && alias add_key='vi /root/inputkey && convert opensssh dropbear /root/inputkey /root/.ssh/id_dropbear'" > /etc/profile
RUN echo "root:x:0:0:root:/root:/bin/bash" > /etc/passwd
RUN mkdir /root/.ssh
RUN chmod go-rwx /root/.ssh
COPY inputkey /root/inputkey
COPY motd /etc/motd
CMD ["/bin/bash", "-l"]
