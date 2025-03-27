FROM ubuntu:24.04
RUN apt update && apt -y install hping3 libcap2-bin curl
RUN setcap cap_net_raw+ep /usr/sbin/hping3

# Set user to ubuntu (UID 1000)
USER ubuntu

# Default command
ENTRYPOINT ["/usr/sbin/hping3"]
