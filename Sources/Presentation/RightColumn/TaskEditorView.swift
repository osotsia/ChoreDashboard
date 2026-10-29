import SwiftUI

/// Main task creation and modification form orchestrator.
public struct TaskEditorView: View {
    @Bindable public var store: DashboardStore
    @Environment(\.scaleFactor) private var s

    @State private var isCreatingCustomTag: Bool = false
    @State private var customTagText: String = ""

    public init(store: DashboardStore) {
        self.store = store
    }

    /// Safe non-force-unwrapping binding that provides a fallback draft during exit transition animations.
    private var safeDraftBinding: Binding<TaskDraft>? {
        guard store.taskDraft != nil else { return nil }
        return Binding<TaskDraft>(
            get: { self.store.taskDraft ?? TaskDraft() },
            set: { self.store.taskDraft = $0 }
        )
    }

    private var isCustomTagValid: Bool {
        ChoreEngine.isValidTag(customTagText)
    }

    private var isTagValid: Bool {
        guard let draft = store.taskDraft else { return false }
        if isCreatingCustomTag {
            return isCustomTagValid
        }
        return ChoreEngine.isValidTag(draft.tag)
    }

    private var isValid: Bool {
        guard let draft = store.taskDraft else { return false }
        return !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isTagValid
    }

    private func confirmCustomTag() {
        let clean = customTagText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !clean.isEmpty, isCustomTagValid else { return }
        store.addCustomTag(clean)
        store.taskDraft?.tag = clean
        customTagText = ""
        isCreatingCustomTag = false
    }

    public var body: some View {
        if let draftBinding = safeDraftBinding {
            let draft = draftBinding.wrappedValue
            VStack(alignment: .leading, spacing: 16 * s) {
                TaskTitleSection(title: draftBinding.title, s: s)

                TaskTagSection(
                    selectedTag: draftBinding.tag,
                    availableTags: store.availableTags,
                    isCreatingCustom: $isCreatingCustomTag,
                    customTagText: $customTagText,
                    isCustomTagValid: isCustomTagValid,
                    onConfirmCustomTag: { confirmCustomTag() },
                    onDeleteTag: { store.deleteTag($0) },
                    s: s
                )

                TaskTimingSection(draft: draftBinding, clock: store.clock, s: s)

                if !draft.isOneTime {
                    TaskHealthSection(draft: draftBinding, clock: store.clock, s: s)
                }

                TaskRoutingCard(info: draft.routingInfo, health: draft.initialHealthState, s: s)

                TaskActionDock(
                    draft: draft,
                    isValid: isValid,
                    onCommit: {
                        if isCreatingCustomTag { confirmCustomTag() }
                        store.commitDraft()
                    },
                    onCancel: { store.dismissDraft() },
                    onDelete: { store.deleteTask(id: draft.id) },
                    s: s
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .onExitCommand(perform: { store.dismissDraft() })
        }
    }
}

// MARK: - Section 1: Task Title
private struct TaskTitleSection: View {
    @Binding var title: String
    let s: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 6 * s) {
            Text("TASK IDENTIFIER")
                .font(.system(size: 10 * s, weight: .bold))
                .tracking(1.4 * s)
                .foregroundColor(AppConfig.Colors.subtextGrey)

            TextField("e.g. Sanitize ice machine coils", text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 13 * s, weight: .semibold))
                .padding(.horizontal, 12 * s)
                .padding(.vertical, 10 * s)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 6 * s))
                .overlay(
                    RoundedRectangle(cornerRadius: 6 * s)
                        .strokeBorder(Color.black.opacity(0.18), lineWidth: 1 * s)
                )
        }
    }
}

