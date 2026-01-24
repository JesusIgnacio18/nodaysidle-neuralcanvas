import SwiftUI

// MARK: - Error Alert Modifier

/// View modifier for presenting error alerts
struct ErrorAlertModifier: ViewModifier {
    @Bindable var errorManager: ErrorManager

    func body(content: Content) -> some View {
        content
            .alert(
                errorManager.currentError?.title ?? "Error",
                isPresented: Binding(
                    get: { errorManager.isShowingError },
                    set: { if !$0 { errorManager.dismissCurrent() } }
                ),
                presenting: errorManager.currentError
            ) { error in
                ForEach(error.actions) { action in
                    Button(action.title, role: action.role) {
                        Task {
                            await action.action()
                            errorManager.dismissCurrent()
                        }
                    }
                }
            } message: { error in
                VStack(alignment: .leading, spacing: 4) {
                    Text(error.message)

                    if let helpURL = error.helpURL {
                        Link("Learn More", destination: helpURL)
                            .font(.footnote)
                    }
                }
            }
    }
}

extension View {
    /// Adds error alert presentation to the view
    func errorAlert(_ errorManager: ErrorManager) -> some View {
        modifier(ErrorAlertModifier(errorManager: errorManager))
    }
}

// MARK: - Toast View

/// Non-intrusive toast notification for info/warning messages
struct ToastView: View {
    let error: PresentableError
    let onDismiss: () -> Void

    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: error.severity.iconName)
                .foregroundStyle(error.severity.color)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(error.title)
                    .font(.headline)

                Text(error.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .padding(.horizontal)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : -20)
        .onAppear {
            withAnimation(.spring(duration: 0.3)) {
                isVisible = true
            }
        }
    }

    private func dismiss() {
        withAnimation(.spring(duration: 0.2)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
}

// MARK: - Error Banner View

/// Banner for persistent error states
struct ErrorBannerView: View {
    let message: String
    let severity: ErrorSeverity
    let action: (() -> Void)?
    let actionTitle: String?

    init(
        message: String,
        severity: ErrorSeverity = .error,
        action: (() -> Void)? = nil,
        actionTitle: String? = nil
    ) {
        self.message = message
        self.severity = severity
        self.action = action
        self.actionTitle = actionTitle
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: severity.iconName)
                .foregroundStyle(severity.color)

            Text(message)
                .font(.callout)

            Spacer()

            if let action = action, let title = actionTitle {
                Button(title) {
                    action()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(severity.color.opacity(0.1))
    }
}

// MARK: - Inline Error View

/// Inline error message for form fields
struct InlineErrorView: View {
    let message: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption)
            Text(message)
                .font(.caption)
        }
        .foregroundStyle(.red)
    }
}

// MARK: - Error History View (Debug)

#if DEBUG
/// Debug view showing error history
struct ErrorHistoryView: View {
    let errorManager: ErrorManager

    var body: some View {
        List(errorManager.errorHistory.reversed()) { error in
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: error.severity.iconName)
                        .foregroundStyle(error.severity.color)

                    Text(error.title)
                        .font(.headline)

                    Spacer()

                    Text(error.timestamp, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(error.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("Error History")
    }
}
#endif

// MARK: - Loading Error View

/// Full-screen error state with retry option
struct LoadingErrorView: View {
    let title: String
    let message: String
    let retryAction: (() -> Void)?

    init(
        title: String = "Something went wrong",
        message: String,
        retryAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.retryAction = retryAction
    }

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            if let retry = retryAction {
                Button("Try Again") {
                    retry()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

// MARK: - Previews

#Preview("Toast") {
    VStack {
        Spacer()
        ToastView(
            error: PresentableError(
                error: SimpleError(message: "Your changes have been saved"),
                severity: .info,
                title: "Saved"
            ),
            onDismiss: {}
        )
    }
    .frame(width: 400, height: 200)
}

#Preview("Error Banner") {
    VStack(spacing: 16) {
        ErrorBannerView(
            message: "Unable to connect to server",
            severity: .error,
            action: {},
            actionTitle: "Retry"
        )

        ErrorBannerView(
            message: "Your subscription will expire soon",
            severity: .warning
        )
    }
}

#Preview("Loading Error") {
    LoadingErrorView(
        message: "Failed to load projects. Please check your connection and try again.",
        retryAction: {}
    )
    .frame(width: 400, height: 300)
}
