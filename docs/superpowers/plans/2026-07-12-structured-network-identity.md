# Structured Network Identity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Make structured SSID/BSSID payloads the sole identity for Pro connection events, generate labels only in presentation code, and replace the development event schema with SQLite v2.

**Architecture:** WiFiObservationEvent.EventType carries WiFiNetworkIdentity for connection and disconnection. Detector, recorder cooldown, Journal, SQLite, Timeline, menu, and search consume those fields directly. SQLite resets any pre-v2 event schema transactionally and never parses the former combined label.

**Tech Stack:** Swift 6, Swift Testing, Combine, SQLite3, SwiftUI, Xcode project targets for macOS 14+.

## Global Constraints

- Work in the existing checkout. Do not create or use a worktree.
- Keep all concrete identity, event, persistence, and presentation implementation Pro-only and absent from the OSS Sources phase.
- Do not add a legacy identity case or parse strings shaped like SSID (BSSID).
- A selected pre-v2 Event Journal database loses its existing event history once and becomes schema version 2.
- Reject a database with user_version greater than 2 without dropping or rewriting its tables.
- EventContextSnapshot remains diagnostic context and must not supply or repair connection identity.
- Preserve transition classification, event ordering, severity, cooldown intervals, Journal ordering, clear behavior, and error precedence.
- Preserve the four non-connection payloads: BSSID change, channel change, signal drop, and latency spike.
- Timeline and menu use one shared identity presentation adapter.
- Do not add third-party dependencies.
- Do not run WiFiLensUITests or WiFiLensProUITests.
- Do not create implementation commits without a new explicit instruction. Use working-tree packages for reviews.

---

### Task 1: Add the identity value and shared presentation adapter

**Files:**
- Modify: Pro/Events/WiFiObservationEvent.swift
- Create: Pro/Presentation/WiFiNetworkIdentityPresentation.swift
- Modify: Pro/Tests/WiFiLensProTests/TimelinePresentationTests.swift
- Modify: WiFiLens/WiFiLens.xcodeproj/project.pbxproj

**Interfaces:**
- Produces WiFiNetworkIdentity with ssid and bssid.
- Produces WiFiNetworkIdentityPresentation.init(identity:), label, and searchTerms.
- Leaves EventType unchanged until Task 2.

- [ ] **Step 1: Write the failing presentation test**

Add this test to TimelinePresentationTests:

    @Test func networkIdentityPresentationFormatsAvailableComponents() {
        let both = WiFiNetworkIdentityPresentation(
            identity: WiFiNetworkIdentity(
                ssid: "Office",
                bssid: "aa:bb:cc:dd:ee:ff"
            )
        )
        let ssidOnly = WiFiNetworkIdentityPresentation(
            identity: WiFiNetworkIdentity(ssid: "Office", bssid: nil)
        )
        let bssidOnly = WiFiNetworkIdentityPresentation(
            identity: WiFiNetworkIdentity(
                ssid: nil,
                bssid: "aa:bb:cc:dd:ee:ff"
            )
        )
        let unknown = WiFiNetworkIdentityPresentation(
            identity: WiFiNetworkIdentity(ssid: nil, bssid: nil)
        )

        #expect(both.label == "Office (aa:bb:cc:dd:ee:ff)")
        #expect(both.searchTerms == ["Office", "aa:bb:cc:dd:ee:ff"])
        #expect(ssidOnly.label == "Office")
        #expect(ssidOnly.searchTerms == ["Office"])
        #expect(bssidOnly.label == "aa:bb:cc:dd:ee:ff")
        #expect(bssidOnly.searchTerms == ["aa:bb:cc:dd:ee:ff"])
        #expect(unknown.label == "Wi-Fi")
        #expect(unknown.searchTerms.isEmpty)
    }

- [ ] **Step 2: Run the TimelinePresentationTests suite and verify RED**

Run:

    xcodebuild -project WiFiLens/WiFiLens.xcodeproj \
      -scheme "WiFi Lens Pro" -configuration Debug \
      -destination 'platform=macOS' -skipPackageUpdates test \
      -only-testing:WiFiLensProTests/TimelinePresentationTests

Expected: compilation fails because both new types are absent.

