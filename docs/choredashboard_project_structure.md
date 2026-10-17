# Project Architecture & Structure: `ChoreDashboard`

### **Core Principles Embodied in This Structure**

*   **Architecture Pattern:** A strict **"Functional Core, Imperative Shell" (FCIS)** architecture with **Unidirectional Data Flow**.
    *   **Functional Core (`Domain/`):** Pure Swift data structures, deterministic state transition algorithms, and mathematical projections. Contains zero imports of `SwiftUI`, `AppKit`, or disk I/O frameworks. All time-sensitive operations are parameterized by an abstract `Clock`, enabling deterministic testing without system-clock dependencies.
    *   **Imperative Shell - Storage (`Storage/`):** Isolates all asynchronous persistence, atomic file transactions, POSIX file-descriptor hooks (`DirectoryWatcher`), and cryptographic change detection (`SHA256`). Communicates with the core strictly through value-typed domain snapshots.
    *   **Imperative Shell - Presentation (`Presentation/` & `App/`):** SwiftUI view hierarchy and AppKit window wrappers. Driven by a lightweight coordinator (`DashboardStore`) that manages ephemeral UI form drafts (`TaskDraft`), system dialogues (`NSOpenPanel`, `NSSavePanel`, `NSAlert`), and active tab routes (`NavigationTab`), delegating all mutations to `ChoreEngine` and all queries to `ChoreProjections`.
*   **Separation of Concerns:** Ephemeral UI inputs (e.g., active task edits, custom tag text fields) are decoupled from the persisted domain schema (`DashboardState`), preventing partial form inputs or navigation transitions from corrupting persistent state.
*   **Low Onboarding Cognitive Load:** Strict, predictable single-responsibility boundaries. Business rules reside exclusively in `Domain/Logic/`, persistence mechanics in `Storage/`, and layout primitives in `Presentation/`.

```text
┌───────────────────────────────────────────────────────────────────────────────────┐
│                                 IMPERATIVE SHELL                                  │
│                                                                                   │
│   ┌─────────────────────────────┐         ┌───────────────────────────────────┐   │
│   │     Presentation Layer      │         │   Storage & System Integration    │   │
│   │   - SwiftUI Views & Layouts │         │   - FilePersistenceClient (Actor) │   │
│   │   - AppKit Chrome & Menus   │         │   - DirectoryWatcher (POSIX I/O)  │   │
│   │   - UI State (Tabs, Drafts) │         │   - Timer & OS Notifications      │   │
│   └──────────────┬──────────────┘         └─────────────────┬─────────────────┘   │
│                  │                                          │                     │
│                  │       ┌──────────────────────────┐       │                     │
│                  └──────►│      DashboardStore      │◄──────┘                     │
│                          │ (Observable Coordinator) │                             │
│                          └────────────┬─────────────┘                             │
└───────────────────────────────────────┼───────────────────────────────────────────┘
                                        │ Dispatches (inout State, Clock)
                                        │ Reads Invariant Projections
                                        ▼
┌───────────────────────────────────────────────────────────────────────────────────┐
│                       FUNCTIONAL CORE (Zero I/O, Pure Swift)                      │
│                                                                                   │
│   ┌───────────────────────────────────┐   ┌───────────────────────────────────┐   │
│   │            ChoreEngine            │   │         ChoreProjections          │   │
│   │   - (inout State, Clock) -> Bool  │   │   - ActiveMonthWindow (Timeline)  │   │
│   │   - Rollover, Toggle, Complete    │   │   - TaskClassificationIndex (O(1))│   │
│   │   - Upsert, Delete, ClearAll      │   │   - PacingMath (Dual-Threshold)   │   │
│   └─────────────────┬─────────────────┘   └─────────────────┬─────────────────┘   │
│                     │                                       │                     │
│                     ▼                                       ▼                     │
│   ┌───────────────────────────────────────────────────────────────────────────┐   │
│   │                               Domain Models                               │   │
│   │   - DashboardState (Codable Schema)   - Clock Protocol (System/Test)      │   │
│   │   - TaskItem (with createdAt)         - TaskHealthState (5-Tier Runway)   │   │
│   │   - RecurrenceRule & CadenceUnit      - HistoryRecord (Immutable Logs)    │   │
│   └───────────────────────────────────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────────────────────────────────────┘
```

---

### **Execution Pipeline: 4-Stage Data Flow**

Every state modification and telemetry query follows a structured unidirectional lifecycle:

