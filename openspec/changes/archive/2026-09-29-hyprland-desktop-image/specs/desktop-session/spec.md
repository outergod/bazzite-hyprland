## Purpose

Defines how the image boots into a graphical login, which desktop sessions are offered, and how the user's Nix-provided environment reaches those sessions.

## ADDED Requirements

### Requirement: Image derives from Bazzite GNOME
The image SHALL be built on the Bazzite GNOME stable image and SHALL keep Bazzite's gaming stack (kernel, graphics drivers, Steam, gamescope) and Homebrew setup intact.

#### Scenario: Rebase from stock Bazzite GNOME
- **WHEN** a host running `bazzite-gnome:stable` switches to this image and reboots
- **THEN** the system boots, the user's home directory and data are unchanged, and Steam, gamescope and Homebrew work as before

#### Scenario: Gaming stack present
- **WHEN** the user runs `gamescope` or `steam` from a graphical session
- **THEN** the image-provided binaries start without anything extra being installed by the user

### Requirement: Password login is always required
The system SHALL present a graphical login screen at boot and SHALL NOT log any user in automatically into any session, including after logout or a session crash.

#### Scenario: Cold boot
- **WHEN** the machine powers on and the disk is unlocked automatically
- **THEN** a graphical login screen asks for credentials and no user session starts until a valid password is entered

#### Scenario: Session ends
- **WHEN** the user logs out or the compositor crashes
- **THEN** the system returns to the login screen and requires a password again

### Requirement: Hyprland is the default session
The login screen SHALL offer a Hyprland session as the default selection. The Hyprland session SHALL run under a session manager that starts the user's `graphical-session.target` and stops it when the session ends.

#### Scenario: Default login
- **WHEN** the user enters their password without changing the session selection
- **THEN** a Hyprland session starts

#### Scenario: User services follow the session
- **WHEN** a Hyprland session starts
- **THEN** systemd user units wanted by `graphical-session.target` are started, and they are stopped when the session ends

### Requirement: GNOME remains available as a fallback session
The login screen SHALL offer a GNOME session that works regardless of the state of the user's Hyprland configuration.

#### Scenario: Broken Hyprland config
- **WHEN** the user's Hyprland configuration is missing or invalid
- **THEN** the user can select the GNOME session at the login screen and get a working desktop

### Requirement: Login unlocks the user keyring
Logging in with a password SHALL unlock the user's login keyring for both the Hyprland and the GNOME session.

#### Scenario: Secrets available after login
- **WHEN** the user logs in with their password and an application requests a secret from the login keyring
- **THEN** the secret is returned without a separate keyring password prompt

### Requirement: Nix environment reaches the graphical session
Graphical sessions SHALL start with the user's Nix profile on `PATH` and its `share` directory in `XDG_DATA_DIRS`, so commands, desktop entries and icons installed through Nix work in the session.

#### Scenario: Launch a Nix-installed command from a keybind
- **WHEN** a Hyprland keybind or autostart entry runs a command that exists only in the user's Nix profile
- **THEN** the command is found and started

#### Scenario: Nix desktop entries are discoverable
- **WHEN** an application launcher lists installed applications in the Hyprland session
- **THEN** applications installed through the user's Nix profile appear alongside system applications

### Requirement: Desktop userland is not part of the image
The image SHALL NOT ship a default Hyprland configuration, application launcher, status bar, notification daemon, wallpaper utility or terminal chosen for Hyprland. The Hyprland session SHALL use the user's own configuration from their home directory.

#### Scenario: Swapping a launcher
- **WHEN** the user replaces their application launcher in their home-manager configuration and applies it
- **THEN** the new launcher is used in the next Hyprland session without any image rebuild or reboot

### Requirement: Password-checking components come from the image
Every component that verifies the user's password in a graphical session (login screen, screen locker, privilege-elevation agent) SHALL be provided by the image and authenticate through the system PAM stack.

#### Scenario: Privilege elevation in Hyprland
- **WHEN** an application in the Hyprland session requests polkit authorization
- **THEN** an authentication dialog appears, and entering the user's password grants the authorization
