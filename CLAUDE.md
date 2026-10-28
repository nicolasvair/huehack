# HUEHACK — iOS App for Philips Hue Circadian Lighting

## Project Purpose
HUEHACK automates circadian lighting on a Philips Hue bridge by creating automation rules directly on the bridge. The core hack: rather than relying on Philips' built-in schedule (which only updates 1-2×/hour), HUEHACK installs rules that fire every 10 seconds via a virtual timer sensor, keeping color temperature in sync with time-of-day immediately when a light is turned on.

The user is in France — sunrise/sunset times vary significantly across the year, so the goal is to anchor color temperature segments to solar events (dawn, sunrise, sunset, etc.) rather than fixed clock times.

## Architecture Overview

### Entry Point
`HUEHACKApp.swift` routes on `@AppStorage("hueOnboardingComplete")` only: `true` → `__rooms()` (grid, settings button in the toolbar), `false` → `_a_welcome()` (onboarding). Each branch has its own `NavigationStack`, so finishing onboarding (`0f` sets the flag) lands on the rooms view instead of leaving the welcome screens pushed on top. A one-shot migration in `init()` (guarded by `hueOnboardingMigrated`) marks pre-flag installs as onboarded without defeating "Relancer l'onboarding" in settings.

### File Structure
```
HUEHACK/
├── API/
│   ├── Rules.swift              # CORE: rule creation, deletion, parsing (~538 lines)
│   ├── Groups.swift             # Fetch rooms/groups from bridge
│   ├── Sensors.swift            # Virtual sensor management + installHUEHACKSensors()
│   ├── RoomOverride.swift       # Per-room circadian pause (OVR sensor, reset rule, migration)
│   ├── AppConfig.swift          # UserDefaults-backed singleton (ip, username, indices)
│   ├── Lights.swift             # Individual light control (incomplete)
│   ├── genericAPIcalls.swift    # HTTP wrapper (HueAPIManager)
│   ├── discovery.swift          # mDNS bridge discovery (NSNetServiceBrowser)
│   ├── Pairing.swift            # Bridge pairing (BridgePairingManager)
│   ├── Location.swift           # GPS + reverse geocoding (LocationManager)
│   └── Kelvins + mireds.swift  # Color temp conversions + SwiftUI Color extension
│
├── New Views/                   # Active UI (entry point: 4_rooms via HUEHACKApp)
│   ├── 0a_welcome.swift         # Intro screen → navigates to 0b
│   ├── 0b_welcome.swift         # Bridge discovery + pairing (functional, writes AppStorage) → navigates to 0d
│   ├── 0c_welcome.swift         # Backup config decision (stub — not in active flow)
│   ├── 0d_welcome.swift         # Room selection (functional — real groups from bridge, multi-select) → navigates to 0e
│   ├── 0e_welcome.swift         # Sensor installation (functional — calls installHUEHACKSensors) → navigates to 0f
│   ├── 0f_welcome.swift         # Solar segment config (functional — group picker + send to bridge wired)
│   ├── 1_overview.swift         # Main dashboard (toggle wired to sendGlobalOnOff, reads current state on appear)
│   ├── 2_rules.swift            # Rules list (functional — loads bridge + solar compare, update buttons wired)
│   ├── 3_settings.swift         # Settings page (functional — bridge IP, masked username, sensor indices, reset)
│   ├── 7_manual_color.swift     # ManualColorSheet (Blancs / Couleurs, live preview)
│   ├── 8_segment_editor.swift   # SegmentEditorSheet (segment ct, live preview)
│   └── LightControls.swift      # Shared: GradientSlider, WhiteTemperaturePicker, HueSaturationPicker, BrightnessSlider, LightSwatch, LiveLightPreview
│
├── Segment.swift                # Segment model + Synced + timeStr()
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
`AppConfig.swift` also exposes module-level read-only aliases (`ip`, `username`, `indexGlobalOnOff`, `indexTimer`) used by the API layer.
All API files reference these globals — no changes needed in API layer when config changes.

> **DEV improvement (to merge)**: `HUEHACK-DEV/API/AppConfig.swift` prefixes UserDefaults keys with `"hue"` (e.g. `"hueIndexGlobalOnOff"` instead of `"indexGlobalOnOff"`) to avoid collisions, makes the class `final`, and adds module-level computed `var` aliases so existing API callers keep working unchanged.

## The Circadian Hack — How It Works
1. Virtual sensors are created on the bridge:
   - **Sensor 171** (`indexGlobalOnOff`): status=0 means HUEHACK enabled, status=1 means disabled
   - **Sensor 172** (`indexTimer`): a CLIP generic status sensor written every 10 seconds by the `HUEHACK-TIMER` schedule
   - **Per room** `HUEHACK-OVR-{g:02d}` (CLIPGenericStatus, uniqueid `huehack-ovr-{g:02d}`): status 0 = circadian running, 1 = paused (manual colour), 2 = reprise en attente (luminosité remise à 100 % au prochain allumage). Id cached in UserDefaults `huehack-ovr-<g>`.
2. For each time segment, a rule is created with 4 conditions:
   - Timer sensor `lastupdated` within 5 seconds (`ddx PT00:00:05`)
   - Local time `in` the segment's time range
   - Global on/off sensor `eq 0` (enabled)
   - Room pause sensor `HUEHACK-OVR-{g}` `eq 0` (omitted — 3 conditions — if the sensor could not be obtained)
3. Rule action: PUT `/groups/{id}/action` with `{"ct": <mireds>, "transitiontime": <fade>}` — fade in deciseconds, per room (`roomFade`, UserDefaults `huehack-fade-<g>`, default 4 = 0.4 s, the bridge default), stored in the segment meta at push (`lastPushedFade`). Read-back only decodes `ct` (extra keys ignored). The rule re-fires every ~10 s, so a fade > 10 s is restarted from the current colour on each tick (ease-out): sent as is it would last far longer (1 min → ~2 min 45). `bridgeTransitionTime(forFade:)` (RoomLinks.swift) shortens the value actually sent so the light is within 5 % of its target after the chosen time (30 s → 158, 1 min → 254 deciseconds); ≤ 10 s is sent unchanged. UserDefaults, meta and UI keep the chosen duration.
4. Rules are named `HUEHACK-{groupIndex:02d}-{ruleIndex:02d}` for identification
5. Per room, two auto-resume rules (switching the room off ends the pause):
   - `HUEHACK-OVRRESET-{g:02d}`: `/groups/{g}/state/any_on dx` + `eq false` + OVR `eq 1` → OVR `{"status":2}`
   - `HUEHACK-OVRRESTORE-{g:02d}`: `any_on dx` + `eq true` + OVR `eq 2` → PUT `/groups/{g}/action` `{"bri":254}` + OVR `{"status":0}` (les règles n'envoient que ct : sans ça la luminosité manuelle resterait ; le ct suit au tick suivant, ≤ 10 s)
   `parseHUEHACKRuleName` does not match them, so per-group deletes never remove them. `ensureOverrideResetRule` (re)crée les deux, et remplace les anciennes versions (reset vers status 0).
6. **Rule action `body` must be compact JSON**: the bridge measures it as raw text (spaces included) and rejects it with type 7 « too big for parameter, body ».
7. **Timer loop**: a bridge **schedule** `HUEHACK-TIMER` (`localtime: "R/PT00:00:10"`) PUTs `{"status":0}` on the TIMER sensor every 10 s — that write updates `lastupdated`, which the segment rules watch. (A self-triggering rule does NOT work: the old `HUEHACK-HEARTBEAT` rule never fired; it is now deleted.) `ensureTimerRunning()` (Sensors.swift) creates/replaces the schedule if missing or pointing at another sensor; called at install, on `__rooms` load and after each rule push. The wipe « HUEHACK seulement » also deletes `HUEHACK*` schedules.
8. No cloud, no Home Assistant — runs entirely on-bridge

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
- Virtual sensor installation (installHUEHACKSensors — creates TIMER + GLOBAL ONOFF + 10 s schedule)

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
0a → 0b (discovery+pairing) → 0d (room selection) → 0e (installation) → 0f (solar config) → __rooms
```
`0f` met `hueOnboardingComplete = true`, ce qui remplace la racine par `__rooms()`.

