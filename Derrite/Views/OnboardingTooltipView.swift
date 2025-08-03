//  OnboardingTooltipView.swift
//  Derrite
//  Subtle onboarding hints for first-time users

import SwiftUI

struct OnboardingTooltipView: View {
    let message: String
    let position: TooltipPosition
    let onDismiss: () -> Void

    @StateObject private var preferencesManager = PreferencesManager.shared
    enum TooltipPosition {
        case top, bottom, leading, trailing
    }

    var body: some View {
        VStack {
            if position == .bottom {
                Spacer()
            }

            HStack {
                if position == .trailing {
                    Spacer()
                }

                // Tooltip bubble
                VStack(spacing: 8) {
                    HStack(alignment: .top, spacing: 12) {
                        Text(message)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)

                        Button(action: {
                            onDismiss()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white.opacity(0.8))
                                .font(.title3)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .frame(minWidth: 200, maxWidth: 280)
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.blue)
                        .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 6)
                )
                .overlay(
                    // Arrow pointing to the feature
                    Triangle()
                        .fill(Color.blue)
                        .frame(width: 12, height: 6)
                        .rotationEffect(.degrees(arrowRotation))
                        .offset(arrowOffset)
                )
                .shadow(radius: 4)

                if position == .leading {
                    Spacer()
                }
            }

            if position == .top {
                Spacer()
            }
        }
        .onAppear {
            // Tooltip appeared
        }
    }

    private var arrowRotation: Double {
        switch position {
        case .top: return 180
        case .bottom: return 0
        case .leading: return 90
        case .trailing: return -90
        }
    }

    private var arrowOffset: CGSize {
        switch position {
        case .top: return CGSize(width: 0, height: 18)
        case .bottom: return CGSize(width: 0, height: -18)
        case .leading: return CGSize(width: 18, height: 0)
        case .trailing: return CGSize(width: -18, height: 0)
        }
    }

}

// Simple triangle shape for tooltip arrow
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// Manager to handle onboarding state
class OnboardingManager: ObservableObject {
    static let shared = OnboardingManager()

    @Published var currentTooltip: OnboardingTooltip?
    @Published var hasSeenOnboarding = false

    private let userDefaults = UserDefaults.standard
    private let onboardingKey = "has_seen_onboarding"

    private init() {
        hasSeenOnboarding = userDefaults.bool(forKey: onboardingKey)
    }

    func startOnboarding() {
        guard !hasSeenOnboarding else {
            return
        }

        // Start with the map tooltip
        showTooltip(.mapLongPress)
    }

    func showTooltip(_ tooltip: OnboardingTooltip) {
        currentTooltip = tooltip
    }

    func dismissCurrentTooltip() {
        guard let current = currentTooltip else { return }
        currentTooltip = nil

        // Show next tooltip in sequence immediately
        switch current {
        case .mapLongPress:
            self.showTooltip(.alertsButton)
        case .alertsButton:
            self.showTooltip(.languageToggle)
        case .languageToggle:
            // End of onboarding
            completeOnboarding()
        }
    }

    private func completeOnboarding() {
        hasSeenOnboarding = true
        userDefaults.set(true, forKey: onboardingKey)
    }

    func resetOnboarding() {
        hasSeenOnboarding = false
        userDefaults.set(false, forKey: onboardingKey)
        currentTooltip = nil
    }
}

enum OnboardingTooltip: CaseIterable {
    case mapLongPress
    case alertsButton
    case languageToggle

    var message: String {
        let preferencesManager = PreferencesManager.shared
        switch self {
        case .mapLongPress:
            return preferencesManager.localizedString("onboarding_map_hint")
        case .alertsButton:
            return preferencesManager.localizedString("onboarding_alerts_hint")
        case .languageToggle:
            return preferencesManager.localizedString("onboarding_language_hint")
        }
    }

    var position: OnboardingTooltipView.TooltipPosition {
        switch self {
        case .mapLongPress: return .top
        case .alertsButton: return .top
        case .languageToggle: return .top
        }
    }
}