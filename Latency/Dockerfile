FROM ubuntu:24.04
RUN apt update && apt -y install hping3 libcap2-bin
RUN setcap cap_net_raw+ep /usr/sbin/hping3