- [ ] **Step 3: Add the domain value**

Add to WiFiObservationEvent.swift:

    struct WiFiNetworkIdentity: Codable, Equatable, Hashable, Sendable {
        let ssid: String?
        let bssid: String?

        init(ssid: String?, bssid: String?) {
            self.ssid = ssid.flatMap { $0.isEmpty ? nil : $0 }
            self.bssid = bssid.flatMap { $0.isEmpty ? nil : $0 }
        }
    }

    extension WiFiCurrentStatus {
        var eventNetworkIdentity: WiFiNetworkIdentity {
            WiFiNetworkIdentity(ssid: ssid, bssid: bssid)
        }
    }

Keep eventContextSnapshot separate.

- [ ] **Step 4: Add the adapter**

Create WiFiNetworkIdentityPresentation.swift:

    import Foundation

    struct WiFiNetworkIdentityPresentation: Equatable {
        let label: String
        let searchTerms: [String]

        init(identity: WiFiNetworkIdentity) {
            searchTerms = [identity.ssid, identity.bssid].compactMap { $0 }
            switch (identity.ssid, identity.bssid) {
            case (.some(let ssid), .some(let bssid)):
                label = "\(ssid) (\(bssid))"
            case (.some(let ssid), .none):
                label = ssid
            case (.none, .some(let bssid)):
                label = bssid
            case (.none, .none):
                label = "Wi-Fi"
            }
        }
    }

- [ ] **Step 5: Add Pro-only PBX membership**

Create a Presentation PBX group under Pro. Add one file reference and one build-file entry to the WiFiLensPro Sources phase. Add nothing to WiFiLens Sources or either test Sources phase.

- [ ] **Step 6: Verify GREEN**

Run PBX lint and the focused suite. Expected: project.pbxproj reports OK and TimelinePresentationTests passes.

- [ ] **Step 7: Write the task report**

Record RED/GREEN commands, exact counts, PBX membership, files changed, and concerns in .superpowers/sdd/structured-network-identity-task-1-report.md. Do not commit.

---

### Task 2: Replace generic connection details across the pipeline

**Files:**
- Modify: Pro/Events/WiFiObservationEvent.swift
- Modify: Pro/Events/RoamingEventDetector.swift
- Modify: Pro/Events/WiFiObservationEventJournal.swift
- Modify: Pro/Events/WiFiObservationEventSQLiteStore.swift
- Modify: Pro/Timeline/TimelineViewModel.swift
- Modify: Pro/Timeline/DebugTimelineView.swift
- Modify: Pro/MenuBar/MenuBarStatusViewModel.swift
- Modify: Pro/Tests/WiFiLensProTests/RoamingEventDetectorTests.swift
- Modify: Pro/Tests/WiFiLensProTests/WiFiEventRecorderTests.swift
- Modify: Pro/Tests/WiFiLensProTests/TimelinePresentationTests.swift
- Modify: Pro/Tests/WiFiLensProTests/MenuBarMigrationTests.swift
- Modify: Pro/Tests/WiFiLensProTests/EventJournalTests.swift

**Interfaces:**
- Consumes Task 1 identity and presentation types.
- Produces disconnection(identity:) and connected(identity:).
- Removes WiFiObservationEvent.details.
- Produces fresh v2 connection rows with separate SSID/BSSID columns. Task 3 supplies old-schema reset.

- [ ] **Step 1: Write structured detector assertions**

Replace label assertions with exact associated values:

    #expect(events[0].type == .disconnection(
        identity: WiFiNetworkIdentity(
            ssid: "Network A",
            bssid: "AA:BB:CC:DD:EE:01"
        )
    ))
    #expect(events[1].type == .connected(
        identity: WiFiNetworkIdentity(
            ssid: "Network B",
            bssid: "BB:BB:CC:DD:EE:01"
        )
    ))

Add SSID-only, BSSID-only, and unknown cases. Retain snapshot assertions.

- [ ] **Step 2: Write presentation and search boundary tests**

Create an event whose payload says OfficeWiFi and whose snapshot says SnapshotMustNotWin. Assert Timeline subtitle and search use the payload, and do not contain SnapshotMustNotWin. Add an unknown payload with a populated snapshot; assert Timeline and menu display Wi-Fi.

