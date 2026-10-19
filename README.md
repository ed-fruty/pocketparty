# 4 Players Game Offline

An original offline party-game collection with same-device play and optional NetPlay over local Wi-Fi built with Godot 4.7.2 / GDScript. Android phones and tablets, portrait and landscape. All project source, original artwork, test captures, APK output, and emulator writable data live in this directory. The sibling Godot projects were read only as references.

## Play

```sh
godot --path .
```

Or open `project.godot` in Godot and press F6/F5. Android debug build: `builds/pocket-party.apk`.

**Flow:** Home → choose four seats (Human / Bot / Off) → small animated game previews → tap to play. Switch the preview grid to **Build tournament**, select 2–8 games in the order you want, then start. At least one human must join; every valid combination of 1–4 active seats is supported. One human can play solo without a bot.

- **Star Sprint:** tap your pad; first to 80 steps, or highest steps after 18 seconds, wins.
- **Signal Snap:** five signals; tap on green. False starts cost 100 points and lock that signal. Faster reactions earn more points.
- **Pair Peek:** 16 hidden cards / eight pairs. Reveal two per turn; matching cards stay face up and earn a pair. Pass the turn after every attempt, including matches. Most pairs wins. Two-player classic, extended to solo and 3–4 seats. Bots remember only exposed cards.
- **Darkspots:** a ring orbits a square. Tap when it enters the gold range; a hit gives five points and moves the gold range to a new location with a different random length (6–12% of the perimeter). The round lasts exactly 20 seconds. Misses give no points. Each seat has its own square; bots share the same speed and target sequence.
- **Snake Clash:** drag the finger in your corner to steer; eat pizza for +3 length, then absorb smaller snakes for half their length. Growing comes first: a unique biggest snake starts a 10-second hunt. A different biggest snake restarts the full timer; ties pause it until someone leads again. Longest surviving snake when the hunt expires wins. Equal sizes bump apart; walls bounce. Eaten snakes are disabled and score zero. Bots seek pizza, hunt smaller snakes and avoid bigger ones. Keyboard: P1 WASD, P2 arrows, P3 IJKL, P4 TFGH.
- **Let's Dance!:** one randomly chosen player creates five moves: Wave, Jump, Spin, Clap. Everyone watches the replay, then the other players repeat all five moves in order. One wrong move ends the attempt. Perfect followers win; if none succeeds, the leader wins. A solo player copies a virtual teacher; a failed solo dance earns no gold. Bots can lead and follow. An idle creator's sequence is filled after 12 seconds, and followers have 12 seconds to respond. Keyboard moves: P1 QWER, P2 UIOP, P3 ASDF, P4 HJKL.
- **Obby Run:** run automatically for up to 35 seconds. Tap JUMP over orange blocks or DUCK under gold bars. A collision eliminates the player immediately. Last survivor wins; solo runners must finish the course. Failed runs with no survivors award no win gold. Bots use the same course and controls show AUTO. Keyboard: P1 A/S, P2 L/K, P3 Z/X, P4 M/N (jump/duck).
- **BurgerTower:** time your drop onto the plate. Real rigid-body ingredients slide, rotate, collide, and topple. Highest current supported tower after 30 seconds plus two settling seconds wins. Falling and airborne ingredients do not count. Heights are game units labelled cm (four physics pixels per cm).

Rounds fill the screen. Separate player fields use matching colored borders and bottom-first positions: P3/P4 above P1/P2. Touch the white finger labelled with your player number and color. In portrait, one active seat uses bottom center and two active seats use the bottom corners. P1 and P2 start in the bottom corners in both orientations; P3 and P4 use the top corners. Bot controls use muted robot icons and large BOT labels instead of fingers, and reject human taps. Pair Peek uses shared cards: a colored YOUR TURN banner and card borders identify the current player; other player indicators are dimmed and labelled WAIT. Mouse works on desktop. Menus support touch swipes, mouse dragging, wheels, and trackpad scrolling. The skin shop preserves its scroll position after purchases/equips. Keyboard: P1 **A**, P2 **L**, P3 **Z**, P4 **M**. Pair Peek: arrows + Space/Enter. Escape / Android Back pauses during games. Leaving the app pauses the round. Menus scroll on short screens.

## NetPlay

Home → **NetPlay** → **Create Room** or **Join Room**. Friends on the same private Wi-Fi join through nearby discovery or the host IP address. P1 hosts; P2–P4 are connected friends, bots or empty seats. The host chooses games/tournaments and advances rounds. Each phone controls only its own seat and receives only its own earned gold in its existing local wallet. No account, backend or internet connection is required. [Details and testing](docs/NETPLAY.md).

## Progress and skins

