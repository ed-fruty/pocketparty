# Data safety guidance — 0.3.2 (code 6)

Package: com.frutylabs.pocketparty. This is a proposed mapping for the shipped implementation, not a submitted Console declaration. Review it against the questions shown in your Console. The publisher receives no gameplay sessions; this does not automatically mean that nothing is collected under Google's off-device definition.

## Suggested form mapping

| Console item | Build-specific answer / basis |
| --- | --- |
| Does the app collect any required user data types? | Yes: optional NetPlay transmits gameplay and connection information off-device to room members. |
| App activity → Other actions | Collected; optional; app functionality. This category explicitly includes gameplay. Covers moves, game state, skin selection, scores and round/tournament results. |
| Device or other IDs | Conservatively disclose temporary per-session connection IDs and local network addresses used to connect app instances. Collected; optional; app functionality. No persistent hardware, advertising, Android or installation identifier is accessed. |
| Ephemeral processing — gameplay | Do not mark the entire category ephemeral: scores/results/standings remain available for the round or tournament and results display; a player's derived gold reward is saved locally. |
| Ephemeral processing — connection data | Used only in memory for discovery/connections and not written to progress saves. If you select ephemeral processing, this still belongs in the form response under Google's guidance. |
| Shared with third parties | No publisher sale, ads, analytics or server-to-server sharing. Local room transfers are initiated explicitly by Create/Join and expected by players; Google's user-initiated transfer exception may support answering not shared for these transfers. Review the exact definition in Console. |
| Encrypted in transit | No. ENet gameplay packets are not encrypted by the app. Wi-Fi security alone does not justify answering yes. |
| Purpose | App functionality only. No analytics, advertising, personalization profiles, account management or developer marketing. |
| Optional vs required | Optional for every player: all games remain available in single-device mode without NetPlay. |
| Location | Not collected or inferred. Private network addresses are used for connectivity, not geolocation. |
| Name, email, contacts, messages, photos, microphone, files, payment information | Not accessed or transmitted by gameplay. Support email is voluntary and handled by an external email app, outside the game's own collection. |
| Advertising ID, Android ID, MAC, IMEI, account user IDs, crash/analytics uploads | None. |
| Accounts / account deletion | No account creation or login. Clear app storage/uninstall to remove local progress. A support-correspondence deletion request can be sent to ed.fruty@gmail.com. |
| Independent security review | Do not claim one; none was performed. |

Temporary numbered seats do not identify a real-world person. This game has no public matchmaking, user names, text chat, freeform content or cloud saves. The table takes a conservative approach to connection identifiers; Google notes that event-only identifiers not reasonably related to a device/app instance do not need the Device IDs declaration. The publisher must decide the final mapping based on the actual Console wording and implementation.

## Families, access and listing

- App access: all functionality available without credentials; no reviewer account needed. NetPlay requires two compatible devices on a local network allowing peer communication.
- Ads: no. In-app purchases: no. Currency is earned game gold, not purchased or real money.
- Keep the selected age groups aligned with the intended audience and answer IARC truthfully, including cartoon snake predation and obstacle elimination.
- There are no social messaging features. Synchronizing an existing game is not freeform player communication.
- Privacy URL: https://raw.githubusercontent.com/ed-fruty/pocketparty/main/PRIVACY_POLICY.md

## Sources checked October 19, 2026

- Collection, ephemeral processing, user-initiated sharing exceptions and data categories: https://support.google.com/googleplay/android-developer/answer/10787469
- Privacy policy and account deletion: https://support.google.com/googleplay/android-developer/answer/10144311

Google defines collection as sending data off a user's device. Other actions includes gameplay. Declaring ephemeral processing does not excuse omitting the data from the form. The Console declarations must match this policy and build; do not reuse the previous single-device/no-network answers without updating them.
