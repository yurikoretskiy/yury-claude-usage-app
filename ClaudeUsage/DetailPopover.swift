import SwiftUI

struct DetailPopover: View {
    @ObservedObject var usageService: UsageService
    @ObservedObject var modeStore: DisplayModeStore

    @AppStorage("cu_creditsFolded") private var creditsFolded: Bool = true

    // Orange accent for progress bars (matches menu bar widget)
    private let accentOrange = Color(red: 1.0, green: 0.6, blue: 0.0)
    // Muted brick red matching claude.ai's exhausted-credits bar — pure .red read as
    // too dramatic in the popover.
    private let brickRed = Color(red: 0.76, green: 0.31, blue: 0.26)

    var body: some View {
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

            Divider()
                .padding(.vertical, 14)
            creditsSection

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

    /// Always shown, fold state persisted independent of on/off — the status badge in the
    /// header is the thing to glance at (it's easy to forget credits are left enabled);
    /// unfolding always reveals whatever detail is available regardless of that state.
    /// The whole header row is one button — the bare DisclosureGroup chevron was too
    /// small a click target.
    private var creditsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: { creditsFolded.toggle() }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(creditsFolded ? 0 : 90))
                    Text("Usage credits")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    creditsBadge
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !creditsFolded {
                if let percent = usageService.usage.creditsPercent {
                    usageBar(percent: percent,
                             critical: usageService.usage.creditsCritical,
                             dimmed: usageService.usage.creditsState == .off)
                        .padding(.top, 8)
                }
                if let used = usageService.usage.creditsUsedDollars,
                   let limit = usageService.usage.creditsLimitDollars {
                    Text("\(dollarString(used)) of \(dollarString(limit))")
                        .font(.system(size: 12.5))
                        .foregroundColor(.secondary)
                }
                Link("Manage credits", destination: URL(string: "https://claude.ai/settings/usage")!)
                    .font(.system(size: 12.5))
                    .padding(.top, 8)
            }
        }
    }

    /// On = orange dot (worth noticing you left it on). Limit reached = red, loudest —
    /// credits ran dry, the claude.ai toggle is still ON. Off = gray, ignorable.
    private var creditsBadge: some View {
        let (dot, label, labelColor, weight): (Color, String, Color, Font.Weight) = {
            switch usageService.usage.creditsState {
            case .on:
                return (accentOrange, "On", .primary, .semibold)
            case .limitReached:
                return (brickRed, "Limit reached", brickRed, .semibold)
            case .off:
                return (Color.secondary.opacity(0.35), "Off", .secondary, .regular)
            }
        }()
        return HStack(spacing: 5) {
            Circle()
                .fill(dot)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 12, weight: weight))
                .foregroundColor(labelColor)
        }
    }

    private func dollarString(_ amount: Double) -> String {
        "$" + String(format: "%.2f", amount)
    }

    /// Shared progress-bar row (track + orange fill + "N% used" label).
    /// `critical` = muted brick fill (claude.ai's exhausted-credits look);
    /// `dimmed` = gray fill for credits shown while toggled off (last-known data).
    private func usageBar(percent: Double, critical: Bool = false, dimmed: Bool = false) -> some View {
        HStack(spacing: 12) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(dimmed ? Color.secondary.opacity(0.5) : (critical ? brickRed : accentOrange))
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
