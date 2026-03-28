# Source priority fallback: vm role requirement (bastion toolbox)
FROM rockylinux:9

RUN dnf -y update && \
    dnf -y install \
      openssh-clients \
      openssh-server \
      sudo \
      curl \
      vim-minimal \
      iproute \
      bind-utils \
      net-tools \
      bash && \
    dnf clean all

EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]
