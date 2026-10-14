// Sources/Views/RightColumn/CreateTaskView.swift
import SwiftUI

public struct CreateTaskView: View {
    public var store: DashboardStore
    @Environment(\.scaleFactor) private var s

    // Recurrence cadence
    @State private var isOneTime: Bool = false
    @State private var repeatCount: Int = 1
    @State private var repeatUnit: CadenceUnit = .month

    // Health state
    @State private var selectedState: TaskHealthState = .good

    // Metadata
    @State private var title: String = ""
    @State private var selectedTag: String = ""
    @State private var isCreatingCustomTag: Bool = false
    @State private var customTagText: String = ""
    @State private var notes: String = ""

    public init(store: DashboardStore) {
        self.store = store
    }

    private var effectiveTag: String {
        let trimmedCustom = customTagText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if isCreatingCustomTag && !trimmedCustom.isEmpty {
            return trimmedCustom
        }
        return selectedTag.uppercased()
    }

    private var isValid: Bool {
        let hasTitle = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasTag = !effectiveTag.isEmpty
        return hasTitle && hasTag
    }

    private var routingInfo: (icon: String, text: String, isImmediate: Bool) {
        if isOneTime {
            switch selectedState {
            case .due, .overdue:
                return ("bolt.fill", "Immediate action: Added to Today's Focus Queue.", true)
            case .good, .notYet:
                return ("calendar", "Scheduled execution: Placed in Upcoming Horizon (In 3 Days).", false)
            }
        }

        let intervalDays = repeatUnit.days(count: repeatCount)
        switch selectedState {
        case .overdue:
            return ("exclamationmark.triangle.fill", "Overdue: Added to Today's Focus Queue as high priority.", true)
        case .due:
            if repeatUnit == .day && repeatCount == 1 {
                return ("checklist", "Daily routine: Added directly to Daily Baseline.", true)
            }
            return ("bolt.fill", "Due today: Added directly to Today's Focus Queue.", true)
        case .notYet:
            let daysLeft = max(1, intervalDays / 2)
            return ("clock", "In progress: Estimated due in ~\(daysLeft) days (Upcoming Horizon).", false)
        case .good:
            return ("checkmark.circle", "Cycle fresh: Next due in \(intervalDays) days (Upcoming Horizon).", false)
        }
    }

