# Changelog

## v0.8.0 - 2026-10-22

This release updates the `sofka`, `stern`, and `thurm` tools. Read the `stern` note before you upgrade, because one template change is required.

### New features

- `sofka` v0.32.0 lets you press `i` on a Flux `HelmRelease` to set `spec.chart.spec.version`. It also lets long log lines scroll sideways with the arrow keys.
- `stern` v1.35.0 adds the `--pager` flag to send output to a pager. With `--timestamps`, `.Message` no longer includes the timestamp, so add `.Timestamp` to custom templates.
- `thurm` adds shell completions for bash, elvish, fish, powershell, and zsh. Run `thurm completion <shell>` to set them up, and your shell then completes commands and options.

## v0.7.2 - 2026-10-22

This release contains no changes for bastion users. It only changes how the project publishes new versions.
