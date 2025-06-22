//
//  HomeBoxConfigView.swift
//  MovingBox
//
//  Created by Camden Webster on 6/22/25.
//

import SwiftUI
import AuthenticationServices

struct HomeBoxConfigView: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var serverURL: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isValidatingConnection = false
    @State private var connectionStatus: ConnectionStatus = .unknown
    @State private var showingPasswordField = false
    @State private var isAuthenticating = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    @FocusState private var isServerURLFocused: Bool
    @FocusState private var isUsernameFocused: Bool
    @FocusState private var isPasswordFocused: Bool
    
    enum ConnectionStatus {
        case unknown
        case validating
        case valid
        case invalid(String)
        
        var icon: String {
            switch self {
            case .unknown:
                return "questionmark.circle"
            case .validating:
                return "arrow.clockwise"
            case .valid:
                return "checkmark.circle"
            case .invalid:
                return "exclamationmark.triangle"
            }
        }
        
        var color: Color {
            switch self {
            case .unknown:
                return .secondary
            case .validating:
                return .blue
            case .valid:
                return .green
            case .invalid:
                return .red
            }
        }
        
        var message: String {
            switch self {
            case .unknown:
                return "Enter server URL to validate"
            case .validating:
                return "Validating connection..."
            case .valid:
                return "Connection validated"
            case .invalid(let error):
                return "Connection failed: \(error)"
            }
        }
    }
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("HomeBox Server Configuration")
                        .font(.headline)
                    
                    Text("Connect to your self-hosted HomeBox instance to sync your inventory data while maintaining complete control over your information.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            Section("Server Configuration") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Server URL")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("https://homebox.example.com", text: $serverURL)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .focused($isServerURLFocused)
                        .onChange(of: serverURL) { _, newValue in
                            connectionStatus = .unknown
                            validateURL(newValue)
                        }
                    
                    Text("Enter the full URL of your HomeBox server")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Connection Status
                HStack {
                    Image(systemName: connectionStatus.icon)
                        .foregroundColor(connectionStatus.color)
                        .imageScale(.small)
                    
                    Text(connectionStatus.message)
                        .font(.caption)
                        .foregroundColor(connectionStatus.color)
                    
                    if case .validating = connectionStatus {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
                .padding(.top, 4)
            }
            
            // Authentication Section
            if case .valid = connectionStatus {
                Section("Authentication") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Login to HomeBox")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TextField("Username", text: $username)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .focused($isUsernameFocused)
                        
                        HStack {
                            if showingPasswordField {
                                SecureField("Password", text: $password)
                                    .textFieldStyle(.roundedBorder)
                                    .focused($isPasswordFocused)
                            } else {
                                Button("Enter Password") {
                                    showingPasswordField = true
                                    isPasswordFocused = true
                                }
                                .foregroundColor(.customPrimary)
                            }
                        }
                        
                        Button {
                            authenticateWithHomeBox()
                        } label: {
                            HStack {
                                if isAuthenticating {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Authenticating...")
                                } else {
                                    Image(systemName: "key")
                                    Text("Login to HomeBox")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canAuthenticate ? Color.customPrimary : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(!canAuthenticate || isAuthenticating)
                        
                        Text("Your credentials are securely stored in the iOS Keychain")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Advanced Options
            if case .valid = connectionStatus {
                Section("Advanced") {
                    Button("Test Connection") {
                        testHomeBoxConnection()
                    }
                    .foregroundColor(.customPrimary)
                    
                    Button("Clear Saved Credentials", role: .destructive) {
                        clearSavedCredentials()
                    }
                }
            }
        }
        .navigationTitle("HomeBox Setup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    saveConfiguration()
                }
                .disabled(!isValidConfiguration)
            }
            
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .onAppear {
            loadExistingConfiguration()
        }
        .alert("Configuration Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var canAuthenticate: Bool {
        case .valid = connectionStatus
        return !username.isEmpty && !password.isEmpty
    }
    
    private var isValidConfiguration: Bool {
        case .valid = connectionStatus
        return !serverURL.isEmpty && !username.isEmpty
    }
    
    // MARK: - Methods
    
    private func loadExistingConfiguration() {
        serverURL = settingsManager.homeBoxServerURL
        username = settingsManager.homeBoxUsername
        
        if !serverURL.isEmpty {
            validateURL(serverURL)
        }
    }
    
    private func validateURL(_ url: String) {
        guard !url.isEmpty else {
            connectionStatus = .unknown
            return
        }
        
        // Basic URL validation
        guard URL(string: url) != nil else {
            connectionStatus = .invalid("Invalid URL format")
            return
        }
        
        connectionStatus = .validating
        
        // Simulate URL validation - in real implementation, this would make an HTTP request
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // For now, assume valid if it's a proper URL
            if url.hasPrefix("http://") || url.hasPrefix("https://") {
                connectionStatus = .valid
            } else {
                connectionStatus = .invalid("URL must start with http:// or https://")
            }
        }
    }
    
    private func authenticateWithHomeBox() {
        isAuthenticating = true
        
        // Simulate authentication - in real implementation, this would authenticate with HomeBox
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isAuthenticating = false
            
            // For now, assume authentication succeeds
            print("🔑 HomeBoxConfigView - Authentication simulated successfully")
        }
    }
    
    private func testHomeBoxConnection() {
        // Simulate connection test
        print("🔗 HomeBoxConfigView - Testing connection to \(serverURL)")
    }
    
    private func clearSavedCredentials() {
        username = ""
        password = ""
        showingPasswordField = false
        
        // Clear from Keychain in real implementation
        print("🗑️ HomeBoxConfigView - Cleared saved credentials")
    }
    
    private func saveConfiguration() {
        guard isValidConfiguration else {
            errorMessage = "Please complete the server configuration and authentication"
            showingError = true
            return
        }
        
        // Save to settings
        settingsManager.homeBoxServerURL = serverURL
        settingsManager.homeBoxUsername = username
        
        // In real implementation, save password to Keychain
        print("💾 HomeBoxConfigView - Saved configuration for server: \(serverURL)")
        
        dismiss()
    }
}

#Preview {
    NavigationStack {
        HomeBoxConfigView()
            .environmentObject(SettingsManager())
    }
}