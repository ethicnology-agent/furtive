# Dev Container

Reproducible Flutter / Android toolchain for furtive. Inspired by [bullbitcoin-mobile](https://github.com/SatoshiPortal/bullbitcoin-mobile).

## Usage

```bash
fvm exec dart run melos run devcontainer:create   # first time: build toolchain image + create + start
fvm exec dart run melos run devcontainer:start    # subsequent times: start stopped container and exec into it
```

The dev container is built from `Containerfile.tools` (Flutter SDK + Android toolchain only). The workspace is mounted live, so code changes don't require rebuilding the image. `Containerfile.app` is reserved for reproducible APK builds via `fvm exec dart run melos run apk`.

or directly:

```bash
devcontainer up --workspace-folder . --config ./.devcontainer/devcontainer.json
```

## macOS (Apple Silicon)

Before starting the container, run the setup script:

```bash
.devcontainer/macos-setup.sh
```

This ensures Rosetta is active in the Podman VM. Without it, x86_64 binaries fall back to QEMU and crash with SIGSEGV. See [containers/podman#28181](https://github.com/containers/podman/issues/28181).

**Note:** SSH agent forwarding is not supported on macOS due to Podman's inability to mount host Unix sockets into containers through the VM layer. See [containers/podman#23785](https://github.com/containers/podman/issues/23785).

## Build APK outside the dev container

```bash
fvm exec dart run melos run apk                  # release apk
MODE=debug fvm exec dart run melos run apk       # debug apk
FORMAT=aab fvm exec dart run melos run apk       # release app bundle
```

Defaults to `podman`. Override with `CONTAINER=docker fvm exec dart run melos run apk`.
