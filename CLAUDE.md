# HUEHACK — iOS App for Philips Hue Circadian Lighting

## Project Purpose
HUEHACK automates circadian lighting on a Philips Hue bridge by creating automation rules directly on the bridge. The core hack: rather than relying on Philips' built-in schedule (which only updates 1-2×/hour), HUEHACK installs rules that fire every 10 seconds via a virtual timer sensor, keeping color temperature in sync with time-of-day immediately when a light is turned on.

The user is in France — sunrise/sunset times vary significantly across the year, so the goal is to anchor color temperature segments to solar events (dawn, sunrise, sunset, etc.) rather than fixed clock times.

## Architecture Overview

### Entry Point
`HUEHACKApp.swift` — `RootView` checks `@AppStorage("hueBridgeIP")` and `@AppStorage("usernameKey")`: if both are set, shows `SetHoursView()` (old view — **not yet updated to route to new views**); otherwise shows `_a_welcome()` (onboarding).

> **Known issue**: the `New Views/` are all implemented and wired but **orphaned** — `RootView` routes to `SetHoursView()` when the bridge is already configured, so `1_overview`, `2_rules`, `3_settings` are never reached. The fix is in `HUEHACK-DEV/`: use `@AppStorage("hueOnboardingComplete")` flag and route to `__rooms()` (new grid view) with a settings toolbar button.

### File Structure
```
HUEHACK/
├── API/
│   ├── Rules.swift              # CORE: rule creation, deletion, parsing (~538 lines)
│   ├── Groups.swift             # Fetch rooms/groups from bridge
│   ├── Sensors.swift            # Virtual sensor management + installHUEHACKSensors()
│   ├── AppConfig.swift          # UserDefaults-backed singleton (ip, username, indices)
│   ├── Lights.swift             # Individual light control (incomplete)
│   ├── genericAPIcalls.swift    # HTTP wrapper (HueAPIManager)
│   ├── discovery.swift          # mDNS bridge discovery (NSNetServiceBrowser)
│   ├── Pairing.swift            # Bridge pairing (BridgePairingManager)
│   ├── Location.swift           # GPS + reverse geocoding (LocationManager)
│   └── Kelvins + mireds.swift  # Color temp conversions + SwiftUI Color extension
│
├── New Views/                   # New UI — fully implemented but orphaned (not reached from RootView)
│   ├── 0a_welcome.swift         # Intro screen → navigates to 0b
│   ├── 0b_welcome.swift         # Bridge discovery + pairing (functional, writes AppStorage) → navigates to 0d
│   ├── 0c_welcome.swift         # Backup config decision (stub — not in active flow)
│   ├── 0d_welcome.swift         # Room selection (functional — real groups from bridge, multi-select) → navigates to 0e
│   ├── 0e_welcome.swift         # Sensor installation (functional — calls installHUEHACKSensors) → navigates to 0f
│   ├── 0f_welcome.swift         # Solar segment config (functional — group picker + send to bridge wired)
│   ├── 1_overview.swift         # Main dashboard (toggle wired to sendGlobalOnOff, reads current state on appear)
│   ├── 2_rules.swift            # Rules list (functional — loads bridge + solar compare, update buttons wired)
│   └── 3_settings.swift         # Settings page (functional — bridge IP, masked username, sensor indices, reset)
│
├── OldViews/                    # Legacy UI — currently active entry point when bridge is configured
│   ├── SetHoursView.swift       # Main working view — group picker + segment list
│   ├── EditSegment.swift        # Edit one segment (time + temp slider + preview)
│   └── ...                     # Other old views
│
└── Data Layer/
    ├── DefaultValues Lists.swift # 10 preset segment configurations
    └── Persistence.swift         # Core Data (minimal, barely used)
```

## Key Data Model

```swift
struct Segment: Identifiable {
    var id = UUID()
    var name: String              // Solar event name or custom
    var hourStart: DateComponents // Hour + minute only
    var temp: Int                 // Mireds (153=6500K cool, 500=2000K warm)
    var synced: Synced            // .synced = on bridge, .notSynced = local only
    var show: Bool?               // Visibility in list
    var hourChanged: Bool = false // True when solar recalc would change the hour
}

enum Synced { case synced, notSynced }
```

