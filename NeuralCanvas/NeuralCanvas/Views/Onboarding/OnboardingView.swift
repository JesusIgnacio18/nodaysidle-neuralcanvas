import SwiftUI

// MARK: - Onboarding Step

/// Represents a step in the onboarding flow
struct OnboardingStep: Identifiable {
    let id: Int
    let title: String
    let description: String
    let systemImage: String
    let accentColor: Color

    static let steps: [OnboardingStep] = [
        OnboardingStep(
            id: 0,
            title: "Sketch Your Ideas",
            description: "Draw freely on the canvas using your mouse, trackpad, or Apple Pencil. NeuralCanvas captures every stroke.",
            systemImage: "pencil.and.outline",
            accentColor: .blue
        ),
        OnboardingStep(
            id: 1,
            title: "Style Mirror",
            description: "Import a screenshot of any UI you love. NeuralCanvas extracts colors, typography, and spacing to apply to your wireframes.",
            systemImage: "rectangle.on.rectangle.angled",
            accentColor: .purple
        ),
        OnboardingStep(
            id: 2,
            title: "Export Anywhere",
            description: "Export your wireframes as SVG, PDF, or PNG. Perfect for sharing with your team or importing into design tools.",
            systemImage: "square.and.arrow.up",
            accentColor: .green
        )
    ]
}

// MARK: - Onboarding View

/// First-launch onboarding showing key features
struct OnboardingView: View {
    @Binding var isPresented: Bool
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var currentStep = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let steps = OnboardingStep.steps

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                Button("Skip") {
                    completeOnboarding()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding()

            // Content
            TabView(selection: $currentStep) {
                ForEach(steps) { step in
                    OnboardingStepView(step: step)
                        .tag(step.id)
                }
            }
            .tabViewStyle(.automatic)
            .frame(maxHeight: .infinity)

            // Page indicator
            HStack(spacing: 8) {
                ForEach(steps) { step in
                    Circle()
                        .fill(step.id == currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.2), value: currentStep)
                }
            }
            .padding(.bottom, 20)

            // Navigation buttons
            HStack(spacing: 16) {
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation(reduceMotion ? .none : .easeInOut) {
                            currentStep -= 1
                        }
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                if currentStep < steps.count - 1 {
                    Button("Continue") {
                        withAnimation(reduceMotion ? .none : .easeInOut) {
                            currentStep += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") {
                        completeOnboarding()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 30)
        }
        .frame(width: 600, height: 500)
        .background(.regularMaterial)
    }

    private func completeOnboarding() {
        hasCompletedOnboarding = true
        withAnimation(reduceMotion ? .none : .easeOut(duration: 0.3)) {
            isPresented = false
        }
        AppLogger.uiEvents.info("Onboarding completed")
    }
}

// MARK: - Onboarding Step View

/// Individual step content view
struct OnboardingStepView: View {
    let step: OnboardingStep

    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(step.accentColor.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: step.systemImage)
                    .font(.system(size: 48))
                    .foregroundColor(step.accentColor)
                    .scaleEffect(isAnimating ? 1.0 : 0.8)
                    .opacity(isAnimating ? 1.0 : 0.0)
            }
            .onAppear {
                withAnimation(reduceMotion ? .none : .spring(duration: 0.5, bounce: 0.3)) {
                    isAnimating = true
                }
            }
            .onDisappear {
                isAnimating = false
            }

            // Title
            Text(step.title)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            // Description
            Text(step.description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(40)
    }
}

// MARK: - Onboarding Manager

/// Manages onboarding state
@MainActor
@Observable
final class OnboardingManager {
    @ObservationIgnored
    @AppStorage("hasCompletedOnboarding") private var _hasCompletedOnboarding = false

    var shouldShowOnboarding: Bool {
        !_hasCompletedOnboarding
    }

    func reset() {
        _hasCompletedOnboarding = false
        AppLogger.uiEvents.info("Onboarding reset")
    }

    func markCompleted() {
        _hasCompletedOnboarding = true
        AppLogger.uiEvents.info("Onboarding marked as completed")
    }
}

// MARK: - Onboarding Modifier

/// View modifier to show onboarding on first launch
struct OnboardingModifier: ViewModifier {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                if !hasCompletedOnboarding {
                    showOnboarding = true
                }
            }
            .sheet(isPresented: $showOnboarding) {
                OnboardingView(isPresented: $showOnboarding)
            }
    }
}

extension View {
    /// Presents onboarding on first launch
    func withOnboarding() -> some View {
        modifier(OnboardingModifier())
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(isPresented: .constant(true))
}
