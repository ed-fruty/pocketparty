# Design notes / v0.2

## Direction

Pocket Party is a quick, warm same-screen game collection. A gently animated pastel rainbow background, dark navy cards, pastel player colors, clear generous touch regions, original friendly avatars. Choose the people first, then browse small animated previews. Games launch directly; tournaments are assembled by selecting preview cards in order.

The original request referenced JindoBlu's 1 2 3 4 Player Games - Offline. Its offline same-device play and AI/player options informed the collection model; no code, branding, images, or assets were copied. Reference: https://play.google.com/store/apps/details?id=com.JindoBlu.FourPlayers

Sushi stacking research found Sushi Stack Tower: Food Game, describing precise drops, stacking, and collapse: https://play.google.com/store/apps/details?id=com.marcospardo.sushistackmaster. This is a related reference, not a confirmed identification of the exact mini game the user saw. BurgerTower follows the requested timed multiplayer physics mechanic with original food drawings and rigid-body stacks.

Godot orientation/resolution reference: https://docs.godotengine.org/en/4.6/tutorials/rendering/multiple_resolutions.html

## Animation

Page entrances ease in over 280 ms; hover feedback eases over 120–160 ms; avatars bob; previews loop continuously. Sprint positions ease toward score changes. Signal lamps pulse on green. Pair Peek flips cards through a narrowing perspective illusion over 250 ms. BurgerTower ingredients use physics interpolation, a smoothly following camera, moving drop previews, and eased height counters. Logical scoring remains separate from displayed movement. Pause stops gameplay clocks and freezes burger bodies with motion restored on resume.

## Responsive behavior

The project uses a square 720 px minimum canvas with `canvas_items` stretching and expanded aspect, Android sensor orientation, and safe-area margins. Home places its introduction and characters beside the main actions in landscape; it stacks them in portrait. Menus scroll. Preview grid is 2 columns portrait / 4 landscape. Pair Peek uses 4×4 portrait / 8×2 landscape. Simultaneous games use player touch pads. BurgerTower uses 2-column player lanes in portrait and one horizontal row in landscape. Each lane has its own fixed 360×560 SubViewport / World2D, so rotation changes display geometry, not collision state or fairness.

## Deliberate prototype choices

- Profiles are four fixed seats; wallet and cosmetic ownership are shared by the device.
- Pair Peek always passes the turn. A later rules setting could offer “match keeps turn.”
- Burger ingredients have rectangle colliders with decorative visual shapes. Gameplay is physical; artwork is intentionally lightweight.
- BurgerTower scores supported, relatively settled pieces at the final deadline, after a two-second settling grace. Height can decrease when the tower falls.
- Cups currently include 2–5 distinct games, selected in order. Repeated rounds and team modes can be added later.
- Sprint/Signal share the initial arena script. New games register their own scripts.

## Next useful work

Physical-device multitouch and tablet safe-area checks; wider bot playtesting; ingredient balancing and bounce/collapse effects; win confetti and music; custom names / persistent profiles; accessibility and localization; more mini games; release signing and Android store assets. The APK is a debug build. Emulator UI checks supplement desktop mechanics tests; they do not prove physical-device ergonomics or performance.

## Verification snapshot

Desktop integration suite: 152 checks passed, including all 65 roster combinations containing humans, both orientations, synthetic multitouch, memory turns, support-based physics scoring, local saves, economy, roster-first navigation, direct preview launch, and selected tournament order and payouts. The Android debug APK builds and runs on the Pixel 3a API 34 emulator. Desktop portrait/landscape captures and Android launch/navigation captures are saved under `builds/`. The emulator is left open for play; physical-device touch ergonomics and sensor rotation remain follow-up checks.

Startup branding: original MINI GAMES OFFLINE PNG splash, with matching Android launcher/adaptive icons. Sources regenerate via tools/build_branding.py.

Darkspots: twenty-second simultaneous timing round. A colored ring orbits each square; tapping inside the dark range earns five points and moves it, changing its length. All seats share a constant 0.48 laps/second and target sequence. Misses do not earn points or move the target. Range lengths vary from 6–12% of the perimeter, with a different length after every hit. The visible range and scoring bounds match and handle corners and the loop boundary; input is debounced to prevent touch/mouse duplication. Bots vary in success probability by difficulty. Portrait/landscape screenshots and timing/pause/hit/miss/bot checks pass (178 integration checks total).

Darkspots colors: only this mini game uses rainbow-filled squares and gold target ranges, including its gallery preview. Colored orbit rings have a dark outline for contrast.

All mini-game rounds now use the full available screen, without a title/header row. Tapping games use white finger controls in four fixed player-colored corners, with a compact centered timer and pause button. Pair Peek retains direct card input and corner score indicators. The skin shop supports touch and mouse dragging, wheels and trackpad pan; skin updates preserve scroll position. 188 integration checks pass.

Corner fingers route native touch and mouse input directly through arena coordinates, with held/pressed animation and release feedback. This avoids GUI-child interception. Full Viewport input dispatch, scoring, and release checks bring the integration suite to 191 passing checks.

Darkspots hit detection includes the visible moving ring radius at the edges of the gold range. Hit (+5) and miss feedback remains visible below each square for 0.9 seconds. This restores feedback lost when corner controls replaced the older bottom pads. 193 integration checks pass.
