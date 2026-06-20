# Keel

Keel is a lightweight native macOS client for Docker Engine.

It gives you a focused SwiftUI interface for day-to-day local container work without replacing Docker itself. Keel expects a working Docker-compatible runtime to already be installed and running.

## What Keel Is

- A native macOS Docker client
- A small SwiftUI app for local container and image visibility
- A lightweight alternative to opening a full Docker dashboard for simple tasks
- A client for existing Docker Engine providers such as Docker Desktop, OrbStack, Colima, or Lima-based setups

## What Keel Is Not

- It does not install Docker Engine
- It does not bundle a Linux VM
- It does not replace Docker Desktop, OrbStack, Colima, or Lima
- It is not designed for multi-user remote Docker management
- It is not an App Store sandboxed app

## Requirements

- macOS 14 or newer
- Xcode 16 or newer to build from source
- Docker CLI available at one of:
  - `/usr/local/bin/docker`
  - `/opt/homebrew/bin/docker`
  - `/usr/bin/docker`
  - a path exposed through `PATH`
  - a custom path set with `DOCKER_CLI`
- A running Docker-compatible engine

Keel works against whichever Docker context your local Docker CLI is currently using.

## Supported Runtimes

Keel should work with any local runtime that exposes the standard Docker CLI and Docker Engine behavior, including:

- Docker Desktop
- OrbStack
- Colima
- Lima-based Docker setups
- Remote Docker contexts, if your local Docker CLI is already configured for them

## Current Features

- Detects the active Docker context
- Shows Docker Engine version
- Command-center interface for local Docker work
- Groups containers by inferred project/service name
- Lists containers with image, state, ports, CPU, memory, and quick actions
- Shows container image, state, and status
- Starts stopped containers
- Stops running containers
- Restarts running containers
- Deletes stopped containers and force-removes containers with confirmation
- Starts, stops, and restarts grouped project containers
- Shows recent container logs for the selected container
- Lets the log drawer be resized by dragging the divider
- Shows Docker disk usage by images, containers, volumes, and build cache
- Shows selected-container network I/O
- Lists local Docker images
- Shows image repository, tag, id, age, and size
- Removes images with confirmation
- Lists Docker volumes and removes volumes with confirmation
- Lists Docker networks and removes removable networks with confirmation
- Shows grouped compose-style projects inferred from local containers
- Provides no-engine onboarding links for OrbStack, Docker Desktop, and Colima

## Roadmap

- Continuous stats refresh
- Full streaming logs
- Exec shell into a container
- Compose project grouping
- Volume and network views
- Image pull and remove actions
- Container delete action with confirmation
- Preferences for Docker CLI path and refresh interval
- Optional Docker Engine API client to reduce Docker CLI dependency

## Architecture

Keel is intentionally simple:

```text
SwiftUI UI
  -> DockerStore
    -> DockerClient
      -> local docker CLI
        -> Docker Engine / current Docker context
```

The app currently talks to Docker through the local Docker CLI. That keeps the first version small, compatible with Docker contexts, and easy to reason about.

The Docker Engine API is still the natural long-term direction for richer streaming features such as logs, stats, and exec sessions.

## Security Model

Docker control is powerful. Access to Docker Engine is effectively machine-level control in many local setups.

Keel does not expose Docker over a network. It runs locally and uses the Docker access already available to your macOS user account.

Because Keel needs to launch the Docker CLI and interact with local developer tooling, it is intended for direct distribution outside the Mac App Store.

## Build

```bash
./script/build_and_run.sh
```

Or build manually:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -project Keel.xcodeproj -scheme Keel -configuration Release -destination 'platform=macOS' build
```

## Install Locally

After a Release build, copy the app into `/Applications`:

```bash
rm -rf /Applications/Keel.app
ditto ~/Library/Developer/Xcode/DerivedData/Keel/Build/Products/Release/Keel.app /Applications/Keel.app
open /Applications/Keel.app
```

## Development Notes

Keel currently uses Xcode's file-system-synchronized project groups, so new Swift files inside `Keel/` are picked up by the app target automatically.

If Docker is not running, Keel shows the Docker CLI or daemon error and lets you refresh after starting your runtime.