// MARK: - Section 2: System Tags & Custom Creation
private struct TaskTagSection: View {
    @Binding var selectedTag: String
    let availableTags: [String]
    @Binding var isCreatingCustom: Bool
    @Binding var customTagText: String
    let isCustomTagValid: Bool
    let onConfirmCustomTag: () -> Void
    let onDeleteTag: (String) -> Void
    let s: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 6 * s) {
            Text("SYSTEM TAG")
                .font(.system(size: 10 * s, weight: .bold))
                .tracking(1.4 * s)
                .foregroundColor(AppConfig.Colors.subtextGrey)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 72 * s), spacing: 6 * s)],
                spacing: 6 * s
            ) {
                ForEach(availableTags, id: \.self) { tag in
                    let isSelected = !isCreatingCustom && selectedTag == tag
                    Button {
                        isCreatingCustom = false
                        selectedTag = tag
                    } label: {
                        Text(tag)
                            .font(.system(size: 9.5 * s, weight: .bold))
                            .tracking(0.8 * s)
                            .lineLimit(1)
                            .foregroundColor(isSelected ? .white : Color.black)
                            .padding(.horizontal, 4 * s)
                            .frame(maxWidth: .infinity)
                            .frame(height: 28 * s)
                            .background(isSelected ? Color.black : Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 5 * s))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5 * s)
                                    .strokeBorder(isSelected ? Color.black : Color.black.opacity(0.15), lineWidth: 1 * s)
                            )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            onDeleteTag(tag)
                        } label: {
                            Label("Delete Tag \"\(tag)\"", systemImage: "trash")
                        }
                    }
                }

                Button {
                    isCreatingCustom = true
                } label: {
                    HStack(spacing: 3 * s) {
                        Image(systemName: "plus")
                            .font(.system(size: 8 * s, weight: .black))
                        Text("CUSTOM")
                            .font(.system(size: 9.5 * s, weight: .bold))
                            .tracking(0.8 * s)
                    }
                    .foregroundColor(isCreatingCustom ? .white : Color.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 28 * s)
                    .background(isCreatingCustom ? Color.black : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 5 * s))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5 * s)
                            .strokeBorder(isCreatingCustom ? Color.black : Color.black.opacity(0.2), lineWidth: 1 * s)
                    )
                }
                .buttonStyle(.plain)
            }

            if isCreatingCustom {
                HStack(spacing: 6 * s) {
                    TextField("ENTER TAG NAME", text: $customTagText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11 * s, weight: .bold))
                        .padding(.horizontal, 10 * s)
                        .padding(.vertical, 8 * s)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 5 * s))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5 * s)
                                .strokeBorder(isCustomTagValid ? Color.black : Color.red, lineWidth: 1.2 * s)
                        )
                        .onSubmit { onConfirmCustomTag() }

                    Button(action: onConfirmCustomTag) {
                        Text("ADD")
                            .font(.system(size: 10 * s, weight: .black))
                            .tracking(1.0 * s)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12 * s)
                            .frame(height: 33 * s)
                            .background(isCustomTagValid ? Color.black : Color.black.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 5 * s))
                    }
                    .buttonStyle(.plain)
                    .disabled(!isCustomTagValid)

                    Button {
                        isCreatingCustom = false
                        customTagText = ""
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11 * s, weight: .bold))
                            .foregroundColor(AppConfig.Colors.subtextGrey)
                            .frame(width: 28 * s, height: 33 * s)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4 * s)
            }
        }
    }
}

