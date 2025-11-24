//
//  BugReportSheet.swift
//  Molten
//
//  Sheet for submitting bug reports via shake gesture
//

import SwiftUI

#if os(iOS)
struct BugReportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var bugDescription = ""
    @State private var email = ""
    @State private var includeDeviceInfo = true
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Shake detected! Found a bug?")
                        .font(.headline)
                        .foregroundColor(.orange)
                } header: {
                    HStack {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    TextField("What went wrong?", text: $bugDescription, axis: .vertical)
                        .lineLimit(5...10)
                } header: {
                    Text("Description")
                } footer: {
                    Text("Please describe what happened and what you expected to happen.")
                        .font(.caption)
                }

                Section {
                    TextField("Email (optional)", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                } header: {
                    Text("Contact")
                } footer: {
                    Text("Provide your email if you'd like a response.")
                        .font(.caption)
                }

                Section {
                    Toggle("Include device info", isOn: $includeDeviceInfo)
                } footer: {
                    if includeDeviceInfo {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Will include:")
                                .font(.caption)
                                .fontWeight(.medium)
                            Text("• App version: \(appVersion)")
                                .font(.caption2)
                            Text("• Device: \(deviceModel)")
                                .font(.caption2)
                            Text("• iOS: \(iosVersion)")
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Report Bug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("bug_report_cancel")
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Submit") {
                        submitBugReport()
                    }
                    .disabled(bugDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                    .accessibilityIdentifier("bug_report_submit")
                }
            }
            .alert("Bug Report Sent", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Thank you for helping improve Molten! Your bug report has been submitted to Sentry.")
            }
        }
    }

    // MARK: - Device Info

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }

    private var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }

    private var iosVersion: String {
        UIDevice.current.systemVersion
    }

    // MARK: - Submit

    private func submitBugReport() {
        isSubmitting = true
        errorMessage = nil

        // Build the bug report message
        var message = "Bug Report\n\n"
        message += "Description:\n\(bugDescription)\n\n"

        if !email.isEmpty {
            message += "Contact: \(email)\n\n"
        }

        if includeDeviceInfo {
            message += "Device Info:\n"
            message += "• App Version: \(appVersion)\n"
            message += "• Device: \(deviceModel)\n"
            message += "• iOS: \(iosVersion)\n"
        }

        // Send to Sentry as a user feedback/message event
        let logger = AppDependencies.shared.loggingService
        logger.error("User-reported bug via shake gesture", context: [
            "bug_description": bugDescription,
            "user_email": email,
            "device_model": deviceModel,
            "ios_version": iosVersion,
            "app_version": appVersion,
            "report_method": "shake_gesture"
        ])

        // Simulate delay for submission
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSubmitting = false
            showSuccess = true
        }
    }
}

#Preview {
    BugReportSheet()
}
#endif