    private func confirmCustomTag() {
        let trimmed = customTagText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return }
        store.addCustomTag(trimmed)
        selectedTag = trimmed
        customTagText = ""
        isCreatingCustomTag = false
    }

    private func commitTask() {
        guard isValid else { return }

        // If user typed custom tag without hitting Enter/ADD, register it now
        if isCreatingCustomTag && !customTagText.isEmpty {
            confirmCustomTag()
        }

        store.dispatchConfiguredTask(
            title: title,
            tag: effectiveTag,
            notes: notes,
            isOneTime: isOneTime,
            repeatCount: repeatCount,
            repeatUnit: repeatUnit,
            healthState: selectedState
        )

        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            store.dismissCreateTask()
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18 * s) {
            // =================================================================
            // 1. TASK TITLE
            // =================================================================
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

            // =================================================================
            // 2. SYSTEM TAG REGISTRY (Sanitized Chips + Inline Confirm)
            // =================================================================
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
                        let isSelected = !isCreatingCustomTag && selectedTag == tag
                        Button(action: {
                            isCreatingCustomTag = false
                            selectedTag = tag
                        }) {
                            Text(tag)
                                .font(.system(size: 9.5 * s, weight: .bold))
                                .tracking(0.8 * s)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity)
                                .frame(height: 28 * s)
                                .background(isSelected ? Color.black : Color.white)
                                .foregroundColor(isSelected ? .white : Color.black)
                                .clipShape(RoundedRectangle(cornerRadius: 5 * s))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5 * s)
                                        .strokeBorder(isSelected ? Color.black : Color.black.opacity(0.15), lineWidth: 1 * s)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    // "+ Custom" Button
                    Button(action: {
                        isCreatingCustomTag = true
                    }) {
                        HStack(spacing: 3 * s) {
                            Image(systemName: "plus")
                                .font(.system(size: 8 * s, weight: .black))
                            Text("CUSTOM")
                                .font(.system(size: 9.5 * s, weight: .bold))
                                .tracking(0.8 * s)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 28 * s)
                        .background(isCreatingCustomTag ? Color.black : Color.white)
                        .foregroundColor(isCreatingCustomTag ? .white : Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 5 * s))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5 * s)
                                .strokeBorder(isCreatingCustomTag ? Color.black : Color.black.opacity(0.2), lineWidth: 1 * s)
                        )
                    }
                    .buttonStyle(.plain)
                }

                if isCreatingCustomTag {
                    HStack(spacing: 6 * s) {
                        TextField("ENTER NEW TAG (e.g. HVAC)", text: $customTagText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11 * s, weight: .bold))
                            .padding(.horizontal, 10 * s)
                            .padding(.vertical, 8 * s)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 5 * s))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5 * s)
                                    .strokeBorder(Color.black, lineWidth: 1.2 * s)
                            )
                            .onSubmit {
                                confirmCustomTag()
                            }

                        Button(action: confirmCustomTag) {
                            Text("ADD")
                                .font(.system(size: 10 * s, weight: .black))
                                .tracking(1.0 * s)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12 * s)
                                .frame(height: 33 * s)
                                .background(customTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.black.opacity(0.3) : Color.black)
                                .clipShape(RoundedRectangle(cornerRadius: 5 * s))
                        }
                        .buttonStyle(.plain)
                        .disabled(customTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

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

            // =================================================================
            // 3. RECURRENCE CADENCE (Ergonomic Dual Pod Stepper)
            // =================================================================
            VStack(alignment: .leading, spacing: 8 * s) {
                HStack {
                    Text("RECURRENCE CADENCE")
                        .font(.system(size: 10 * s, weight: .bold))
                        .tracking(1.4 * s)
                        .foregroundColor(AppConfig.Colors.subtextGrey)

                    Spacer()

                    // Recurrence vs One-Time Segment
                    HStack(spacing: 2 * s) {
                        CadenceTypeTab(title: "RECURRING", isSelected: !isOneTime, s: s) {
                            isOneTime = false
                        }
                        CadenceTypeTab(title: "ONE-TIME", isSelected: isOneTime, s: s) {
                            isOneTime = true
                        }
                    }
                    .padding(2 * s)
                    .background(Color.black.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6 * s))
                }

                if !isOneTime {
                    HStack(spacing: 10 * s) {
                        // Pod 1: Quantity Stepper
                        HStack(spacing: 0) {
                            Button(action: {
                                if repeatCount > 1 { repeatCount -= 1 }
                            }) {
                                Image(systemName: "minus")
                                    .font(.system(size: 11 * s, weight: .bold))
                                    .foregroundColor(.black)
                                    .frame(width: 36 * s, height: 42 * s)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(SubtlePressStyle())

                            Divider()
                                .frame(height: 20 * s)

                            Text("\(repeatCount)")
                                .font(.system(size: 18 * s, weight: .black, design: .monospaced))
                                .frame(maxWidth: .infinity)

                            Divider()
                                .frame(height: 20 * s)

                            Button(action: {
                                repeatCount += 1
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
                        .overlay(
                            RoundedRectangle(cornerRadius: 7 * s)
                                .strokeBorder(Color.black.opacity(0.15), lineWidth: 1 * s)
                        )

                        // Pod 2: Unit Stepper (Day <-> Week <-> Month <-> Year)
                        HStack(spacing: 0) {
                            Button(action: {
                                repeatUnit = repeatUnit.previous()
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 11 * s, weight: .bold))
                                    .foregroundColor(.black)
                                    .frame(width: 34 * s, height: 42 * s)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(SubtlePressStyle())

                            Divider()
                                .frame(height: 20 * s)

                            Text(repeatUnit.displayString(count: repeatCount).uppercased())
                                .font(.system(size: 12 * s, weight: .bold))
                                .tracking(0.6 * s)
                                .frame(maxWidth: .infinity)

                            Divider()
                                .frame(height: 20 * s)

                            Button(action: {
                                repeatUnit = repeatUnit.next()
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
                        .overlay(
                            RoundedRectangle(cornerRadius: 7 * s)
                                .strokeBorder(Color.black.opacity(0.15), lineWidth: 1 * s)
                        )
                    }
                } else {
                    HStack(spacing: 6 * s) {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10 * s))
                            .foregroundColor(AppConfig.Colors.subtextGrey)
                        Text("Task will execute once without recurring horizon intervals.")
                            .font(.system(size: 11 * s, weight: .medium))
                            .foregroundColor(AppConfig.Colors.subtextGrey)
                    }
                    .padding(.horizontal, 12 * s)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 42 * s)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 7 * s))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7 * s)
                            .strokeBorder(Color.black.opacity(0.12), lineWidth: 1 * s)
                    )
                }
            }

            // =================================================================
            // 4. CURRENT OPERATIONAL STATUS
            // =================================================================
            VStack(alignment: .leading, spacing: 8 * s) {
                Text("CURRENT OPERATIONAL STATUS")
                    .font(.system(size: 10 * s, weight: .bold))
                    .tracking(1.4 * s)
                    .foregroundColor(AppConfig.Colors.subtextGrey)

                HStack(spacing: 5 * s) {
                    ForEach(TaskHealthState.allCases, id: \.self) { state in
                        let isSelected = selectedState == state
                        Button(action: {
                            selectedState = state
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
                            .background(isSelected ? Color.black : Color.white)
                            .foregroundColor(isSelected ? .white : Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 6 * s))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6 * s)
                                    .strokeBorder(isSelected ? Color.black : Color.black.opacity(0.15), lineWidth: 1 * s)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Estimated Routing Summary Banner
                HStack(alignment: .center, spacing: 8 * s) {
                    Image(systemName: routingInfo.icon)
                        .font(.system(size: 11 * s, weight: .bold))
                        .foregroundColor(routingInfo.isImmediate ? Color.black : AppConfig.Colors.subtextGrey)

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
            }

            // =================================================================
            // 5. RUN NOTES / SPECS (Optional)
            // =================================================================
            VStack(alignment: .leading, spacing: 6 * s) {
                Text("OPERATIONAL CONTEXT / NOTES (OPTIONAL)")
                    .font(.system(size: 10 * s, weight: .bold))
                    .tracking(1.4 * s)
                    .foregroundColor(AppConfig.Colors.subtextGrey)

                TextField("Tools required, specific detergents, specs", text: $notes)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11 * s, weight: .regular))
                    .padding(.horizontal, 10 * s)
                    .padding(.vertical, 8 * s)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6 * s))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6 * s)
                            .strokeBorder(Color.black.opacity(0.15), lineWidth: 1 * s)
                    )
            }

            // =================================================================
            // 6. EXECUTION DOCK
            // =================================================================
            VStack(spacing: 8 * s) {
                Button(action: commitTask) {
                    HStack(spacing: 6 * s) {
                        Image(systemName: "plus")
                            .font(.system(size: 10 * s, weight: .black))
                        Text("DISPATCH TASK TO BOARD")
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

                Button(action: {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        store.dismissCreateTask()
                    }
                }) {
                    Text("CANCEL")
                        .font(.system(size: 10 * s, weight: .bold))
                        .tracking(1.2 * s)
                        .foregroundColor(AppConfig.Colors.subtextGrey)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32 * s)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4 * s)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            if selectedTag.isEmpty, let firstTag = store.availableTags.first {
                selectedTag = firstTag
            }
        }
    }
}

// MARK: - Subcomponents & Styles
private struct CadenceTypeTab: View {
    let title: String
    let isSelected: Bool
    let s: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 8.5 * s, weight: isSelected ? .black : .bold))
                .tracking(0.6 * s)
                .padding(.horizontal, 8 * s)
                .padding(.vertical, 4 * s)
                .background(isSelected ? Color.white : Color.clear)
                .foregroundColor(isSelected ? .black : AppConfig.Colors.subtextGrey)
                .clipShape(RoundedRectangle(cornerRadius: 4 * s))
                .shadow(color: isSelected ? Color.black.opacity(0.08) : Color.clear, radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }
}

private struct SubtlePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.black.opacity(0.06) : Color.clear)
    }
}