// MARK: - Section 3: Timing, Recurrence & Duration
private struct TaskTimingSection: View {
    @Binding var draft: TaskDraft
    let clock: Clock
    let s: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8 * s) {
            HStack {
                Text(draft.isOneTime ? "TASK TIMING (ONE-TIME)" : "RECURRENCE CADENCE")
                    .font(.system(size: 10 * s, weight: .bold))
                    .tracking(1.4 * s)
                    .foregroundColor(AppConfig.Colors.subtextGrey)

                Spacer()

                HStack(spacing: 2 * s) {
                    CadenceTypeTab(title: "RECURRING", isSelected: !draft.isOneTime, s: s) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            draft.isOneTime = false
                            if draft.isOverdue {
                                draft.setOverdue(false, clock: clock)
                            } else {
                                draft.setRunway(ratio: draft.runwayRatio, clock: clock)
                            }
                        }
                    }
                    CadenceTypeTab(title: "ONE-TIME", isSelected: draft.isOneTime, s: s) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            draft.isOneTime = true
                        }
                    }
                }
                .padding(2 * s)
                .background(Color.black.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6 * s))
            }

            if !draft.isOneTime {
                HStack(spacing: 10 * s) {
                    NumericStepper(value: Binding(
                        get: { draft.repeatCount },
                        set: {
                            draft.repeatCount = $0
                            draft.setRunway(ratio: draft.runwayRatio, clock: clock)
                        }
                    ), range: 1...99, s: s)

                    CadenceUnitSelector(unit: Binding(
                        get: { draft.repeatUnit },
                        set: {
                            draft.repeatUnit = $0
                            draft.setRunway(ratio: draft.runwayRatio, clock: clock)
                        }
                    ), count: draft.repeatCount, s: s)
                }
            } else {
                VStack(alignment: .leading, spacing: 8 * s) {
                    HStack {
                        Text("TARGET DEADLINE")
                            .font(.system(size: 9.5 * s, weight: .bold))
                            .foregroundColor(AppConfig.Colors.subtextGrey)

                        Spacer()

                        HStack(spacing: 2 * s) {
                            if draft.initialHealthState == .overdue {
                                CadenceTypeTab(title: "OVERDUE", isSelected: true, s: s) {}
                            }
                            CadenceTypeTab(title: "TODAY", isSelected: draft.initialHealthState == .due, s: s) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    draft.initialHealthState = .due
                                    draft.targetDueDate = clock.now
                                }
                            }
                            CadenceTypeTab(title: "IN FUTURE", isSelected: draft.isOneTimeInFuture, s: s) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    draft.initialHealthState = .good
                                    draft.targetDueDate = clock.calendar.date(
                                        byAdding: .day,
                                        value: draft.repeatUnit.days(count: draft.repeatCount),
                                        to: clock.now
                                    ) ?? clock.now
                                }
                            }
                        }
                        .padding(2 * s)
                        .background(Color.black.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6 * s))
                    }

                    if draft.isOneTimeInFuture {
                        HStack(spacing: 10 * s) {
                            NumericStepper(value: Binding(
                                get: { draft.repeatCount },
                                set: {
                                    draft.repeatCount = $0
                                    draft.targetDueDate = clock.calendar.date(
                                        byAdding: .day,
                                        value: draft.repeatUnit.days(count: $0),
                                        to: clock.now
                                    ) ?? clock.now
                                }
                            ), range: 1...99, s: s)

                            CadenceUnitSelector(unit: Binding(
                                get: { draft.repeatUnit },
                                set: {
                                    draft.repeatUnit = $0
                                    draft.targetDueDate = clock.calendar.date(
                                        byAdding: .day,
                                        value: $0.days(count: draft.repeatCount),
                                        to: clock.now
                                    ) ?? clock.now
                                }
                            ), count: draft.repeatCount, s: s)
                        }
                    }
                }
            }

            // Universal Duration Adjustment
            HStack {
                Text("ESTIMATED DURATION")
                    .font(.system(size: 10 * s, weight: .bold))
                    .tracking(1.4 * s)
                    .foregroundColor(AppConfig.Colors.subtextGrey)

                Spacer()

                HStack(spacing: 0) {
                    Button {
                        if draft.durationMinutes > 5 { draft.durationMinutes -= 5 }
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 10 * s, weight: .bold))
                            .frame(width: 28 * s, height: 30 * s)
                    }
                    .buttonStyle(SubtlePressStyle())

                    Text("\(draft.durationMinutes) MIN")
                        .font(.system(size: 11 * s, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6 * s)

                    Button {
                        draft.durationMinutes += 5
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 10 * s, weight: .bold))
                            .frame(width: 28 * s, height: 30 * s)
                    }
                    .buttonStyle(SubtlePressStyle())
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 5 * s))
                .overlay(RoundedRectangle(cornerRadius: 5 * s).strokeBorder(Color.black.opacity(0.15), lineWidth: 1 * s))
            }
            .padding(.top, 4 * s)
        }
    }
}

// MARK: - Section 4: Operational Health (Interactive Segmented Runway Gauge)
private struct TaskHealthSection: View {
    @Binding var draft: TaskDraft
    let clock: Clock
    let s: CGFloat

    private var intervalDays: Int {
        max(1, draft.repeatUnit.days(count: draft.repeatCount))
    }

    private var segmentCount: Int {
        max(2, min(intervalDays, 20))
    }

    private var filledSegments: Int {
        if draft.isOverdue { return 0 }
        return Int(round(draft.runwayRatio * Double(segmentCount)))
    }

    private var daysRemaining: Int {
        if draft.isOverdue { return -1 }
        return Int(round(Double(intervalDays) * draft.runwayRatio))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6 * s) {
            HStack {
                Text("CURRENT OPERATIONAL RUNWAY")
                    .font(.system(size: 10 * s, weight: .bold))
                    .tracking(1.4 * s)
                    .foregroundColor(AppConfig.Colors.subtextGrey)

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        draft.setOverdue(!draft.isOverdue, clock: clock)
                    }
                } label: {
                    HStack(spacing: 3 * s) {
                        Image(systemName: draft.isOverdue ? "radiation" : "exclamationmark.triangle")
                            .font(.system(size: 8.5 * s, weight: .black))
                        Text(draft.isOverdue ? "DECAY HAZARD" : "MARK OVERDUE")
                            .font(.system(size: 8 * s, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(draft.isOverdue ? .white : AppConfig.Colors.statusRed)
                    .padding(.horizontal, 7 * s)
                    .padding(.vertical, 3.5 * s)
                    .background(draft.isOverdue ? AppConfig.Colors.statusRed : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 4 * s))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4 * s)
                            .strokeBorder(draft.isOverdue ? Color.clear : AppConfig.Colors.statusRed.opacity(0.4), lineWidth: 1 * s)
                    )
                }
                .buttonStyle(.plain)
            }

            HealthRunwayGauge(
                state: draft.initialHealthState,
                s: s,
                segmentCount: segmentCount,
                filledSegments: filledSegments,
                totalDays: intervalDays,
                daysRemaining: daysRemaining,
                targetDate: draft.targetDueDate,
                isOverdue: draft.isOverdue,
                isInteractive: true,
                onSelectLevel: { level in
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        let ratio = Double(level) / Double(segmentCount)
                        draft.setRunway(ratio: ratio, clock: clock)
                    }
                },
                onToggleOverdue: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        draft.setOverdue(!draft.isOverdue, clock: clock)
                    }
                }
            )
        }
    }
}

