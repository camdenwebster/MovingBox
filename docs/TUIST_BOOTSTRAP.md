# Tuist Bootstrap (Package-First)

Tuist manifests have been added for a package-focused development project:

- `Tuist/Config.swift`
- `Workspace.swift`
- `Project.swift`
- `TuistSupport/` harness sources and tests

## Purpose

This does not replace `MovingBox.xcodeproj` yet.
It provides a low-risk path to iterate on modular packages and gradually migrate project generation to Tuist.

## When Tuist is available

```bash
tuist install

tuist generate
```

Then open the generated workspace and use `MovingBoxModules` target for package integration work.

## Why this staged approach

- Keeps current app/test flows intact while migration starts.
- Avoids large one-shot project generation changes.
- Enables package-centric code evolution first.
