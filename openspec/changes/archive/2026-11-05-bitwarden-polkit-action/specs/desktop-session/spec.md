## ADDED Requirements

### Requirement: Polkit actions for the user's Flatpak apps come from the image
Polkit actions that the user's Flatpak apps need, and that a Flatpak can't register itself, SHALL be provided by the image. This is an exception to "Desktop userland is not part of the image": polkit only reads actions from system directories. Each shipped action SHALL grant nothing without authenticating the active user through the session's polkit agent. The image SHALL provide Bitwarden's action `com.bitwarden.Bitwarden.unlock`, allowed for the active session after the user authenticates as themselves and denied for inactive and remote sessions.

#### Scenario: Unlock Bitwarden with system authentication
- **WHEN** "Unlock with system authentication" is enabled in the Bitwarden flatpak and the user unlocks the locked vault with it, in the Hyprland or the GNOME session
- **THEN** the session's polkit agent asks for the user's password, and entering it unlocks the vault

#### Scenario: Action known without local files
- **WHEN** the host runs the image with nothing added under `/etc/polkit-1/actions`
- **THEN** `pkaction --action-id com.bitwarden.Bitwarden.unlock` lists the action

#### Scenario: Other sessions are denied
- **WHEN** a process outside the active local session (e.g. over SSH) asks polkit to authorize `com.bitwarden.Bitwarden.unlock`
- **THEN** the authorization is denied without a prompt
