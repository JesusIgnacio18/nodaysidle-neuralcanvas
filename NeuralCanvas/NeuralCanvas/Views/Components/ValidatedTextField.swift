import SwiftUI

// MARK: - Validation Rule

/// A rule for validating text input
struct ValidationRule: Sendable {
    let validate: @Sendable (String) -> Bool
    let message: String

    init(message: String, validate: @escaping @Sendable (String) -> Bool) {
        self.message = message
        self.validate = validate
    }

    // Common validation rules
    static let notEmpty = ValidationRule(message: "This field is required") { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    static func minLength(_ length: Int) -> ValidationRule {
        ValidationRule(message: "Must be at least \(length) characters") { $0.count >= length }
    }

    static func maxLength(_ length: Int) -> ValidationRule {
        ValidationRule(message: "Must be at most \(length) characters") { $0.count <= length }
    }

    static let validProjectName = ValidationRule(message: "Invalid project name") { name in
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard trimmed.count <= 255 else { return false }

        // Check for invalid characters
        let invalidCharacters = CharacterSet(charactersIn: "<>:\"|?*\\/")
        return trimmed.rangeOfCharacter(from: invalidCharacters) == nil
    }

    static let validFileName = ValidationRule(message: "Invalid file name") { name in
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard trimmed.count <= 255 else { return false }

        // Check for path traversal
        guard !trimmed.contains("..") else { return false }
        guard !trimmed.contains("/") else { return false }
        guard !trimmed.contains("\\") else { return false }

        return true
    }
}

// MARK: - Validation State

/// State for tracking validation
@Observable
final class ValidationState {
    var isValid = true
    var errorMessage: String?

    func validate(_ value: String, rules: [ValidationRule]) {
        for rule in rules {
            if !rule.validate(value) {
                isValid = false
                errorMessage = rule.message
                return
            }
        }

        isValid = true
        errorMessage = nil
    }

    func reset() {
        isValid = true
        errorMessage = nil
    }
}

// MARK: - Validated Text Field

/// Text field with built-in validation
struct ValidatedTextField: View {
    let title: String
    @Binding var text: String
    let rules: [ValidationRule]
    let placeholder: String

    @State private var validation = ValidationState()
    @State private var hasBeenEdited = false

    @FocusState private var isFocused: Bool

    init(
        _ title: String,
        text: Binding<String>,
        placeholder: String = "",
        rules: [ValidationRule] = [.notEmpty]
    ) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.rules = rules
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(title, text: $text, prompt: Text(placeholder))
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onChange(of: text) { _, newValue in
                    if hasBeenEdited {
                        validation.validate(newValue, rules: rules)
                    }
                }
                .onChange(of: isFocused) { _, focused in
                    if !focused && !hasBeenEdited {
                        hasBeenEdited = true
                        validation.validate(text, rules: rules)
                    }
                }
                .overlay(alignment: .trailing) {
                    if hasBeenEdited {
                        Image(systemName: validation.isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundStyle(validation.isValid ? .green : .red)
                            .padding(.trailing, 8)
                    }
                }

            if let error = validation.errorMessage, hasBeenEdited {
                InlineErrorView(message: error)
            }
        }
    }

    /// Whether the current value is valid
    var isValid: Bool {
        validation.isValid || !hasBeenEdited
    }

    /// Triggers validation manually
    func validate() {
        hasBeenEdited = true
        validation.validate(text, rules: rules)
    }
}

// MARK: - Validated Form Field

/// Generic form field with validation
struct ValidatedFormField<Content: View>: View {
    let label: String
    let isValid: Bool
    let errorMessage: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.headline)

            content()

            if let error = errorMessage, !isValid {
                InlineErrorView(message: error)
            }
        }
    }
}

// MARK: - Image Dimension Validator

/// Validates image dimensions for import
struct ImageDimensionValidator {
    static let minDimension: Int = 64
    static let maxDimension: Int = 8192

    enum Result {
        case valid
        case tooSmall(width: Int, height: Int)
        case tooLarge(width: Int, height: Int)
    }

    static func validate(width: Int, height: Int) -> Result {
        if width < minDimension || height < minDimension {
            return .tooSmall(width: width, height: height)
        }

        if width > maxDimension || height > maxDimension {
            return .tooLarge(width: width, height: height)
        }

        return .valid
    }

    static func errorMessage(for result: Result) -> String? {
        switch result {
        case .valid:
            return nil
        case .tooSmall(let width, let height):
            return "Image too small (\(width)×\(height)). Minimum size is \(minDimension)×\(minDimension) pixels."
        case .tooLarge(let width, let height):
            return "Image too large (\(width)×\(height)). Maximum size is \(maxDimension)×\(maxDimension) pixels."
        }
    }
}

// MARK: - Form Validation Helper

/// Helper for validating entire forms
@MainActor
final class FormValidator {
    private var fieldValidations: [String: Bool] = [:]

    /// Registers a field's validation state
    func setFieldValid(_ field: String, isValid: Bool) {
        fieldValidations[field] = isValid
    }

    /// Returns whether all fields are valid
    var isFormValid: Bool {
        fieldValidations.values.allSatisfy { $0 }
    }

    /// Returns invalid field names
    var invalidFields: [String] {
        fieldValidations.filter { !$0.value }.map { $0.key }
    }

    /// Resets all validation states
    func reset() {
        fieldValidations.removeAll()
    }
}

// MARK: - Previews

#Preview("Validated Text Field") {
    struct PreviewWrapper: View {
        @State private var projectName = ""
        @State private var description = ""

        var body: some View {
            Form {
                ValidatedTextField(
                    "Project Name",
                    text: $projectName,
                    placeholder: "My Wireframe Project",
                    rules: [.notEmpty, .validProjectName]
                )

                ValidatedTextField(
                    "Description",
                    text: $description,
                    placeholder: "Optional description",
                    rules: [.maxLength(500)]
                )
            }
            .padding()
            .frame(width: 400)
        }
    }

    return PreviewWrapper()
}