- [ ] **Step 3: Verify RED**

Run the RoamingEventDetectorTests, WiFiEventRecorderTests, TimelinePresentationTests, and MenuBarMigrationTests suites. Expected: connection cases reject identity arguments.

- [ ] **Step 4: Change the event domain**

Use these cases:

    case bssidChange(from: String, to: String)
    case disconnection(identity: WiFiNetworkIdentity)
    case connected(identity: WiFiNetworkIdentity)
    case signalDrop(from: Int, to: Int)
    case latencySpike(from: Double, to: Double)
    case channelChange(from: Int, to: Int)

Delete the details property and initializer parameter. Update kind, severity, and transition-state switches without changing their outputs.

- [ ] **Step 5: Make the detector emit identity**

Delete connectionLabel(for:). A connection uses current.eventNetworkIdentity. A disconnection uses previous.eventNetworkIdentity. A network switch emits old disconnection before new connection. Retain matching snapshots.

- [ ] **Step 6: Replace recorder string keys**

Use this private key in WiFiObservationEventJournal.swift:

    private enum EventCooldownKey: Hashable {
        case bssidChange(from: String, to: String)
        case disconnection(ssid: String?, normalizedBSSID: String?)
        case connected(ssid: String?, normalizedBSSID: String?)
        case signalDrop
        case latencySpike
        case channelChange(from: Int, to: Int)
    }

Change lastEmissionByKey to use EventCooldownKey. Lowercase BSSID only in the key. Keep SSID case-sensitive and preserve current event-specific grouping.

- [ ] **Step 7: Move Timeline and menu to the adapter**

Pattern-match identity and use WiFiNetworkIdentityPresentation.label. Add searchTerms to TimelineEventPresentation. searchIndex joins title, subtitle, badge, and raw terms. Set searchTerms to an empty array for non-connection cases. Update debug fixtures.

- [ ] **Step 8: Write and hydrate structured rows**

Define from_bssid and to_bssid in the connection table. Bind identity fields on the connected side. Query all four identity columns and construct the associated value. Remove HydratedEvent.details. Do not read context JSON for identity.

- [ ] **Step 9: Update exhaustive switches and fixtures**

Every connected and disconnection construction supplies identity. Test helpers may default to an unknown identity. Production detector code must use the participating status.

- [ ] **Step 10: Verify GREEN**

Run the five focused Pro suites named above plus EventJournalTests, then build WiFi Lens Pro Debug. Expected: all selected tests and the build pass.

- [ ] **Step 11: Write the task report**

Record RED/GREEN commands, exact counts, structured identity behavior, files changed, and concerns in .superpowers/sdd/structured-network-identity-task-2-report.md. Do not commit.

---

### Task 3: Install SQLite v2 and reset older history

**Files:**
- Modify: Pro/Events/WiFiObservationEventSQLiteStore.swift
- Create: Pro/Tests/WiFiLensProTests/WiFiObservationEventSQLiteStoreTests.swift
- Modify: WiFiLens/WiFiLens.xcodeproj/project.pbxproj

**Interfaces:**
- Consumes Task 2 structured rows.
- Produces schema version 2, transactional pre-v2 reset, required-column validation, and newer-schema rejection.

- [ ] **Step 1: Add a Pro SQLite test file**

Import Foundation, SQLite3, Testing, and the Pro module. Add the file to the Pro test group and WiFiLensProTests Sources only.

- [ ] **Step 2: Write fresh-schema and round-trip tests**

Assert user_version equals 2. Assert the transition columns are exactly event_id, from_state, to_state, from_ssid, from_bssid, to_ssid, to_bssid. Round-trip both connection directions with full, partial, and unknown identities.

- [ ] **Step 3: Write a v1 reset test**

Seed a temporary database with user_version 1, a v1 event_index row containing details equal to Legacy (aa:bb:cc:dd:ee:ff), and a v1 transition row. Initialize the store and assert history is empty, user_version is 2, and the new BSSID columns exist. Do not assert parsed legacy data.

- [ ] **Step 4: Write a newer-schema test**

Seed user_version 3 with a sentinel table. Call append and expect an error. Reopen read-only and prove the sentinel table remains.

