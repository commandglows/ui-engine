# shipglows_test_kit

Test helpers for what makes widget tests hang or depend on the machine. Add it
as a dev dependency by path; it never goes in `dependencies`.

| Helper | Does |
| --- | --- |
| `reducedMotionBuilder` | `MaterialApp.builder` that sets reduced motion, so `pumpAndSettle` ends when a looping animation is on screen |
| `useTemporaryAppFolders()` | Points `path_provider` at a temporary folder removed after the test |
| `useMemoryPreferences()` | Returns `SharedPreferences` held in memory, with optional initial values |
