# Changelog

## v0.9.0 - 2026-11-24

This release updates the tools in bastion. Users get new features and fixes from these tool updates.

### New features
- Update `gh` to 2.105.0. The preview `gh event listen` command waits for pull request events instead of polling GitHub.
- Update the Kubernetes terminal UI to 0.38.0 and add a searchable API resource browser. The release removes the Intel Mac build, so those users must build it from source.
- Update the terminal app to 0.24.0. Commands can run in a minimized card, and panes can be minimized or restored.
- Update the terminal app to 0.25.0. Users can copy files between this Mac and a remote host.
- Update the terminal app to 0.27.0. Pi and Antigravity sessions get automatic titles.
- Update `ripgrep` to 16.0.0. It adds the `-G` flag for negated globs and the `RIPGREP_THREADS` variable.
- Update `mise` to 2026.11.10. It adds the `enable_backends` allowlist for tool backends.
- Update `mise` to 2026.11.11. It adds the `if_pool` task option for task locks.
- Update `mise` to 2026.11.12. It adds `mise audit` and `mise upgrade --vulnerable`.
- Update `mise` to 2026.11.14. It adds `cache.sandbox`, which limits a cached task to its sources and outputs.

### Fixes
- Update `flux`, the terminal app, and `pi` to newer versions. The `flux` update fixes credential caching, so changed annotations apply on the next reconcile.
- Update `talosctl` to 1.14.7. The release fixes how Talos serves logind D-Bus broker clients.

## v0.8.4 - 2026-11-16

This release updates the tools that bastion bundles. Bastion commands, config fields and defaults do not change.

### Other changes

- Updates the bundled `sofka` tool to v0.37.0. The logs view shows a horizontal scrollbar for long lines.
- Updates the `mise` container image to 2026.11.9. Tool installs and task runs use the new version.

## v0.8.3 - 2026-11-07

This release updates the tools and base image that bastion uses. It does not change how bastion works for you.

## v0.8.2 - 2026-11-02

This release updates the tools that bastion installs. It does not change how bastion works.

## v0.8.1 - 2026-10-29

This release fixes the container image and the `mise lock` command. Both work again without user action.

### Fixes

- The container image now installs `libatomic1`. Node.js 26 needs this library to start.
- The `sofka` and `thurm` tools now apply to Linux only. This stops `mise lock` from failing on macOS.

### Other changes

- The container image now uses Node.js 26, which is an LTS release.

## v0.8.0 - 2026-10-22

This release updates the `sofka`, `stern`, and `thurm` tools. Read the `stern` note before you upgrade, because one template change is required.

### New features

- `sofka` v0.32.0 lets you press `i` on a Flux `HelmRelease` to set `spec.chart.spec.version`. It also lets long log lines scroll sideways with the arrow keys.
- `stern` v1.35.0 adds the `--pager` flag to send output to a pager. With `--timestamps`, `.Message` no longer includes the timestamp, so add `.Timestamp` to custom templates.
- `thurm` adds shell completions for bash, elvish, fish, powershell, and zsh. Run `thurm completion <shell>` to set them up, and your shell then completes commands and options.

## v0.7.2 - 2026-10-22

This release contains no changes for bastion users. It only changes how the project publishes new versions.
