import SwiftUI

struct DetailPopover: View {
    @ObservedObject var usageService: UsageService
    @ObservedObject var modeStore: DisplayModeStore
    @ObservedObject var styleStore: WidgetStyleStore

    @AppStorage("cu_creditsFolded") private var creditsFolded: Bool = true

    // Orange accent for progress bars (matches menu bar widget)
    private let accentOrange = Color(red: 1.0, green: 0.6, blue: 0.0)

    var body: some View {
        Group {
            switch styleStore.style {
            case .native:
                content
            case .glass:
                glassBackground { content }
            }
        }
    }

    /// Liquid Glass on macOS 26+ (Tahoe); a translucent material on older systems that
    /// still run this app's macOS 13 minimum deployment target.
    @ViewBuilder
    private func glassBackground<Inner: View>(@ViewBuilder _ inner: () -> Inner) -> some View {
        if #available(macOS 26.0, *) {
            inner()
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        } else {
            inner()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Plan usage limits header
            Text("Plan usage limits")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)
                .padding(.bottom, 16)

            // Error state
            if let error = usageService.usage.error {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 12)
            }

            // Current session section
            VStack(alignment: .leading, spacing: 4) {
                Text("Current session")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Text(sessionResetLabel)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                usageBar(percent: usageService.usage.sessionPercent)
            }

            Divider()
                .padding(.vertical, 14)

            // Weekly limits section
            VStack(alignment: .leading, spacing: 4) {
                Text("Weekly limits")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)

                Text("All models")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .padding(.top, 4)

                Text(weeklyResetLabel)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                usageBar(percent: usageService.usage.weeklyPercent)

                // Model-specific limits (e.g. Fable, Sonnet, Opus)
                ForEach(Array(usageService.usage.modelLimits.enumerated()), id: \.offset) { _, model in
                    Text(model.label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.top, 10)

                    if let resetTime = model.resetTime {
                        Text("Resets \(resetLabel(for: resetTime))")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }

                    usageBar(percent: model.percent)
                }
            }

            if usageService.usage.creditsEnabled {
                Divider()
                    .padding(.vertical, 14)
                creditsSection
            }

            Divider()
                .padding(.vertical, 14)

            // Display size picker
            HStack(spacing: 8) {
                Text("Display")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Picker("", selection: $modeStore.displayMode) {
                    ForEach(DisplayMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .padding(.bottom, 10)

            // Style picker (Current / Liquid Glass)
            HStack(spacing: 8) {
                Text("Style")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Picker("", selection: $styleStore.style) {
                    ForEach(WidgetStyle.allCases) { style in
                        Text(style.label).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .padding(.bottom, 10)

            // Footer
            HStack {
                if let lastFetched = usageService.usage.lastFetched {
                    Text("Last updated: \(lastFetched, style: .relative) ago")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { usageService.refreshNow() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Divider()
                .padding(.vertical, 8)

            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Text("Quit")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(width: 300)
    }

    /// Foldable, collapsed by default. The dollar amount is intentionally never shown —
    /// only the percentage — this widget is for glancing, not for managing spend.
    private var creditsSection: some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { !creditsFolded },
                set: { creditsFolded = !$0 }
            )
        ) {
            VStack(alignment: .leading, spacing: 4) {
                if let percent = usageService.usage.creditsPercent {
                    usageBar(percent: percent)
                        .padding(.top, 8)
                }
                Link("Manage credits", destination: URL(string: "https://claude.ai/settings/usage")!)
                    .font(.system(size: 12.5))
                    .padding(.top, 8)
            }
        } label: {
            Text("Usage credits")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
        }
    }

    /// Shared progress-bar row (track + orange fill + "N% used" label).
    private func usageBar(percent: Double) -> some View {
        HStack(spacing: 12) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(accentOrange)
                        .frame(width: max(0, geo.size.width * min(percent, 100) / 100))
                }
            }
            .frame(height: 8)

            Text("\(Int(round(percent)))% used")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .fixedSize()
        }
        .padding(.top, 4)
    }

    private var sessionResetLabel: String {
        guard let resetTime = usageService.usage.sessionResetTime else {
            return ""
        }
        let remaining = resetTime.timeIntervalSinceNow
        if remaining <= 0 { return "Resetting soon" }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeStr = formatter.string(from: resetTime)
        if hours > 0 {
            return "Resets at \(timeStr) · in \(hours) hr \(minutes) min"
        }
        return "Resets at \(timeStr) · in \(minutes) min"
    }

    private var weeklyResetLabel: String {
        guard let resetTime = usageService.usage.weeklyResetTime else {
            return ""
        }
        return resetLabel(for: resetTime)
    }

    private func resetLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE h:mm a"
        return formatter.string(from: date)
    }
}
