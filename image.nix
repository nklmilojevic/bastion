# OCI image for the bastion pod: a rootless sshd jump box carrying the same
# toolchain as the home repo's dev shell, plus Claude Code with the Telegram
# channel plugin kept alive in tmux (scripts/claude-channel.sh).
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

  # writeShellApplication supplies the shebang and `set -o errexit/nounset/pipefail`
  # and runs shellcheck at build time, so the script files carry neither.
  entrypoint = writeShellApplication {
    name = "bastion-entrypoint";
    runtimeInputs = [
      coreutils
      openssh
      git
      github-cli
      tmux
      glibc.bin # getent
      claudeChannel
    ];
    text = builtins.replaceStrings [ "@sftpServer@" ] [ "${openssh}/libexec/sftp-server" ] (
      builtins.readFile ./scripts/entrypoint.sh
    );
  };

  claudeChannel = writeShellApplication {
    name = "claude-channel";
    runtimeInputs = [
      coreutils
      jq
      git
      bun
      claude-code
    ];
    # No errexit: the loop must survive a failing `claude` and restart it.
    bashOptions = [
      "nounset"
      "pipefail"
    ];
    text = builtins.readFile ./scripts/claude-channel.sh;
  };

  # Shadows mosh-server on PATH (mosh itself is deliberately not in `contents`)
  # so the UDP range matches what the LoadBalancer Service exposes.
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
    claude-code
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
  # Placeholder only: the Image workflow re-tags with the release version on push.
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
    # sshd hands login shells a scrubbed environment; the entrypoint forwards
    # the relevant subset of these through PermitUserEnvironment.
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
