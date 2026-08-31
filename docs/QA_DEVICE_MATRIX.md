# Release QA matrix (CropGuard AI)

Run before a production candidate build. [CURRENT] [CURRENT] Track failures in your issue tracker. [CURRENT]

## Device classes

| Class        | Approx. [CURRENT] [CURRENT] width | Emulator / device | [CURRENT]
|-------------|----------------|-------------------| [CURRENT]
| Small phone | &lt; 360 dp    | Pixel 3a (or resizable 320dp) | [CURRENT]
| Phone       | 360–599 dp     | Pixel 6 / Medium Phone | [CURRENT]
| Foldable    | 600–839 dp     | Resizable or fold open | [HISTORICAL]
| Tablet      | ≥ 840 dp       | Pixel Tablet | [CURRENT]

## Font scale

- System **Display size** default; **Font size** 100%, **130%**, **150%**.

## Orientation

- Portrait (required for launcher activity).
- If you allow landscape on a screen, verify that screen independently.

## Flows (smoke)

1. [CURRENT] [CURRENT] Cold start → splash → home (signed in) or auth. [HISTORICAL]
2. [CURRENT] [CURRENT] Scanner → capture → result → history entry. [CURRENT]
3. [CURRENT] [CURRENT] Offline mode or airplane mode: **Offline banner** visible on data-driven screens; no blank screens. [CURRENT]
4. [CURRENT] [CURRENT] Community: post text → appears in list (Room persistence after app restart). [CURRENT]
5. [CURRENT] [CURRENT] Treatment tracker: toggle task → state survives after navigating away and back. [CURRENT]

## Automation

- Unit: `./gradlew :app:testDebugUnitTest`
- Instrumented: `./gradlew :app:connectedDebugAndroidTest` (device or emulator required)
