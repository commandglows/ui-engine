# App Engine

Shared packages of the ShipGlows Flutter apps, one package per capability. Each
package keeps its own dependencies, so an app pulls only what it uses, and has
its own README. **[flutter/CATALOG.md](flutter/CATALOG.md)** lists them all with
their dependencies and consumers.

## Layers

| Folder | Holds | May depend on |
| --- | --- | --- |
| `flutter/foundation/` | Theme and icons | nothing shared |
| `flutter/core/` | Pure Dart logic: no Flutter | `core` |
| `flutter/services/` | Accounts, settings, backends, updates, crash net | `foundation`, `core`, `services` |
| `flutter/components/` | Reusable widgets | `foundation`, `core`, `components` |
| `flutter/features/` | Complete user-facing capabilities | `foundation`, `core`, `services`, `components` |
| `flutter/desktop/` | Native windows, tray, hotkeys | everything except `features` |

A feature never depends on another feature. `dart tool/check_layers.dart` checks
all of this, by hand.

A new shared component takes its colors, radii, spacing and keys from
`ShipglowsTheme`, never from raw values or its own palette.

## Using a package

Every app reads the packages by path from the sibling checkout:

```yaml
dependencies:
  shipglows_command_bar:
    path: ../../shipglows-app-engine/flutter/components/shipglows_command_bar
```

A host that only has the app's repository (CI, Vercel) runs this before
`flutter pub get`, from the folder of the app's `pubspec.yaml`:

```bash
curl -fsSL https://raw.githubusercontent.com/commandglows/app-engine/main/tool/provide-engines.sh | bash -s -- .
```

It follows the path dependencies and clones the missing engines from their main
branch. To pin one, add `<repository> <commit>` to an `engine-refs` file next to
the `pubspec.yaml`.

## Working here

`flutter/` is a Dart workspace: run `flutter pub get` once in `flutter/` for one
resolution and one analysis context. Apps ignore the workspace and only see the
member they depend on.

| Tool | Does |
| --- | --- |
| `tool/check_layers.dart` | Checks the layers and that `core` stays pure |
| `tool/gen_catalog.dart` | Rewrites `flutter/CATALOG.md` from the pubspecs of this engine and of the sibling repositories |
| `tool/provide-engines.sh` | Provides the engines on a single-repository host |

Add a package in its layer folder with `resolution: workspace` and its README,
then rerun both Dart tools.

## `typescript/shipglows_sync`

`@shipglows/sync` is the reusable command synchronization engine. It supplies
strict request validation, canonical SHA-256 intent fingerprints, durable
receipt replay, remote revisions, deterministic field-conflict checks and
injectable schema factories. The host supplies one atomic transaction,
authenticated ownership and its domain executor. It has no Path or identity
provider dependency. See the [package contract](typescript/shipglows_sync/README.md).

DreamGlows uses this engine in its Convex backend and keeps Path commands in
`@dreamglows/path-core`. Its Flutter adapter reuses `shipglows_sync` for status,
`shipglows_clerk_auth` for PKCE and `shipglows_convex` for transport. Source
integration and synthetic regression proof do not establish hosted activation
or authentication for a consuming application.
