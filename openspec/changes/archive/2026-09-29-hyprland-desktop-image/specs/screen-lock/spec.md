## Purpose

Guarantees that an unattended or suspended Hyprland session is always behind a password prompt, because the lock screen is one of only two authentication barriers on a machine whose disk unlocks itself.

## ADDED Requirements

### Requirement: Session locks on idle
The Hyprland session SHALL lock after a period of user inactivity. The timeout is configured by the user, and the locking mechanism is provided by the image.

#### Scenario: Idle timeout reached
- **WHEN** no input occurs for the configured idle timeout
- **THEN** the session locks and the screen shows the lock screen

#### Scenario: Idle inhibited
- **WHEN** an application holds an idle inhibitor (for example, fullscreen video playback)
- **THEN** the session does not lock due to idleness while the inhibitor is held

### Requirement: Session locks on request
The user SHALL be able to lock the session on demand, and a system lock request for the session (such as `loginctl lock-session`) SHALL lock it.

#### Scenario: Manual lock
- **WHEN** the user triggers their lock keybind or runs `loginctl lock-session`
- **THEN** the session locks immediately

### Requirement: Session is locked before the system sleeps
When the system suspends or hibernates, the Hyprland session SHALL be locked before sleep begins, so session content is never visible on resume.

#### Scenario: Suspend and resume
- **WHEN** the system suspends from an unlocked Hyprland session and is later resumed
- **THEN** the first frame shown after resume is the lock screen, not session content

#### Scenario: Suspend while already locked
- **WHEN** the system suspends while the session is already locked
- **THEN** exactly one lock screen is active after resume and it accepts the user's password

### Requirement: Unlock requires the user's password via system PAM
The lock screen SHALL authenticate the user through the system PAM stack and SHALL unlock only on successful authentication.

#### Scenario: Correct password
- **WHEN** the user enters their correct password at the lock screen
- **THEN** the session unlocks and shows the previous content

#### Scenario: Wrong password
- **WHEN** the user enters an incorrect password
- **THEN** the session stays locked and indicates the failure

#### Scenario: Locker in the user's Nix profile
- **WHEN** the user's Nix profile also contains a screen-locker binary with the same name
- **THEN** locking still uses the image-provided locker, and unlocking with the correct password succeeds

### Requirement: Locker failure never exposes the session
If the lock screen process crashes or is killed while locked, the session SHALL remain locked and SHALL NOT show session content. The user SHALL be able to recover by logging in on a text console.

#### Scenario: Locker crash
- **WHEN** the lock screen process terminates unexpectedly while the session is locked
- **THEN** the display stays covered and input does not reach session applications

#### Scenario: Recovery from a text console
- **WHEN** the locker has crashed and the user logs in on a text console with their password
- **THEN** the user can restart a lock screen for the graphical session, unlock it, or end the session

### Requirement: Nested gaming sessions are covered by the lock
Applications running nested inside the Hyprland session, including Steam under a nested gamescope, SHALL be covered by the same lock behavior as any other application.

#### Scenario: Idle during nested Steam
- **WHEN** Steam runs in a nested gamescope window and the session is locked by request or before sleep
- **THEN** the lock screen covers the gamescope window and unlocking requires the user's password
