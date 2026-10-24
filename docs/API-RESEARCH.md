# API research for UnhingedCC 0.1.0

Research date: 24 October 2026. These are reference observations, not an in-client compatibility certification.

## Retail target

The [live WoW UI source mirror](https://github.com/Gethe/wow-ui-source/commit/15881d522c44cd106d3d8660106ec9f9d2f44167) identifies its latest commit as **12.1.5 (70575)**, dated 23 October 2026. This is a mirror of Blizzard's shipped UI and generated documentation, rather than an official developer website. Both reference addons use Interface **120105**, which this addon targets.

- [Generated chat API](https://github.com/Gethe/wow-ui-source/blob/15881d522c44cd106d3d8660106ec9f9d2f44167/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua): `CHAT_MSG_PARTY`, `CHAT_MSG_PARTY_LEADER`, `CHAT_MSG_INSTANCE_CHAT`, `CHAT_MSG_INSTANCE_CHAT_LEADER` are marked `SecretInChatMessagingLockdown = true`. Message and sender are not marked `NeverSecret`. `SendChatMessage` has restrictions including `RestrictedForMacroChatMessages`.
- [Generated spell API](https://github.com/Gethe/wow-ui-source/blob/15881d522c44cd106d3d8660106ec9f9d2f44167/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua): `C_Spell.GetSpellCooldown(spellIdentifier)` has no unit argument and is `SecretWhenCooldownsRestricted`. `GetSpellCooldownDuration` supplies a duration object suitable for supported displays, not an unrestricted numerical cooldown for arbitrary party members.
- `issecretvalue` guards run before type-based parsing, string operations, lookup or comparison on chat payloads. There is no declassification attempt. Unreadable events are counted and skipped.

## Northern Sky Winds Helper

Inspected [NorthernSkyRaidTools at 190084a202cd7359c42616419acf8d9c98cc25f3](https://github.com/Reloe/NorthernSkyRaidTools/tree/190084a202cd7359c42616419acf8d9c98cc25f3), specifically [Sszorak.lua](https://github.com/Reloe/NorthernSkyRaidTools/blob/190084a202cd7359c42616419acf8d9c98cc25f3/NorthernSkyRaidTools/EncounterAlerts/MidnightS2/Sszorak.lua), Winds Helper and `DisplayWind`.

It creates `/raid 1` through `/raid 8` macros. The event callback passes the message unchanged to `DisplayWind`; the display uses `SetFormattedText` to interpolate it into a raid-target texture string. The visible slot index increments independently of the message content. Its preview deliberately uses `secretwrap`, confirming that the implementation is designed to display secret inputs.

This is meaningfully different from branching on `Brick:4`, validating its sender and choosing a timer duration. Displaying a secret value does not make it available for parsing or use as a Lua lookup key. No reliable replacement for the requested trigger was found in this helper. Per the user's instruction, this draft implements the guarded chat-based fallback for in-game testing.

No source code from the reference addon is bundled.

## EllesmereUI

Inspected [EllesmereUI at 5622298cea39f8bfc20500daf18dcb0dd37c702f](https://github.com/EllesmereGaming/EllesmereUI/tree/5622298cea39f8bfc20500daf18dcb0dd37c702f), especially `EllesmereUI_Kick.lua`, `EllesmereUI_KickData.lua` and its TOC. Useful practices include namespaced data, explicit spell tables, secret-value guards, separating tracking data from rendering, and using current `C_Spell` APIs.

Its kick data documents talent/spec modifiers (for example Restoration Shaman's different Wind Shear cooldown and Quick Witted for Counterspell). Such inference can estimate maximum cooldowns, but does not provide authoritative live cooldown state for another player. This first draft therefore uses explicit per-slot overrides rather than adding expensive talent inspection and suggesting it is exact.

## Cooldown source

For each entry in `Abilities.lua`, retrieved `https://nether.wowhead.com/tooltip/spell/SPELL_ID` over verified HTTPS on the research date. Parsed the primary `<!--cooldownText-->` field from each Retail tooltip. Names, icons and positive cooldown values were recorded. `docs/cooldowns.tsv` records the retrieved values and per-spell source URLs. No runtime requests are made by the addon.

Example: Chaos Nova (179057) returned **45 sec cooldown**, with an additional conditional 33-second tooltip variant. The catalog uses 45; an override can represent the player's 33-second build. Baselines are not talent-adjusted and the public endpoint is not pinned to a historical patch. Recheck when editing/upgrading the catalog.

Cyclone and Sleep Walk returned no cooldown text and are omitted from this positive-cooldown catalog. Charged/resettable abilities in the catalog are only approximated by one timer; the draft does not claim charge tracking or cast-success confirmation.

## Validation boundary

The Lua 5.1 suite runs the actual addon source with mocked frame, spell, roster and macro APIs. It verifies parsing, identity matching, ordering, config safety, UI callbacks, pooling and timer shutdown. Only a real Retail client can verify rendering, protected-action restrictions, taint interactions, macro message delivery and availability of readable announcements in combat. See README for that test sequence.

## 0.2.0 expansion and observed behaviour

The user reports the original chat-based cooldown tracking works in their in-game tests. The secret-value guards remain in place for contexts where message payloads are restricted.

Expanded the catalog by 26 positive-cooldown entries (79 total), using the same verified HTTPS Retail tooltip endpoint and primary baseline cooldown field. Source links and values are in `cooldowns.tsv`. Entries include additional interrupts, roots, displacements, PvP talents and racials; tooltip notes explain important restrictions. The Earthgrab aura (64695) has no cooldown and is not added; the actual cast, Earthgrab Totem (51485), has a 30-second baseline and is added.

Devourer was checked against Wowhead's [Devourer talent list](https://www.wowhead.com/spells/talents/demon-hunter/devourer) and [class ability list](https://www.wowhead.com/spells/abilities/demon-hunter/devourer). The talent list identifies **Void Nova (1234195)** with specialization **1480**, and its [Retail tooltip](https://nether.wowhead.com/tooltip/spell/1234195) reports **45 seconds**, an eruption that stuns the target and nearby enemies. The class ability list identifies **Disrupt (183752)** as the shared interrupt. Void Nova is a distinct selectable entry; it is not aliased to Chaos Nova. Its default message is `PlayerVoidNova`; the shared kick uses `PlayerKick`.

The new appearance uses custom solid-colour panels, borders and buttons without native gradient button/input skins. A searchable icon grid replaces the old text dropdown. The setup window uses a sidebar and per-player icon strips. Tracker headers and their padding are removed; only temporary unlock overlays remain. Row gaps are calculated in physical pixels using UIParent's effective scale.
