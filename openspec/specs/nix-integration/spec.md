# nix-integration Specification

## Purpose

Provides a native, multi-user Nix installation on the image-based host so home-manager manages user tooling and desktop userland directly on the host, with a single store shared by the host and its toolbox containers.

## Requirements

### Requirement: Nix is available on the host out of the box
The image SHALL provide a working multi-user Nix installation: a Nix daemon started on demand, the `nix` command, and flakes and the `nix` command interface enabled, with no installer run by the user.

#### Scenario: First use after rebase
- **WHEN** a user on a freshly deployed image runs `nix run nixpkgs#hello`
- **THEN** the package is fetched into the store through the daemon and runs, without root privileges or installer steps

#### Scenario: Unprivileged user
- **WHEN** a non-root user builds or fetches a store path
- **THEN** the operation goes through the daemon and the resulting store path is owned by root and readable by all users

### Requirement: Nix store lives at /nix and persists across image updates
The Nix store SHALL be accessible at `/nix` (as a real directory, not a symlink) and its contents, including profiles and the database, SHALL persist across image upgrades, rollbacks and reboots.

#### Scenario: Image upgrade
- **WHEN** the host upgrades to a newer image build and reboots
- **THEN** all store paths, profiles and home-manager generations present before the upgrade still exist and resolve

#### Scenario: Image rollback
- **WHEN** the host rolls back to the previous deployment of this image
- **THEN** the Nix store and daemon remain functional

### Requirement: Nix works under SELinux enforcing
Nix operations and programs run from the Nix store, including systemd user units defined in store paths, SHALL work with SELinux in enforcing mode, without the user changing policy.

#### Scenario: User unit from the store
- **WHEN** home-manager activates a systemd user unit whose `ExecStart` points into `/nix/store`
- **THEN** the unit starts under SELinux enforcing without AVC denials that prevent it from running

#### Scenario: Newly built store path
- **WHEN** a store path is created after the image was deployed and a program from it is executed by the user
- **THEN** the program runs under SELinux enforcing

### Requirement: home-manager runs on the host
The user SHALL be able to apply their existing standalone home-manager flake on the host, and the results SHALL take effect in both login shells and graphical sessions.

#### Scenario: Apply an existing flake
- **WHEN** the user runs `nix run home-manager -- switch --flake ~/.config/home-manager` on the host
- **THEN** activation succeeds, the managed packages are on `PATH` in new login shells, and managed dotfiles resolve to existing store paths

#### Scenario: Fish shell
- **WHEN** the user's login shell is fish
- **THEN** the Nix profile is on `PATH` in fish sessions without additional user configuration

### Requirement: Containers use the single host store
The image SHALL provide a supported way to create a toolbox container that uses the host's Nix store and daemon, so Nix-installed tools and home-manager-managed files that live in the shared home directory resolve inside the container.

#### Scenario: Tools inside a toolbox
- **WHEN** the user creates a toolbox through the provided recipe and enters it
- **THEN** commands from the user's host home-manager profile run inside the container

#### Scenario: Building inside a toolbox
- **WHEN** the user runs a Nix build or `nix develop` inside such a toolbox
- **THEN** the build goes through the host daemon and the result is in the host store, visible from the host

#### Scenario: No split stores
- **WHEN** the user works across the host and toolbox containers created through the recipe
- **THEN** there is exactly one Nix store and one set of Nix profiles for the user, and no profile link in the home directory points to a store path that is missing on the host

### Requirement: Homebrew remains untouched
The image SHALL keep Bazzite's Homebrew setup unchanged, and Nix SHALL coexist with it.

#### Scenario: Both package managers present
- **WHEN** the user has both Homebrew and a Nix profile active
- **THEN** both `brew` and `nix` work
