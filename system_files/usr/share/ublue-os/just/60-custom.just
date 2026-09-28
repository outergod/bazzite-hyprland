# Create a distrobox that uses the host's Nix store and daemon instead of its own store
[group('Nix')]
nix-toolbox name="nix" image="":
    #!/usr/bin/bash
    set -euo pipefail
    image="{{ image }}"
    if [[ -z "${image}" ]]; then
        image="registry.fedoraproject.org/fedora-toolbox:$(rpm -E %fedora)"
    fi
    # Read-only: the container reaches the store only through the host daemon's socket
    distrobox create --yes --name "{{ name }}" --image "${image}" --volume /nix:/nix:ro