// MARK: - Section 5: Routing Summary Card
private struct TaskRoutingCard: View {
    let info: TaskRoutingInfo
    let health: TaskHealthState
    let s: CGFloat

    var body: some View {
        HStack(alignment: .center, spacing: 8 * s) {
            Image(systemName: info.icon)
                .font(.system(size: 11 * s, weight: .bold))
                .foregroundColor(info.isImmediate ? (health == .overdue ? .red : Color.black) : AppConfig.Colors.subtextGrey)

            Text(info.text)
                .font(.system(size: 10.5 * s, weight: .medium))
                .foregroundColor(Color.black.opacity(0.85))
                .lineLimit(2)
        }
        .padding(.horizontal, 10 * s)
        .padding(.vertical, 8 * s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 6 * s))
    }
}

// MARK: - Section 6: Action Dock
private struct TaskActionDock: View {
    let draft: TaskDraft
    let isValid: Bool
    let onCommit: () -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void
    let s: CGFloat

    var body: some View {
        VStack(spacing: 8 * s) {
            Button(action: onCommit) {
                HStack(spacing: 6 * s) {
                    Image(systemName: draft.isNew ? "plus" : "checkmark")
                        .font(.system(size: 10 * s, weight: .black))
                    Text(draft.isNew ? "DISPATCH TASK TO BOARD" : "SAVE MODIFICATIONS")
                        .font(.system(size: 11 * s, weight: .bold))
                        .tracking(1.4 * s)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 42 * s)
                .background(isValid ? Color.black : Color.black.opacity(0.25))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 6 * s))
            }
            .disabled(!isValid)
            .buttonStyle(.plain)

            Button(action: onCancel) {
                Text("CANCEL")
                    .font(.system(size: 10 * s, weight: .bold))
                    .tracking(1.2 * s)
                    .foregroundColor(AppConfig.Colors.subtextGrey)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32 * s)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])

            if !draft.isNew {
                Button {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        onDelete()
                    }
                } label: {
                    HStack(spacing: 4 * s) {
                        Image(systemName: "trash")
                            .font(.system(size: 10 * s))
                        Text("DELETE TASK")
                            .font(.system(size: 9.5 * s, weight: .bold))
                            .tracking(1.0 * s)
                    }
                    .foregroundColor(Color.red.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .frame(height: 28 * s)
                }
                .buttonStyle(.plain)
                .padding(.top, 2 * s)
            }
        }
        .padding(.top, 4 * s)
    }
}

// MARK: - Reusable Micro-Components

private struct NumericStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let s: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Button {
                if value > range.lowerBound { value -= 1 }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 11 * s, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 36 * s, height: 42 * s)
                    .contentShape(Rectangle())
            }
            .buttonStyle(SubtlePressStyle())

            Divider().frame(height: 20 * s)

            Text("\(value)")
                .font(.system(size: 18 * s, weight: .black, design: .monospaced))
                .frame(maxWidth: .infinity)

            Divider().frame(height: 20 * s)

            Button {
                if value < range.upperBound { value += 1 }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11 * s, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 36 * s, height: 42 * s)
                    .contentShape(Rectangle())
            }
            .buttonStyle(SubtlePressStyle())
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 7 * s))
        .overlay(RoundedRectangle(cornerRadius: 7 * s).strokeBorder(Color.black.opacity(0.15), lineWidth: 1 * s))
    }
}

private struct CadenceUnitSelector: View {
    @Binding var unit: CadenceUnit
    let count: Int
    let s: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Button {
                unit = unit.previous()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11 * s, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 34 * s, height: 42 * s)
                    .contentShape(Rectangle())
            }
            .buttonStyle(SubtlePressStyle())

            Divider().frame(height: 20 * s)

            Text(unit.displayString(count: count).uppercased())
                .font(.system(size: 12 * s, weight: .bold))
                .tracking(0.6 * s)
                .frame(maxWidth: .infinity)

            Divider().frame(height: 20 * s)

            Button {
                unit = unit.next()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11 * s, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 34 * s, height: 42 * s)
                    .contentShape(Rectangle())
            }
            .buttonStyle(SubtlePressStyle())
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 7 * s))
        .overlay(RoundedRectangle(cornerRadius: 7 * s).strokeBorder(Color.black.opacity(0.15), lineWidth: 1 * s))
    }
}