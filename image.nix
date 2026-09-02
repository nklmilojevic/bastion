{
  lib,
  dockerTools,
  writeShellApplication,
  runCommand,
  bash,
  coreutils,
  findutils,
  gnugrep,
  gnused,
  gawk,
  less,
  curl,
  cacert,
  tzdata,
  iana-etc,
  glibc,
  glibcLocalesUtf8,
  ncurses,
  openssh,
  mosh,
  tmux,
  fish,
  git,
  github-cli,
  jq,
  yq-go,
  ripgrep,
  catatonit,
  kubectl,
  fluxcd,
  kustomize,
  kubernetes-helm,
  just,
  stern,
  claude-code,
  bun,
  sofka,
  talosctl,
  rev,
}:
let
  user = "me";
  uid = "1000";
  home = "/config";
  moshPortRange = "60001:60005";

  claude = claude-code.overrideAttrs (_: {
    postFixup = "";
  });

  entrypoint = writeShellApplication {
    name = "bastion-entrypoint";
    runtimeInputs = [
      coreutils
      openssh
      git
      github-cli
      tmux
      claudeChannel
    ];
    text =
      builtins.replaceStrings
        [ "@sshd@" "@sftpServer@" ]
        [ "${openssh}/bin/sshd" "${openssh}/libexec/sftp-server" ]
        (builtins.readFile ./scripts/entrypoint.sh);
  };

  claudeChannel = writeShellApplication {
    name = "claude-channel";
    runtimeInputs = [
      coreutils
      jq
      git
      bun
      claude
    ];
    bashOptions = [
      "nounset"
      "pipefail"
    ];
    text = builtins.readFile ./scripts/claude-channel.sh;
  };

  moshServer = writeShellApplication {
    name = "mosh-server";
    text =
      builtins.replaceStrings
        [ "@moshServer@" "@moshPortRange@" ]
        [ "${mosh}/bin/mosh-server" moshPortRange ]
        (builtins.readFile ./scripts/mosh-server.sh);
  };

  etc = runCommand "bastion-etc" { } ''
    mkdir -p $out/etc/ssh $out/var/empty
    cat >$out/etc/passwd <<EOF
    root:x:0:0:root:/root:${bash}/bin/bash
    sshd:x:74:74:sshd privsep:/var/empty:/bin/false
    ${user}:x:${uid}:${uid}:${user}:${home}:${fish}/bin/fish
    EOF
    cat >$out/etc/group <<EOF
    root:x:0:
    sshd:x:74:
    ${user}:x:${uid}:
    EOF
    cat >$out/etc/nsswitch.conf <<EOF
    passwd: files
    group: files
    shadow: files
    hosts: files dns
    EOF
    ln -s ${openssh}/etc/ssh/moduli $out/etc/ssh/moduli
  '';

  toolchain = [
    kubectl
    fluxcd
    kustomize
    kubernetes-helm
    just
    stern
    talosctl
    sofka
    claude
    bun
    git
    github-cli
    jq
    yq-go
    ripgrep
  ];
in
dockerTools.streamLayeredImage {
  name = "ghcr.io/nklmilojevic/bastion";
  tag = rev;

  contents = toolchain ++ [
    bash
    fish
    tmux
    openssh
    moshServer
    coreutils
    findutils
    gnugrep
    gnused
    gawk
    less
    curl
    cacert
    tzdata
    iana-etc
    ncurses
    catatonit
    entrypoint
    claudeChannel
    etc
  ];

  fakeRootCommands = ''
    mkdir -p ${lib.removePrefix "/" home} tmp
    chown ${uid}:${uid} ${lib.removePrefix "/" home}
    chmod 1777 tmp
  '';

  config = {
    User = "${uid}:${uid}";
    WorkingDir = home;
    Entrypoint = [
      "${catatonit}/bin/catatonit"
      "--"
      "${entrypoint}/bin/bastion-entrypoint"
    ];
    Env = [
      "PATH=/bin"
      "HOME=${home}"
      "USER=${user}"
      "USER_NAME=${user}"
      "PORT=2222"
      "LANG=C.UTF-8"
      "LOCALE_ARCHIVE=${glibcLocalesUtf8}/lib/locale/locale-archive"
      "TZDIR=${tzdata}/share/zoneinfo"
      "TERMINFO_DIRS=/share/terminfo"
      "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
      "NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
      "GIT_SSL_CAINFO=/etc/ssl/certs/ca-bundle.crt"
      "CLAUDE_CONFIG_DIR=${home}/.claude"
      "DISABLE_AUTOUPDATER=1"
      "USE_BUILTIN_RIPGREP=0"
      "MOSH_PORT_RANGE=${moshPortRange}"
    ];
    ExposedPorts = {
      "2222/tcp" = { };
      "60001/udp" = { };
      "60002/udp" = { };
      "60003/udp" = { };
      "60004/udp" = { };
      "60005/udp" = { };
    };
    Volumes = {
      "${home}" = { };
    };
  };
}