## Config (done — backed by UserDefaults)
`AppConfig.swift` is a singleton that stores `ip`, `username`, `indexGlobalOnOff`, `indexTimer` in UserDefaults.
In `OldViews/SetHoursView.swift`, the four global vars are now computed proxies to `AppConfig.shared`:
```swift
var ip: String { get { AppConfig.shared.ip } set { AppConfig.shared.ip = newValue } }
// … same for username, indexGlobalOnOff, indexTimer
```
All API files reference these globals — no changes needed in API layer when config changes.

> **DEV improvement (to merge)**: `HUEHACK-DEV/API/AppConfig.swift` prefixes UserDefaults keys with `"hue"` (e.g. `"hueIndexGlobalOnOff"` instead of `"indexGlobalOnOff"`) to avoid collisions, makes the class `final`, and adds module-level computed `var` aliases so existing API callers keep working unchanged.

## The Circadian Hack — How It Works
1. Two virtual sensors are created on the bridge:
   - **Sensor 171** (`indexGlobalOnOff`): status=0 means HUEHACK enabled, status=1 means disabled
   - **Sensor 172** (`indexTimer`): a CLIP generic status sensor that auto-triggers every ~10 seconds via a self-referencing rule
2. For each time segment, a rule is created with 3 conditions:
   - Timer sensor `lastupdated` within 5 seconds (`ddx PT00:00:05`)
   - Local time `in` the segment's time range
   - Global on/off sensor `eq 0` (enabled)
3. Rule action: PUT `/groups/{id}/action` with `{"ct": <mireds>}`
4. Rules are named `HUEHACK-{groupIndex:02d}-{ruleIndex:02d}` for identification
5. No cloud, no Home Assistant — runs entirely on-bridge

## Color Temperature System
- Bridge uses **Mireds** (153–500), not Kelvin
- Formula: `mireds = 1,000,000 / kelvin`
- 153 mireds = 6500K (cool daylight), 500 mireds = 2000K (warm candlelight)
- `Color(mireds:)` and `Color(kelvin:)` extensions in `Kelvins + mireds.swift`
- Extension `Int.miredsToKelvin` for display

## Solar Events Used (SunCalc library)
Ordered by time, with default mireds:
| Event | Mireds | Show by default |
|-------|--------|-----------------|
| nightEnd | 500 | false |
| dawn | 325 | true |
| sunrise | 300 | true |
| sunriseEnd | 275 | true |
| goldenHourEnd | 250 | true |
| solarNoon | 250 | true |
| goldenHour | 250 | true |
| sunsetStart | 280 | true |
| dusk | 290 | true |
| night | 350 | true |
| nadir | 500 | true |

Solar events calculated via `SunCalc.getTimes(date:latitude:longitude:)`.
Location via `LocationManager` (CoreLocation) + `fetchCityName()` (reverse geocoding).

## Duplicate Functions (to consolidate)
- `fillListOfSegments()` — in `2_rules.swift`
- `fillListOfSegmentsInit()` — in `0f_welcome.swift`  
- `fillListOfSegmentsWrongHour()` — in `2_rules.swift` (demo data with fake sync states)

All three do basically the same thing. Should become one canonical function.

## What Works
- mDNS bridge discovery
- Bridge pairing (username generation via POST)
- Fetching groups/rooms from bridge
- Creating rules on the bridge (the hack)
- Deleting and re-creating rules per group
- Reading back existing rules and converting to Segments
- Color temperature conversions + SwiftUI color preview
- Solar time calculation from GPS location
- Sync/unsync visual state in segment list
- Persistent config via UserDefaults (AppConfig + global proxies)
- Onboarding routing (RootView checks config at launch)
- Virtual sensor installation (installHUEHACKSensors — creates TIMER + GLOBAL ONOFF + heartbeat rule)

## What's Incomplete / To Build

### ~~Priority 1 — `0f_welcome`: câbler "send to bridge"~~ ✅ DONE
- Sélecteur de groupe via `sendGETGroups` au chargement
- Bouton câblé à `createRulesFromlistOfSegments`
- Feedback visuel (progress, succès, erreur)
- Navigation vers `SetHoursView` après succès
- Fix: `createRulesFromlistOfSegments` utilisait des indices 171/172 hardcodés → corrigé pour utiliser les globales `indexGlobalOnOff`/`indexTimer`
- Navigation `0e → 0f` mise à jour (était `0e → SetHoursView`)