## Link entre pièces (API/RoomLinks.swift)
Un lien = un groupe de pièces qui partagent le même planning. Les liens sont **symétriques et complets** :
chaque membre stocke la liste des autres dans `huehack-links-<groupIndex>` (JSON `[String]`).
- Chaque pièce garde ses **propres règles sur le bridge** et son **propre offset** — l'état de sync affiché
  correspond donc toujours à ce qui est réellement installé.
- Le lien n'agit qu'au moment du push : `Update` envoie le planning à la pièce courante puis à chaque pièce liée,
  en réappliquant l'offset propre à chacune.
- **La transition (fade) est partagée par le groupe**, l'offset reste par pièce : `setLinkGroupFade` écrit le fade
  sur tous les membres ; `updateRoomLinks` fait adopter le fade de la pièce courante aux pièces qui rejoignent
  (avant le push immédiat) ; `applyUpdate` réécrit le fade sur tout le groupe avant de pousser (défensif).
- `migrateAndPruneRoomLinks(existingIndices:)` convertit l'ancien stockage master/follower
  (`huehack-linkedTo-<idx>`), supprime les liens vers des pièces disparues et répare les groupes
  incomplets (chaque membre doit lister tous les autres).
- `updateRoomLinks(for:to:)` applique une sélection multiple : les pièces décochées quittent le groupe
  (les autres restent liées entre elles), les pièces cochées le rejoignent — une pièce déjà dans un autre
  groupe **quitte** son ancien groupe (les autres membres y restent liés entre eux), pas de fusion. Retourne les pièces qui viennent de rejoindre le groupe.

UI (`2_rules.swift`) :
- Bouton **icône seule** 🔗 (`.font(.title)`, zone 44pt) → sheet `LinkRoomsSheet` : checklist multi-sélection
  des autres pièces, « déjà liée à … » si une pièce appartient à un autre groupe (« quittera son lien avec … » une fois cochée), Annuler / Valider.