Round winners receive 15 gold each; human tournament champions receive another 40 gold each. Ties pay each human winner. Bot wins pay no gold. Gold is a shared device wallet, with skins individually equipped on the four player seats. Cup scoring: `10 × (active seats − seats with a higher score)`. Round results show points earned and cumulative tournament totals. Highest total wins. The final ceremony raises one gold cup with a red diamond for every tied champion, with animated confetti; non-winners stand still. Payouts are idempotent.

Ten original procedural skins: party pals, cats, robots, royals, ninjas, aliens, Rabbit (30 gold), Koala (45), Panda (60), and Capybara (75). Animal skins wear the player’s colored scarf. Gold, owned/equipped skins, difficulty, music, and sound effects save in Godot's local `user://party_save.json`. The app has no ads, login, or purchases. Optional NetPlay uses Android INTERNET permission for local Wi-Fi sockets; single-device gameplay remains offline. Saves are local to each installation.

## Structure

- `core/party.gd`: roster, session schedule, tournament scoring, economy, saves.
- `core/catalog.gd`: game metadata and script registry.
- `ui/main.gd`: responsive screens, roster-first navigation, small game previews, selected tournament, pause/results/shop/settings.
- `ui/avatar.gd`, `ui/game_art.gd`: original animated vector art.
- `ui/tournament_ceremony.gd`: responsive podium, one red-diamond cup per champion, cup-raising animation and confetti.
- `games/arena.gd`: shared arena helpers + Sprint and Signal mechanics.
- `games/lets_dance.gd`: player-created dance sequences, replay, ordered copying, animated dancers and bots.
- `games/snake_clash.gd`: fixed-step snake movement, drag controls, pizza, growth, predation and bots.
- `games/obby_run.gd`: automatic runner, timed jump/duck actions, obstacle elimination, bots and two-button touch controls.
- `games/darkspots.gd`: twenty-second timing game, target sequence, hit windows and bots.
- `games/pair_peek.gd`: card turns, reveals, memory bots, responsive board.
- `games/burger_tower.gd`: timed round, controls, player lanes and scoring.
- `games/burger_lane.gd`: independent fixed-coordinate physics world and camera.
- `games/ingredient.gd`: rigid-body food and original drawing.
- `core/audio.gd`: tiny synthesized offline sound cues.
- `core/music.gd`: original looping ambient music, independent saved toggle, fades and background pause.
- `tests/smoke.gd`: executable integration checks and optional screenshots.

To add a game, create a Control script with `roster`, `game_id`, `paused`, and a `finished(scores: Dictionary)` signal (inherit the arena helpers if useful), then register metadata and its script in `core/catalog.gd`. Catalog entries automatically become previews. Scores must be keyed by seat ID, with larger values better. UI/rewards belong to the shell, not to the mini game.

## Verify

```sh
godot --headless --path . tests/smoke.tscn
godot --headless --path . tests/obby_smoke.tscn
godot --headless --path . tests/snake_smoke.tscn
godot --headless --path . tests/dance_smoke.tscn
godot --headless --path . tests/ceremony_smoke.tscn
godot --path . tests/smoke.tscn -- --screenshots
godot --headless --path . --export-debug Android builds/pocket-party.apk
```

Tests redirect saves to `builds/test_save.json` and remove the test save afterward. Screenshots and logs are in ignored `builds/`. Export excludes tests, docs, and builds. Godot's Android export templates, Android SDK, and JDK 17 are already available on the development machine. Android minimum SDK 24, target 36, ARMv7 and ARM64; OpenGL compatibility renderer; sensor orientation; small through extra-large screens supported. Debug signing is for development; release signing is still required for store distribution.

See `docs/design.md` for decisions and remaining polish. This is a playable prototype, not a store-ready release.

The development laptop profile lives in `builds/laptop_party_save.json`; Android continues using its own `user://party_save.json`. Automated tests use separate temporary save files.

## Google Play publishing

Package: `com.frutylabs.pocketparty`. Public privacy policy: https://raw.githubusercontent.com/ed-fruty/pocketparty/main/PRIVACY_POLICY.md. Support: ed.fruty@gmail.com.

The `Google Play` export preset builds release App Bundles; the `Android` preset keeps the debug APK workflow. Store listing source and upload notes live in `publishing/google-play/`. Generated bundles, screenshots, graphics, verification reports, and the upload ZIP live in ignored `builds/google-play/`.

```sh
python3 tools/build_google_play.py
python3 tools/build_play_icon.py
godot --path . tools/capture_play_store.tscn
```

Restore your private upload key and `signing.json` into `builds/play-console-private/` before building on another machine. Those files are deliberately absent from GitHub and the upload ZIP. Increment the Google Play preset's version code for each subsequent upload. Do not recreate a missing upload key for an existing app.

Release verification and packaging: after `python3 tools/build_google_play.py`, run `python3 tools/verify_google_play.py` and `python3 tools/package_google_play.py`. Before submitting NetPlay, review `publishing/google-play/DATA_SAFETY.md`.