```text
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                              UNIDIRECTIONAL DATA PIPELINE                              │
│                                                                                        │
│   [Stage 1: Intent Capture]                                                            │
│   User Interaction (Toggle / Commit / Delete / Reset)                                  │
│            │                                                                           │
│            ▼                                                                           │
│   [TaskDraft] ────────► [DashboardStore] ◄──────── [External Disk Mutation]            │
│   (Ephemeral Form)      (MainActor Coordinator)    (DirectoryWatcher + SHA-256 Diff)   │
│                              │                                                         │
│                              ▼                                                         │
│   [Stage 2: Deterministic Mutation]                                                    │
│   ChoreEngine.mutation(state: inout DashboardState, clock: Clock)                      │
│   ├── Rollover & Auto-Purge      ├── Upsert & Tag Deduplication                        │
│   └── Toggle Check / Uncheck     └── Delete Task with Historical Categorization        │
│                              │                                                         │
│             ┌────────────────┴────────────────┐                                        │
│             ▼                                 ▼                                        │
│   [Stage 3: Projection Synthesis]    [Stage 4: Async Storage Dispatch]                 │
│   ChoreProjections (Pure Queries)    FilePersistenceClient (Actor)                     │
│   ├── ActiveMonthWindow              ├── 120ms Debounced Task                          │
│   ├── TaskClassificationIndex        ├── Atomic ISO-8601 File Write                    │
│   ├── Queue Disjoint Partitions      └── SHA-256 Digest Validation                     │
│   └── PacingMath Targets                            │                                  │
│             │                                       ▼                                  │
│             ▼                               [state.json on Disk]                       │
│   [Stage 5: SwiftUI View Re-Render]                                                    │
│   ├── PrimaryFocusView & BaselineResetView                                             │
│   └── StatusView, BacklogListView, HistoryTimelineView                                 │
│             │                                                                          │
│             └──────────────► (Awaits Next User Event)                                  │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

#### **Stage-by-Stage Breakdown**

**Stage 1: Intent Capture & Ephemeral UI Isolation (Presentation)**
*   **Elements:** `Presentation/State/TaskDraft.swift`, `Presentation/State/NavigationTab.swift`, `Presentation/RightColumn/TaskEditorView.swift`, and `Presentation/RightColumn/HistoryTimelineView.swift`.
*   **Mechanism:** User inputs, cadence adjustments, tag configurations, and data management triggers (Export, Load, Clear) are managed via `DashboardStore`. Interactive form state is isolated within value-typed `TaskDraft` instances with explicit `createdAt` tracking. 
*   **Invariant:** Ephemeral UI churn cannot contaminate domain models or trigger premature disk serialization.

**Stage 2: Deterministic Functional Transitions & Invariants (Domain Core)**
*   **Elements:** `Domain/Logic/ChoreEngine.swift`, `Domain/Clock.swift`, and `Domain/Models/TaskItem.swift`.
*   **Mechanism:** `DashboardStore` forwards mutations to pure static methods on `ChoreEngine`, passing `(inout DashboardState, Clock)`. Transitions evaluate all calendar boundaries against `clock.now` and `clock.calendar`. Task deletions stamp historical records to enforce semantic immutability across the archive.
*   **Invariant:** Business rules have zero dependencies on SwiftUI, AppKit, or filesystem APIs. Rollovers, completions, deletions, and full resets execute deterministically in microseconds under `TestClock`.

**Stage 3: Pure Projection Synthesis & Telemetry Calculations (Domain Queries)**
*   **Elements:** `Domain/Logic/ChoreProjections.swift`.
*   **Mechanism:** Views never perform ad-hoc task filtering or progress arithmetic. `ChoreProjections` consumes an immutable `(DashboardState, Clock)` snapshot:
    *   `ActiveMonthWindow`: Encapsulates temporal boundaries, month lengths, leap years, and active tracking horizons.
    *   `TaskClassificationIndex`: Indexes baseline task IDs and titles into `Set` collections once per projection, eliminating $O(H \times T)$ nested scans.
    *   `PacingMath`: Evaluates prospective dual-threshold operational pacing (prior-day floor vs. today's ceiling), pro-rating expectations based on task creation dates (`createdAt`).
    *   `baselineCompliance`: Evaluates routine adherence while enforcing the capacity invariant ($\text{expectedCount} \ge \text{completedCount}$) to prevent denominator shrinkage upon task deletion.
*   **Invariant:** Complete mathematical disjointness across active operational queues:
    $$\text{focusQueue} \cap \text{baselineTasks} = \emptyset, \quad \text{focusQueue} \cap \text{upcomingEvents} = \emptyset$$

**Stage 4: Actor-Isolated Persistence & Cryptographic File Watching (Storage)**
*   **Elements:** `Storage/FilePersistenceClient.swift` and `Storage/DirectoryWatcher.swift`.
*   **Mechanism:** State mutations dispatch a 120ms debounced write to the `FilePersistenceClient` actor, which serializes the payload to atomic storage and records its SHA-256 digest. Concurrently, `DirectoryWatcher` monitors `state.json` via a POSIX `DispatchSourceFileSystemObject`. When external changes occur, `evaluateExternalChange()` validates the checksum before decoding. Full state imports and exports run through standard JSON serialization routines.
*   **Invariant:** Offloads all disk I/O from the main thread. Atomic writes protect against process termination faults, while SHA-256 digest comparisons prevent write-and-watch feedback loops.

**Stage 5: Reactive Projection Binding & View Re-Render (Presentation)**
*   **Elements:** `Presentation/DashboardView.swift`, `Presentation/LeftColumn/PrimaryFocusView.swift`, `Presentation/LeftColumn/BaselineResetView.swift`, `Presentation/RightColumn/StatusView.swift`, and tactile UI components (`FocusJobTile.swift`, `CheckboxRow.swift`, `HealthRunwayGauge.swift`).
*   **Mechanism:** Views observe `DashboardStore` via Swift's Observation framework (`@Observable`). When mutations commit to `state` or external file modifications reload the store, SwiftUI re-evaluates bound projection accessors (`store.focusQueue`, `store.todaySnapshot`, `store.monthlyPacing`). Layouts adjust dynamically to window resizing via `LeftColumnAdaptiveLayout` and proportional geometry scalers (`\.scaleFactor`). Views consume computed projection models passively, executing zero filtering or mathematical processing in `body`.
*   **Invariant:** Rendering is purely a pure projection function of state ($f(\text{State}) \to \text{UI}$). Views never mutate domain entities, cache derived queries, or dispatch I/O side-effects during render passes.
---

### **Project Structure: `ChoreDashboard/`**

```text
ChoreDashboard/
├── Package.swift                           # SPM manifest: defines executable & test targets (.macOS v14).
├── compile.sh                              # Standalone release compilation and .app bundle packager.
│
├── Sources/
│   ├── App/                                # --- SYSTEM INTEGRATION & ENTRY POINT ---
│   │   └── ChoreDashboardApp.swift         # Declarative App scene, window bounds, and MenuBarExtra.
│   │
│   ├── Config/
│   │   └── AppConfig.swift                 # Central design tokens, 65/35 split geometry, and file URLs.
│   │
│   ├── Domain/                             # --- FUNCTIONAL CORE (PURE SWIFT) ---
│   │   ├── Clock.swift                     # Clock protocol, SystemClock, and deterministic TestClock.
│   │   │
│   │   ├── Models/                         # Ground-truth entity definitions and codable schemas.
│   │   │   ├── TaskItem.swift              # Unified chore item (title, recurrence, cadence, dates, createdAt).
│   │   │   ├── TaskHealthState.swift       # 5-tier operational runway enum (GOOD, NOT YET, HALF, DUE, OVERDUE).
│   │   │   ├── HistoryRecord.swift         # Immutable historical completion entry with timestamps.
│   │   │   └── DashboardState.swift        # Root persistent document schema.
│   │   │
│   │   ├── Logic/                          # Pure business rules (zero external dependencies).
│   │   │   ├── ChoreEngine.swift           # State transitions (toggle, complete, rollover, upsert, delete, clear).
│   │   │   └── ChoreProjections.swift      # Projections engine (ActiveMonthWindow, TaskClassificationIndex, PacingMath).
│   │   │
│   │   └── Seeds/
│   │       └── PreviewData.swift           # Ground-truth seed data for previews and default fallback.
│   │
│   ├── Storage/                            # --- PERSISTENCE & FILE SYSTEM I/O ---
│   │   ├── PersistenceClient.swift         # Async contract protocol for load/save/evaluate operations.
│   │   ├── FilePersistenceClient.swift     # Actor executing atomic disk writes and SHA-256 diff checks.
│   │   └── DirectoryWatcher.swift          # DispatchSource POSIX file-system descriptor observer.
│   │
│   └── Presentation/                       # --- IMPERATIVE SHELL (VIEWS & UI STATE) ---
│       ├── DashboardStore.swift            # @Observable coordinator (Domain, Storage, UI, and AppKit dialogs).
│       ├── DashboardView.swift             # Root 65/35 dual-column layout container with scaling scalar.
│       │
│       ├── State/                          # Transient form and navigation state.
│       │   ├── NavigationTab.swift         # RightPanelTab enum (status, backlog, history, create, edit).
│       │   └── TaskDraft.swift             # Ephemeral form model isolating live task editing from disk.
│       │
│       ├── Components/                     # Reusable Swiss-style tactile design components.
│       │   ├── CheckboxRow.swift           # High-visibility row with square checkbox and priority tags.
│       │   ├── FocusJobTile.swift          # Grid card component with inline overdue hazard warnings.
│       │   ├── HealthRunwayGauge.swift     # 4-segment operational buffer indicator with hazard alerts.
│       │   ├── PanelHeaderView.swift       # Monospaced section headers with tracking and action badges.
│       │   └── SectionBadge.swift          # Scaled typography badge primitives.
│       │
│       ├── LeftColumn/                     # 65% Dark Operational Focus Zones.
│       │   ├── PrimaryFocusView.swift      # Active operations grid (tasks due today or overdue).
│       │   └── BaselineResetView.swift     # Continuous 24-hour maintenance checklist and reset trigger.
│       │
│       └── RightColumn/                    # 35% Horizon, Status, and Inventory Deck.
│           ├── StatusView.swift            # Telemetry snapshot, monthly pacing velocity, and horizon queue.
│           ├── BacklogListView.swift       # Master item registry broken down into operational tiers.
│           ├── HistoryTimelineView.swift   # Chronological completion log with backup dock (EXPORT, LOAD, CLEAR).
│           ├── TaskEditorView.swift        # Task modification/creation form with cadence steppers.
│           └── BottomActionBarView.swift   # Primary dock switcher (NEW, STATUS, BACKLOG, HISTORY).
│
└── Tests/                                  # --- DETERMINISTIC TEST SUITE ---
    └── ChoreDashboardTests/
        ├── DomainTests/                    # Pure domain logic verification (Clock-driven).
        │   ├── TaskItemTests.swift         # Health runway heuristics and time anchor evaluations.
        │   ├── ChoreEngineTests.swift      # Task completions, deletions, and cascading tag cleanup.
        │   ├── RolloverTests.swift         # Midnight calendar crossings and cadence rollover checks.
        │   ├── ProjectionsTests.swift      # Partition disjointness, clearance rates, and sorting.
        │   ├── VelocityComplianceTelemetryTests.swift # ActiveMonthWindow, PacingMath matrix, and telemetry integration.
        │   └── SystemInvariantTests.swift  # Idempotency, inventory conservation, and schema roundtrips.
        │
        ├── StorageTests/                   # I/O, atomicity, and serialization tests.
        │   └── PersistenceTests.swift      # Disk roundtrips, corrupted file handling, and SHA short-circuits.
        │
        ├── PresentationTests/              # UI coordination and workflow tests.
        │   ├── AdaptiveLayoutTests.swift   # Column split layout calculation math.
        │   ├── ComponentTests.swift        # Component hierarchy rendering under various scale factors.
        │   └── DashboardStoreTests.swift   # Navigation lifecycles, imports, and debounced persistence.
        │
        ├── TestDoubles/                    # Zero-I/O test doubles.
        │   └── InMemoryPersistenceClient.swift # In-memory storage mock tracking save calls without disk access.
        │
        ├── bugfixes/                       # Dedicated regression tests.
        │   └── CriticalRegressionTests.swift # High-criticality regression smoke tests.
        │
        └── ChoreDashboardTests.swift       # Smoke test for test target registration.
```

---

### **Architectural Invariants & Development Rules**

1. **Unidirectional Dependency Rules:**
   * `Domain` must **never** import `SwiftUI`, `AppKit`, `Storage`, or `Presentation`.
   * `Storage` depends only on `Domain/Models`. It has no reference to `Presentation` or UI state.
   * `Presentation` views receive data via `DashboardStore`. Views do not perform domain mutations directly.
2. **Deterministic Time Rules:**
   * Any function calculating dates, cadences, or relative time must accept an injected `Clock` or reference `Date` explicitly. Direct calls to `Date()` or `Calendar.current` inside domain logic are prohibited.
3. **Persistence Isolation Rules:**
   * All mutations to `DashboardState` occur in-memory first via `ChoreEngine`. Persistence to disk is debounced (120ms) and executed asynchronously via `FilePersistenceClient`.
   * Form inputs in `TaskEditorView` mutate an isolated `TaskDraft`. State reaches `DashboardState` only when explicitly committed via `DashboardStore.commitDraft()`.
4. **Historical Semantic Immutability:**
   * Modifications to active task inventory (e.g., deleting a chore or editing cadences) must not mutate or reclassify historical completion records. A baseline completion remains a baseline completion permanently.