- [ ] **Step 5: Verify RED**

Run WiFiObservationEventSQLiteStoreTests. Expected: reset and newer-version tests fail under the old initializer.

- [ ] **Step 6: Replace legacy normalization**

Use schemaVersion 2. Remove normalizeLegacySchemaIfNeeded, both legacy normalization methods, and migrateAddContextSnapshotIfNeeded. Initialization reads the version, rejects versions above 2, installs v2 for lower versions, and validates an existing v2 schema.

- [ ] **Step 7: Install v2 transactionally**

Before BEGIN IMMEDIATE, disable foreign keys. For every version below 2, use DROP TABLE IF EXISTS for these child tables and then event_index. A fresh version-0 database has no matching tables, so these statements are no-ops before schema creation:

    wifi_bssid_change_events
    wifi_channel_change_events
    wifi_signal_change_events
    wifi_latency_change_events
    wifi_connection_transition_events
    event_index

Within the same transaction create all v2 tables and indexes, validate required columns, set user_version to 2, and commit. Roll back and restore foreign keys on every error.

- [ ] **Step 8: Reject newer schemas**

Add unsupportedSchemaVersion(Int) to SQLiteStoreError. Do not treat it as a migration path.

- [ ] **Step 9: Verify GREEN**

Run PBX lint plus SQLite, recorder, and Journal suites. Expected: all pass.

- [ ] **Step 10: Write the task report**

Record schema evidence, RED/GREEN commands, exact counts, PBX membership, files changed, and concerns in .superpowers/sdd/structured-network-identity-task-3-report.md. Do not commit.

---

### Task 4: Delete the string contract and complete verification

**Files:**
- Modify: docs/ARCHITECTURE.md
- Modify: Pro/docs/ARCHITECTURE.md
- Modify: docs/superpowers/specs/2026-07-12-structured-network-identity-design.md
- Modify only when an audit exposes a stale fixture: Pro source and tests from Tasks 1 through 3

**Interfaces:**
- Consumes the completed event pipeline and SQLite v2 installer.
- Produces architecture documentation, zero-hit production audits, and final OSS/Pro evidence.

- [ ] **Step 1: Update documentation**

Document status to typed identity to Journal to structured SQLite to shared presentation. State that snapshots feed diagnostic detail only and v1 development history resets once. Mark the design Implemented after verification.

- [ ] **Step 2: Run deletion searches**

Run:

    rg -n '\bdetails\b|connectionLabel' Pro/Events Pro/Timeline Pro/MenuBar -g '*.swift'
    rg -n 'event\.details|details:' Pro/Events Pro/Timeline Pro/MenuBar -g '*.swift'

Expected: zero production matches. The v1 test fixture may define a details column.

- [ ] **Step 3: Audit edition and identity ownership**

Prove every connection construction supplies identity, both UI adapters use WiFiNetworkIdentityPresentation, contextSnapshot cannot supply labels, SQLite binds and hydrates SSID/BSSID separately, the new files are Pro-only in PBX, and the four other payload definitions remain unchanged.

- [ ] **Step 4: Run full unit suites**

Run the OSS WiFiLensTests target and Pro WiFiLensProTests target with only-testing selectors. Do not run UI tests. Expected: zero failures.

- [ ] **Step 5: Run builds and static checks**

Build both Debug schemes. Run PBX lint, root and Pro diff checks, and both cached-diff status commands. Expected: builds succeed, checks are clean, and no implementation change is staged.

- [ ] **Step 6: Write the acceptance report**

Record exact commands, counts, findings, and warnings in .superpowers/sdd/structured-network-identity-task-4-report.md.

- [ ] **Step 7: Complete final independent review**

Generate a complete root/Pro working-tree package. Give a fresh reviewer the design, this plan, all reports, and the package. Send every Critical or Important finding to one fix subagent, rerun covering tests, and repeat review until clean.

---

## Completion Gate

The phase is complete only when all four tasks have independent clean reviews, final review has no open Critical or Important finding, production deletion searches are zero-hit, v1 reset and v2 round-trip tests pass, OSS and Pro unit targets pass, both Debug builds succeed, PBX and diff checks are clean, and no implementation change is staged or committed without explicit authorization.
