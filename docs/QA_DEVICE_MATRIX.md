# Release QA matrix (CropGuard AI)

Run before a production candidate build. Track failures in your issue tracker.

## Device classes

| Class        | Approx. width | Emulator / device |
|-------------|----------------|-------------------|
| Small phone | &lt; 360 dp    | Pixel 3a (or resizable 320dp) |
| Phone       | 360–599 dp     | Pixel 6 / Medium Phone |
| Foldable    | 600–839 dp     | Resizable or fold open |
| Tablet      | ≥ 840 dp       | Pixel Tablet |

## Font scale

- System **Display size** default; **Font size** 100%, **130%**, **150%**.

## Orientation

- Portrait (required for launcher activity).
- If you allow landscape on a screen, verify that screen independently.

## Flows (smoke)

1. Cold start → splash → home (signed in) or auth.
2. Scanner → capture → result → history entry.
3. Offline mode or airplane mode: **Offline banner** visible on data-driven screens; no blank screens.
4. Community: post text → appears in list (Room persistence after app restart).
5. Treatment tracker: toggle task → state survives after navigating away and back.

## Automation

- Unit: `./gradlew :app:testDebugUnitTest`
- Instrumented: `./gradlew :app:connectedDebugAndroidTest` (device or emulator required)
