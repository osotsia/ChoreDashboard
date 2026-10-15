import SwiftUI

public struct TaskEditorView: View {
    @Bindable public var store: DashboardStore
    @Environment(\.scaleFactor) private var s

    @State private var isCreatingCustomTag: Bool = false
    @State private var customTagText: String = ""

    public init(store: DashboardStore) {
        self.store = store
    }

    private var draft: TaskDraft? {
        store.taskDraft
    }

    private var isTagValid: Bool {
        guard let draft = draft else { return false }
        if isCreatingCustomTag {
            let clean = customTagText.trimmingCharacters(in: .whitespacesAndNewlines)
            return !clean.isEmpty && clean.rangeOfCharacter(from: CharacterSet(charactersIn: "·,")) == nil
        }
        return !draft.tag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isValid: Bool {
        guard let draft = draft else { return false }
        return !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isTagValid
    }

    private var isOneTimeInFuture: Bool {
        guard let draft = draft else { return false }
        return draft.isOneTime && draft.initialHealthState != .due && draft.initialHealthState != .overdue
    }

    private var routingInfo: (icon: String, text: String, isImmediate: Bool) {
        guard let draft = draft else { return ("questionmark", "", false) }

        if draft.isOneTime {
            if draft.initialHealthState == .overdue {
                return ("exclamationmark.triangle.fill", "Overdue hazard: Assigned high priority on Active Focus.", true)
            } else if draft.initialHealthState == .due {
                return ("bolt.fill", "Immediate action: Placed on Today's Active Focus Queue.", true)
            } else {
                let intervalDays = draft.repeatUnit.days(count: draft.repeatCount)
                let timeStr = draft.repeatUnit.displayString(count: draft.repeatCount).lowercased()
                return ("calendar", "Scheduled execution: Due in \(draft.repeatCount) \(timeStr) (\(intervalDays)d) in Upcoming Horizon.", false)
            }
        }

        let intervalDays = draft.repeatUnit.days(count: draft.repeatCount)
        switch draft.initialHealthState {
        case .overdue:
            return ("exclamationmark.triangle.fill", "Overdue hazard: Assigned high priority on Active Focus.", true)
        case .due:
            if draft.repeatUnit == .day && draft.repeatCount == 1 {
                return ("checklist", "Daily routine: Assigned to Daily Baseline (\(draft.durationMinutes) min).", true)
            }
            return ("bolt.fill", "Due today: Active on Today's Focus Queue.", true)
        case .halfway:
            let daysLeft = max(1, intervalDays / 2)
            return ("clock", "Halfway runway: Estimated due in ~\(daysLeft) days (Upcoming Horizon).", false)
        case .notYet:
            let daysLeft = max(1, Int(round(Double(intervalDays) * 0.75)))
            return ("clock", "In progress: Estimated due in ~\(daysLeft) days (Upcoming Horizon).", false)
        case .good:
            return ("checkmark.circle", "Cycle fresh: Next due in \(intervalDays) days (Upcoming Horizon).", false)
        }
    }

    private func confirmCustomTag() {
        let clean = customTagText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !clean.isEmpty, isTagValid else { return }
        store.addCustomTag(clean)
        store.taskDraft?.tag = clean
        customTagText = ""
        isCreatingCustomTag = false
    }

    public var body: some View {
        if let draft = store.taskDraft {
            VStack(alignment: .leading, spacing: 16 * s) {
                // 1. Task Title
                VStack(alignment: .leading, spacing: 6 * s) {
                    Text("TASK IDENTIFIER")
                        .font(.system(size: 10 * s, weight: .bold))
                        .tracking(1.4 * s)
                        .foregroundColor(AppConfig.Colors.subtextGrey)

                    TextField(
                        "e.g. Sanitize ice machine coils",
                        text: Binding(
                            get: { store.taskDraft?.title ?? "" },
                            set: { store.taskDraft?.title = $0 }
                        )
                    )
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

                // 2. System Tag Registry
                VStack(alignment: .leading, spacing: 6 * s) {
                    Text("SYSTEM TAG")
                        .font(.system(size: 10 * s, weight: .bold))
                        .tracking(1.4 * s)
                        .foregroundColor(AppConfig.Colors.subtextGrey)

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 72 * s), spacing: 6 * s)],
                        spacing: 6 * s
                    ) {
                        ForEach(store.availableTags, id: \.self) { tag in
                            let isSelected = !isCreatingCustomTag && draft.tag == tag
                            ZStack {
                                RoundedRectangle(cornerRadius: 5 * s)
                                    .fill(isSelected ? Color.black : Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5 * s)
                                            .strokeBorder(isSelected ? Color.black : Color.black.opacity(0.15), lineWidth: 1 * s)
                                    )

                                Text(tag)
                                    .font(.system(size: 9.5 * s, weight: .bold))
                                    .tracking(0.8 * s)
                                    .lineLimit(1)
                                    .foregroundColor(isSelected ? .white : Color.black)
                                    .padding(.horizontal, 4 * s)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 28 * s)
                            .contentShape(RoundedRectangle(cornerRadius: 5 * s))
                            .onTapGesture {
                                isCreatingCustomTag = false
                                store.taskDraft?.tag = tag
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    store.deleteTag(tag)
                                } label: {
                                    Label("Delete Tag \"\(tag)\"", systemImage: "trash")
                                }
                            }
                        }

                        // Add Custom Tag Trigger
                        ZStack {
                            RoundedRectangle(cornerRadius: 5 * s)
                                .fill(isCreatingCustomTag ? Color.black : Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5 * s)
                                        .strokeBorder(isCreatingCustomTag ? Color.black : Color.black.opacity(0.2), lineWidth: 1 * s)
                                )

                            HStack(spacing: 3 * s) {
                                Image(systemName: "plus")
                                    .font(.system(size: 8 * s, weight: .black))
                                Text("CUSTOM")
                                    .font(.system(size: 9.5 * s, weight: .bold))
                                    .tracking(0.8 * s)
                            }
                            .foregroundColor(isCreatingCustomTag ? .white : Color.black)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 28 * s)
                        .contentShape(RoundedRectangle(cornerRadius: 5 * s))
                        .onTapGesture {
                            isCreatingCustomTag = true
                        }
                    }

                    if isCreatingCustomTag {
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
                                        .strokeBorder(isTagValid ? Color.black : Color.red, lineWidth: 1.2 * s)
                                )
                                .onSubmit { confirmCustomTag() }

                            Button(action: confirmCustomTag) {
                                Text("ADD")
                                    .font(.system(size: 10 * s, weight: .black))
                                    .tracking(1.0 * s)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12 * s)
                                    .frame(height: 33 * s)
                                    .background(isTagValid ? Color.black : Color.black.opacity(0.3))
                                    .clipShape(RoundedRectangle(cornerRadius: 5 * s))
                            }
                            .buttonStyle(.plain)
                            .disabled(!isTagValid)

                            Button(action: {
                                isCreatingCustomTag = false
                                customTagText = ""
                            }) {
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

                // 3. Cadence Type Selection
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
                                    store.taskDraft?.isOneTime = false
                                    if store.taskDraft?.initialHealthState == .overdue {
                                        store.taskDraft?.initialHealthState = .due
                                    }
                                }
                            }
                            CadenceTypeTab(title: "ONE-TIME", isSelected: draft.isOneTime, s: s) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    store.taskDraft?.isOneTime = true
                                }
                            }
                        }
                        .padding(2 * s)
                        .background(Color.black.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6 * s))
                    }

                    if !draft.isOneTime {
                        HStack(spacing: 10 * s) {
                            HStack(spacing: 0) {
                                Button(action: {
                                    if let c = store.taskDraft?.repeatCount, c > 1 {
                                        store.taskDraft?.repeatCount -= 1
                                    }
                                }) {
                                    Image(systemName: "minus")
                                        .font(.system(size: 11 * s, weight: .bold))
                                        .foregroundColor(.black)
                                        .frame(width: 36 * s, height: 42 * s)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(SubtlePressStyle())

                                Divider().frame(height: 20 * s)

                                Text("\(draft.repeatCount)")
                                    .font(.system(size: 18 * s, weight: .black, design: .monospaced))
                                    .frame(maxWidth: .infinity)

                                Divider().frame(height: 20 * s)

                                Button(action: {
                                    store.taskDraft?.repeatCount += 1
                                }) {
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

                            HStack(spacing: 0) {
                                Button(action: {
                                    store.taskDraft?.repeatUnit = draft.repeatUnit.previous()
                                }) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 11 * s, weight: .bold))
                                        .foregroundColor(.black)
                                        .frame(width: 34 * s, height: 42 * s)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(SubtlePressStyle())

                                Divider().frame(height: 20 * s)

                                Text(draft.repeatUnit.displayString(count: draft.repeatCount).uppercased())
                                    .font(.system(size: 12 * s, weight: .bold))
                                    .tracking(0.6 * s)
                                    .frame(maxWidth: .infinity)

                                Divider().frame(height: 20 * s)

                                Button(action: {
                                    store.taskDraft?.repeatUnit = draft.repeatUnit.next()
                                }) {
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

                        if draft.repeatUnit == .day && draft.repeatCount == 1 {
                            HStack {
                                Text("DAILY DURATION")
                                    .font(.system(size: 10 * s, weight: .bold))
                                    .tracking(1.4 * s)
                                    .foregroundColor(AppConfig.Colors.subtextGrey)

                                Spacer()

                                HStack(spacing: 0) {
                                    Button(action: {
                                        if let d = store.taskDraft?.durationMinutes, d > 5 {
                                            store.taskDraft?.durationMinutes -= 5
                                        }
                                    }) {
                                        Image(systemName: "minus")
                                            .font(.system(size: 10 * s, weight: .bold))
                                            .frame(width: 28 * s, height: 30 * s)
                                    }
                                    .buttonStyle(SubtlePressStyle())

                                    Text("\(draft.durationMinutes) MIN")
                                        .font(.system(size: 11 * s, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 6 * s)

                                    Button(action: {
                                        store.taskDraft?.durationMinutes += 5
                                    }) {
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

                                    CadenceTypeTab(
                                        title: "TODAY",
                                        isSelected: draft.initialHealthState == .due,
                                        s: s
                                    ) {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                            store.taskDraft?.initialHealthState = .due
                                        }
                                    }

                                    CadenceTypeTab(
                                        title: "IN FUTURE",
                                        isSelected: isOneTimeInFuture,
                                        s: s
                                    ) {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                            store.taskDraft?.initialHealthState = .good
                                        }
                                    }
                                }
                                .padding(2 * s)
                                .background(Color.black.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 6 * s))
                            }

                            if isOneTimeInFuture {
                                HStack(spacing: 10 * s) {
                                    HStack(spacing: 0) {
                                        Button(action: {
                                            if let c = store.taskDraft?.repeatCount, c > 1 {
                                                store.taskDraft?.repeatCount -= 1
                                            }
                                        }) {
                                            Image(systemName: "minus")
                                                .font(.system(size: 11 * s, weight: .bold))
                                                .foregroundColor(.black)
                                                .frame(width: 36 * s, height: 42 * s)
                                                .contentShape(Rectangle())
                                        }
                                        .buttonStyle(SubtlePressStyle())

                                        Divider().frame(height: 20 * s)

                                        Text("\(draft.repeatCount)")
                                            .font(.system(size: 18 * s, weight: .black, design: .monospaced))
                                            .frame(maxWidth: .infinity)

                                        Divider().frame(height: 20 * s)

                                        Button(action: {
                                            store.taskDraft?.repeatCount += 1
                                        }) {
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

                                    HStack(spacing: 0) {
                                        Button(action: {
                                            store.taskDraft?.repeatUnit = draft.repeatUnit.previous()
                                        }) {
                                            Image(systemName: "chevron.left")
                                                .font(.system(size: 11 * s, weight: .bold))
                                                .foregroundColor(.black)
                                                .frame(width: 34 * s, height: 42 * s)
                                                .contentShape(Rectangle())
                                        }
                                        .buttonStyle(SubtlePressStyle())

                                        Divider().frame(height: 20 * s)

                                        Text(draft.repeatUnit.displayString(count: draft.repeatCount).uppercased())
                                            .font(.system(size: 12 * s, weight: .bold))
                                            .tracking(0.6 * s)
                                            .frame(maxWidth: .infinity)

                                        Divider().frame(height: 20 * s)

                                        Button(action: {
                                            store.taskDraft?.repeatUnit = draft.repeatUnit.next()
                                        }) {
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
                        }
                    }
                }

                // 4. Status Runway Gauge
                if !draft.isOneTime {
                    VStack(alignment: .leading, spacing: 8 * s) {
                        Text("CURRENT OPERATIONAL STATUS")
                            .font(.system(size: 10 * s, weight: .bold))
                            .tracking(1.4 * s)
                            .foregroundColor(AppConfig.Colors.subtextGrey)

                        HStack(spacing: 5 * s) {
                            ForEach(TaskHealthState.allCases, id: \.self) { state in
                                let isSelected = draft.initialHealthState == state
                                Button(action: {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                        store.taskDraft?.initialHealthState = state
                                    }
                                }) {
                                    VStack(spacing: 2 * s) {
                                        Text(state.rawValue)
                                            .font(.system(size: 10 * s, weight: .black))
                                            .tracking(0.5 * s)
                                        Text(state.subtitle)
                                            .font(.system(size: 7.5 * s, weight: .bold))
                                            .opacity(isSelected ? 0.75 : 0.6)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 40 * s)
                                    .background(isSelected ? (state == .overdue ? Color.red : Color.black) : Color.white)
                                    .foregroundColor(isSelected ? .white : Color.black)
                                    .clipShape(RoundedRectangle(cornerRadius: 6 * s))
                                    .overlay(RoundedRectangle(cornerRadius: 6 * s).strokeBorder(isSelected ? Color.clear : Color.black.opacity(0.15), lineWidth: 1 * s))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        HealthRunwayGauge(state: draft.initialHealthState, s: s)
                    }
                }

                // 5. Routing Indicator
                HStack(alignment: .center, spacing: 8 * s) {
                    Image(systemName: routingInfo.icon)
                        .font(.system(size: 11 * s, weight: .bold))
                        .foregroundColor(routingInfo.isImmediate ? (draft.initialHealthState == .overdue ? .red : Color.black) : AppConfig.Colors.subtextGrey)

                    Text(routingInfo.text)
                        .font(.system(size: 10.5 * s, weight: .medium))
                        .foregroundColor(Color.black.opacity(0.85))
                        .lineLimit(2)
                }
                .padding(.horizontal, 10 * s)
                .padding(.vertical, 8 * s)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 6 * s))

                // 6. Execution Dock
                VStack(spacing: 8 * s) {
                    Button(action: {
                        if isCreatingCustomTag { confirmCustomTag() }
                        store.commitDraft()
                    }) {
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

                    Button(action: { store.dismissDraft() }) {
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
                        Button(action: {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                store.deleteTask(id: draft.id)
                            }
                        }) {
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .onExitCommand(perform: { store.dismissDraft() })
        }
    }
}