- À la validation, si des pièces rejoignent le groupe, le planning de la pièce courante est **poussé
  immédiatement** à tout le groupe (`applyUpdate`) — sinon les pièces ajoutées garderaient leur ancien
  planning. Si le planning n'est pas encore chargé, fallback sur le bouton Update (`linksChanged`).
- Bandeau « Planning partagé avec … » sous la barre du haut (tap → même sheet).
- « Copier les horaires depuis » est un menu séparé (icône `doc.on.doc`) : copie ponctuelle, sans lien.
- `4_rooms.swift` : badge 🔗 sur les cartes liées, compteur rafraîchi à chaque `onAppear`.
- Bouton `dial.medium` (offset) → `OffsetEditorSheet` : offset + Picker « Transition » (Instantané, 0,4 s (défaut),
  1 s, 2 s, 5 s, 10 s, 30 s, 1 min) avec légende (allumage, « Appliqué à toutes les pièces liées »). Icône `timer`
  sur le bouton si fade ≠ défaut. Update apparaît si `lastPushedFade` ≠ fade courant (comme l'offset poussé).
  `resumeCircadian` envoie aussi le fade avec le ct immédiat.

## Pause circadienne par pièce (API/RoomOverride.swift, New Views/7_manual_color.swift)
- Bouton `paintpalette` dans la barre de `2_rules.swift` → `ManualColorSheet`, deux onglets + curseur de luminosité commun :
  - « Blancs » : barre froid (153) → chaud (500), `ManualLight.white` → `{"on":true,"ct","bri"}` — seul onglet utile pour les lampes « Color temperature light ».
  - « Couleurs » : curseurs Teinte et Saturation (blanc → vif), `ManualLight.color` → `{"on":true,"hue","sat","bri"}`. Seul le curseur de luminosité change `bri`.
  - S'ouvre sur l'onglet du `colormode` actuel (`hs` → Couleurs, sinon Blancs).
  - **Aperçu en direct** (`LiveLightPreview`, LightControls.swift) : au premier changement `beginManualPreview` (OVR = 1), puis envois au plus une fois par seconde (le bridge ne tient qu'~1 commande de groupe/s et met le reste en file : plusieurs secondes de retard), une requête à la fois, dernière valeur gagnante, et seulement les attributs qui ont changé (`sendManualPreview(after:)`). « OK » → `applyManualColor` (après la dernière requête en vol) ; « Annuler » → `cancelManualPreview` remet l'action précédente (on/off, bri, ct / hs / xy) et l'état de pause d'avant. Glisser pour fermer est désactivé.
- Édition d'un créneau (tap sur une ligne de `2_rules.swift`) → `SegmentEditorSheet` : mêmes composants (`LightSwatch` + `WhiteTemperaturePicker`), aperçu en direct en ct seul (`sendManualPreview(bri: nil)` : ni allumage ni luminosité), Annuler / OK. À la fermeture la pièce est remise comme avant (`cancelManualPreview(restoreOnAndBrightness: false)`) ; OK garde la valeur dans `newTemp` / `tempChanged`, envoyée aux règles avec Update.
- `applyManualColor(groupIndex:light:bri:)` : `prepareRoomOverride` (capteur OVR + règle reset + condition OVR sur les règles de la pièce) → OVR = 1 → **puis** PUT `/groups/{g}/action` (l'ordre inverse laisserait un tick écraser la couleur).
- Bandeau « Circadien en pause — couleur manuelle » + « Reprendre » → `resumeCircadian` : pièce allumée → OVR = 0, puis si l'interrupteur global est actif, envoi immédiat de `bri` 254 + ct du segment courant (base + offset des règles poussées, `clampMireds`) ; pièce éteinte → OVR = 2 (la règle OVRRESTORE remet la luminosité au prochain allumage).
- `ensureOverrideSensor` : GET /sensors brut (JSONSerialization), recherche par nom exact (id le plus bas si doublons), jamais de création après une lecture échouée, jamais de remise à zéro du statut, appels concurrents fusionnés par pièce.
- Pousser un planning (Update, pièces liées) **ne change jamais** l'état de pause ; la pause reste par pièce même pour des pièces liées.
- Migration silencieuse une fois par session (`migrateLegacyRulesToOverride`, lancée par `__rooms` après chargement des groupes, hors demoMode) : `PUT /rules/{id}` avec les conditions existantes + la condition OVR (ids, noms, actions et meta conservés), pièce par pièce, séquentiellement.
- `4_rooms.swift` : un GET /sensors à l'apparition → badge `pause.circle.fill` ; carte remplie avec la couleur hue/sat si `colormode == "hs"`.
- Suppression d'une pièce (`5_rooms_edit.swift`) : règles segments + `HUEHACK-OVRRESET-NN` + `HUEHACK-OVRRESTORE-NN` + capteur `HUEHACK-OVR-NN` + clé `huehack-ovr-<g>`, puis le groupe. Le nettoyage « Supprimer les règles HUEHACK » (préfixe `HUEHACK`) et `clearLocalHUEHACKState` (préfixe `huehack-`) les couvrent déjà.
- demoMode : `demoPausedRooms` (DemoData.swift), aucun appel réseau.

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
