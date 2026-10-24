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

## 0.2.1 generated IDs only

Removed custom tracking IDs from the configuration UI and runtime model. Prioritisation shows the computed ID as read-only text. Saved v1/v2 configurations and older text imports retain their assignments and cooldown settings but discard custom IDs. The UCC3 export format carries no trigger field. Macro generation, the displayed value and exact-message lookup all use the same player/ability-derived function. Tests cover custom-ID removal through both SavedVariables and import/export, rejection of old custom messages, canonical macro output and read-only UI rendering.

## 0.3.0 settings and export changes

The config schema remains version 3, while new copy/paste exports use `!UCC4!<Base64 payload>!<Adler-32>`. The payload is the existing UCC3 data-only representation. The checksum detects accidental corruption and is not an authenticity guarantee. Imports still accept older multiline formats, with optional surrounding quotes and omitted trailing blank fields. No third-party encoding library or executable serialization is used. The Lua encoder and checksum are compared against Python's standard-library Base64 and Adler-32 implementations.

The UI uses flat navy, blue and violet colours from the Devourer reference. All themed frames calculate border thickness from their own effective scale, and borders refresh on UI scale changes. Only explicit title-bar frames register drag handlers. The compact ability picker combines a class dropdown with its text search. No changes to cooldown tracking or the generated chat-ID rules are required.

## 0.4.0 follow-up — 25 October 2026

The current [Blizzard Macro UI](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_MacroUI/Blizzard_MacroUI.lua) uses `Constants.MacroConsts.MAX_CHARACTER_MACROS` and `MAX_ACCOUNT_MACROS`. Our previous comparison used the legacy global `MAX_CHARACTER_MACROS`; if absent, comparing a number to nil aborted before CreateMacro. The mock had supplied that old global and did not expose the defect. The implementation now prefers the current constants with a compatibility fallback. It verifies the name/body using `GetMacroInfo` after creation and reports API failures, nil results, full slots and verification failures in chat and settings. Tests now deliberately omit the legacy global and emulate stored macro bodies. A real client is still required to validate protected-action and taint behaviour.

Inspected [EllesmereUI_Fonts.lua](https://github.com/EllesmereGaming/EllesmereUI/blob/main/EllesmereUI_Fonts.lua): `EllesmereUI.GetFontPath()` with no key resolves the global font selection and handles locale-specific font resolution internally. UnhingedCC calls it defensively, falls back to the game font and then its original Blizzard FontObjects, and declares EllesmereUI as an optional dependency for load order. Fonts are applied to UnhingedCC's own regions only; no global fonts or external addon settings are changed. No font files are bundled.

Borders now use four solid, pixel-snapped texture strips instead of a backdrop edge texture. The title bar and sidebar use fills with no outlines; the sidebar has one divider. Presets live in their own SavedVariable, preserving them when importing or resetting the active configuration. Reset/load confirmations are local UI actions and are covered by the mock interaction suite.

## 0.5.0 panel styling and separate priority queues

The settings palette follows the supplied Guild & Communities and Achievements screenshots: warm near-black backgrounds, grey navigation rows, gold headings and brown section bands. Page structure, thin pixel-line outlines, font inheritance, title-bar dragging, presets, imports and generated chat IDs remain as before. No new art files or runtime libraries are required.

Automatic ability assignment now ranks kicks and stops independently. A new assignment appends to its category and the assigned entries in that category are numbered consecutively, preserving relative order. Replacements retain order and removals close gaps. The other category is untouched. Existing manually entered or imported values are preserved unless an assignment in that category changes; direct priority edits remain supported. Tests exercise sparse player/slot assignments, mixed kick/stop additions, replacement, removal, manual ordering and the actual picker callbacks.
