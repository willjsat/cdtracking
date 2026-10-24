# UnhingedCC

A lightweight World of Warcraft **Retail 12.1.5** addon for manually announced party interrupts and crowd control. Version 0.2.0; Interface 120105. No runtime dependencies or bundled libraries.

## Install

Copy the **UnhingedCC** folder into `_retail_/Interface/AddOns/` so the TOC is at `AddOns/UnhingedCC/UnhingedCC.toc`. Restart WoW or reload if the addon is already discovered. Open `/ucc` (also `/unhingedcc`).

1. In **Party Setup**, enter up to five character names, including your own. Prefer `Name-Realm` for cross-realm parties. Choose one kick in slot 1 and up to four stops in slots 2–5 using the compact icon strips. Click a + to add or an icon to replace; the picker supports name/class/spec search. Press Enter to save names.
2. In **Prioritisation**, assign numeric priorities (1 is highest). Kicks are listed together; stops are grouped under their owner. Priorities reposition immediately as you type. Ties use party/slot order.
3. The exact chat value defaults to `PlayerKick` for interrupts (for example `AngeelsKick`) or `PlayerCondensedAbilityName` for CC (for example `AngeelsChaosNova` or `AngeelsVoidNova`). Realm suffixes are excluded from the message but retained for sender validation. Spaces and punctuation are removed from the English ability name, so Dragon's Breath becomes `AngeelsDragonsBreath`. Edit it for a custom message. Leave CD blank for the catalog baseline, or enter a talent-adjusted cooldown in seconds (0.1–3600). All clients should import the same config.
4. **Copy** provides macro text to paste into WoW's macro editor. **Create** makes a new character macro for your own configured character, outside combat, without overwriting any existing macro. Drag it from `/macro` to an action bar. For another player, copy the text and send it to them yourself.
5. **Unlock Bars** on either tab lets you drag each group's temporary mover overlay, then **Lock Bars** saves its position. `/ucc unlock` and `/ucc lock` also work. Empty groups are visible only when unlocked.
6. **Export / Import** uses a bounded, versioned, plain text config. Import replaces assignments and priorities, retaining local frame positions and lock state. No Lua is executed.

Example macro (three separate lines):

```text
#showtooltip Chaos Nova
/cast Chaos Nova
/party AngeelsChaosNova
```

Macros generated while in an instance group use `/instance` instead. Recreate/copy the macro if switching between premade party and instance chat. Spell names are localized through `C_Spell.GetSpellName`.

## Upgrading from 0.1.0

Saved variables and `UCC1` imports automatically migrate to the new `UCC2` config format. Assignments, priorities, overrides, frame positions and lock state are retained. Numeric IDs such as `Angeels:4` become the appropriate readable ID, including when the old UI saved a generated ID explicitly. Truly custom chat messages are retained. The new generated IDs follow the ability rather than its slot and update automatically when a player or spell changes.

**Recreate or edit your macros after updating.** Existing macros are never overwritten automatically. All trackers need the updated config; the old generated numeric messages are no longer recognized. Export a backup before upgrading.

The catalog now contains **79 spell entries**, including Devourer's Void Nova (45 sec baseline), the shared Disrupt interrupt, additional class/spec/pet controls and four racial stops. Notes identify special requirements. Roots, disarms and pulls are CC options; they do not necessarily interrupt every cast.

## Display and tracking

Two headerless lists, 20% narrower overall than v0.1.0 and with a one-physical-pixel gap between rows: left-hand ability icon, class-coloured status bar, player name and remaining seconds. Ready abilities show a full bar, ordered by priority. Cooling abilities drain toward zero, ordered by remaining time then priority. When an ability becomes ready it returns to its priority position above active timers.

Only **exact** configured messages from the configured party member are accepted. Party, party leader, instance chat, instance leader and your own echoed messages are supported. The sender must resolve through the current party roster. Ambiguous short names are rejected; use full realm-qualified names. Repeated announcements during an active timer are ignored. No addon installation is required for the announcing player; they only need the macro.

### Known limitations — please test in game

- **12.1.5 chat restrictions:** party and instance-chat message/sender payloads may be secret under chat-messaging lockdown. These events are skipped safely, with a one-time warning and `/ucc status` counter. This draft cannot guarantee combat tracking. It does not attempt to remove secrecy or bypass restrictions.
- `/cast` followed by `/party` announces even if the cast fails. Cooldowns are estimates based on the announcement, not confirmed spell usage. Chat throttling, latency and lost announcements can affect accuracy.
- There is no supported unit parameter on `C_Spell.GetSpellCooldown` for querying a party member. Talent/spec inspection can estimate cooldowns, but cannot prove their actual current cooldown, resets or reductions. Use per-slot overrides for this draft.
- No charge recovery, reset detection, cooldown synchronization, talent inspection, or automatic spec filtering. A charged ability is modelled as a single timer; avoid it if that is unsuitable. Catalog entries may require specific specs/talents/pets.
- Timers clear on reload/login. Config and frame positions persist. `/ucc reset` clears current timers manually. Config edits preserve timers for unchanged player/slot/spell assignments.
- The catalog deliberately covers abilities with a positive tooltip cooldown. Zero-cooldown CC such as Cyclone is omitted. This is a starter catalog, not every racial or pet ability.

## Edit the ability catalog

**[UnhingedCC/Abilities.lua](UnhingedCC/Abilities.lua)** is the single editable catalog. Each spell ID has `name`, `class` (WoW class token, or `RACIAL`), `kind` (`kick` or `stop`), `cooldown` (baseline seconds) and `icon`. Optional `note` is searchable and shown in tooltips; optional `token` overrides the condensed English chat suffix. Add/remove entries there and reload. Removing an in-use entry makes the saved config invalid: export first, clear its assignments before removal, and keep a backup. Invalid saved configs are preserved rather than silently overwritten.

Cooldowns were fetched from Wowhead Retail tooltips on 24 October 2026; details and evidence are in [docs/API-RESEARCH.md](docs/API-RESEARCH.md) and [docs/cooldowns.tsv](docs/cooldowns.tsv).

## Performance

Exact-message lookup before roster resolution; no combat-log scanning, inspection polling, permanent ticker or network requests. Rendering uses at most 25 reusable bars. A single throttled 20 Hz update handler runs only while estimated timers are active, stopping once all are ready. Sorting happens on config/roster changes, accepted announcements and readiness transitions, rather than every frame. Config and picker widgets are pooled across redraws; the config UI is created on demand. No shared global API hooks or runtime external libraries.

## Development and validation

```sh
python -m venv .venv
.venv/bin/pip install -r tests/requirements.txt
.venv/bin/python tests/run.py
```

Tests execute the actual addon Lua in Lua 5.1 via Lupa, including model/config validation, sender matching, timer sorting, event initialization, macro creation, frame reuse and idle timer shutdown. The mocked API cannot establish real client rendering, taint safety or combat availability.

Before use: enable script errors (`/console scriptErrors 1`), configure two real party members, test announcements from each, reject spoofed/partial messages, verify cooldown/priority transitions, drag/lock both groups, import/export and reload. Repeat in a dungeon during combat and check `/ucc status`. Test premade party and instance groups separately. Verify macros when casts fail, as those still announce. Run alongside your usual addons and check CPU/memory in game.

To package: `python tools/package.py` creates `dist/UnhingedCC-0.2.0.zip` containing only the installable addon folder.