### ~~Priority 2 — `2_rules.swift`: lire le bridge + wirer les boutons~~ ✅ DONE
- Sélecteur de groupe via `sendGETGroups`
- `loadSegments()`: calcule solar + lit bridge via `getSegmentFromRulesForGroup`, compare position par position
  - `hourChanged = true` si heure solaire ≠ heure bridge
  - `.notSynced` si temp solaire ≠ temp bridge
- Boutons "update sun hours" et "update colors" : appellent `sendSolarToBridge()` → `createRulesFromlistOfSegments`
- Recharge depuis bridge après envoi réussi
- Note: `fillListOfSegments` (doublon) supprimé, remplacé par `fillListOfSegmentsInit` de `0f_welcome.swift`

### ~~Priority 3 — `0d_welcome`: vraie sélection de rooms~~ ✅ DONE
- Appelle `sendGETGroups()` au chargement, toutes les rooms pré-sélectionnées
- Multi-select avec checkmarks, nom + nombre de lumières par room
- Navigation `0b → 0d → 0e` câblée (0c toujours hors flow)
- Note: sélection non persistée — consommée uniquement par le flux onboarding (pas encore utilisée par 0f)

### ~~Priority 4 — `3_settings.swift`: page paramètres~~ ✅ DONE
- IP bridge, username masqué (4 premiers + 4 derniers chars), indices capteurs
- Bouton reset avec confirmation : vide bridgeIP + username → RootView bascule automatiquement en onboarding

### ~~Priority 5 — `1_overview.swift`: brancher l'API~~ ✅ DONE
- Toggle lit l'état réel du capteur `indexGlobalOnOff` au chargement via `sendGETSensors`
- `onChange` appelle `sendGlobalOnOff` (state 0=actif, 1=inactif)
- Slider `globalDim` supprimé — pas d'API de dim global sur bridge Hue v1
- Scènes hardcodées laissées en place (fonctionnalité future)

### Priority 6 — Fusionner HUEHACK-DEV dans HUEHACK
Le dossier `HUEHACK-DEV/` (copié dans le repo pour référence) contient des améliorations non fusionnées :

1. **`HUEHACKApp.swift`** : router vers `__rooms()` via `@AppStorage("hueOnboardingComplete")` + bouton settings toolbar
2. **`New Views/4_rooms.swift`** : nouvelle vue principale — grid 2 colonnes de RoomCards (couleur CT live + nom)
3. **`New Views/0b1_welcome.swift` + `0b2_welcome.swift`** : split de l'écran discovery/pairing en deux étapes
4. **`API/genericAPIcalls.swift`** : fix IP hardcodée → guard statement dynamique
5. **`API/AppConfig.swift`** : clés UserDefaults préfixées + aliases module-level + `final class`
6. **`API/Rules.swift`** : `saveSegmentMeta()` pour persister name+show state par groupe, nettoyage commentaires morts

### Onboarding flow — état actuel
```
0a → 0b (discovery+pairing) → 0d (room selection) → 0e (installation) → 0f (solar config) → [orphan]
```
`RootView` route vers `SetHoursView()` (vieux) si bridge configuré — les nouvelles vues ne sont jamais atteintes.
**Cible post-fusion** : `RootView` route vers `__rooms()` si `hueOnboardingComplete == true`.

## Build Info
- No external package manager (SunCalc embedded locally)
- App Sandbox enabled
- Entitlements: network client/server, location, Bonjour (_hue._tcp)
- No developer license — must rebuild to run on device
- Currently no TestFlight / AltStore setup

## Key Conventions
- API calls use completion handlers (not async/await) — keep consistent
- Rule naming: `HUEHACK-{groupIndex:02d}-{ruleIndex:02d}`
- Group indices are Strings in the dict but cast to Int for API calls
- Segments must be sorted with "first" segment (lowest hour post-midnight) moved to end (circular schedule)
- Live color preview: `Rectangle().foregroundStyle(Color(mireds: Double(segment.temp)))` — keep in edit views
