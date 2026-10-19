# NetPlay

Create Room on one device. Join from the nearby room browser on up to three other devices, or enter the host's local IPv4 address. All devices must run a compatible game build and share a network that allows device-to-device traffic. Guest Wi-Fi/client isolation can block both discovery and direct connections. No WAN port forwarding or backend is used.

The host occupies P1. Connected friends occupy P2–P4. The host can use bots or empty unused seats, select quick play or build a tournament, pause/resume everyone, and advance rounds. Other devices can control only their assigned seat. Each device uses its own existing profile and equipped P1 skin as its network avatar. Only that player's wins award gold on that device. There is no cloud synchronization.

All eight games use host-authoritative simulation and 30Hz compressed state snapshots. BurgerTower physics run only on the host. Pair Peek reveals only exposed card symbols in network snapshots. Darkspots validates recent displayed positions with a bounded 250ms window. The host validates action type, seat ownership, round ticket and game rules; client input cannot directly set scores, gold or outcomes. Local progress and a player-hosted authority cannot provide tamper-proof currency.

An unfinished match returns everyone to the room if a participant disconnects; it does not award that unfinished round. Host loss ends the room. There is no host migration or mid-match join. A readiness handshake holds the start until participating devices have loaded. A 12-second loading/host-state timeout provides an escape from a stalled session.

ENet UDP port 47638; room announcements UDP broadcast port 47639. Only the join screen listens for discovery. Same-computer testing can use 127.0.0.1. Only one host per device/port. No object deserialization is enabled for network snapshots. Discovery packets are size limited; snapshot decompression is bounded.

Android exports enable INTERNET for LAN sockets. Current target SDK is 36; before moving to target 37+, implement and test Android's ACCESS_LOCAL_NETWORK runtime permission. No location, contacts, microphone, camera, advertising or Bluetooth permissions are added.

## Verification

Run `python3 tools/test_netplay.py` from this project. It launches four real ENet processes using isolated test saves under builds/, exercises every game, seat ownership, ties, local-only rewards, duplicate result messages and a two-round tournament. Run `python3 tools/test_netplay.py --disconnect` to verify UDP discovery, friend/bot/empty seats, seat ownership, stale-round rejection, aborts without rewards, reconnecting, pause/resume and host loss. Existing native gameplay suites still apply. Physical-device Wi-Fi behavior requires testing on the intended phones/router.

## Store disclosures

The privacy policy now describes optional direct device-to-device gameplay, temporary connection data, skin/input/state exchange, local rewards and the lack of transport encryption. Do not reuse the previous no-network declaration without reassessing Play Data safety: data sent to another device may fall within Google's collection definition even if the publisher has no backend and processing is ephemeral. Review gameplay/app interactions, temporary connection identifiers, optional processing, user-initiated transfers and encryption answers against the final implementation. No analytics or advertising SDK has been added.
