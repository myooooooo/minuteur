import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppStateManager

    var body: some View {
        NavigationStack {
            List {
                Section("Apparence") {
                    Picker("Couleur du Néon", selection: neonThemeBinding) {
                        ForEach(NeonTheme.allCases, id: \.rawValue) { theme in
                            let unlocked = theme.isUnlocked(totalXP: appState.totalXP)
                            Text(unlocked ? theme.title : "\(theme.title) (verrouillé)")
                                .tag(theme)
                        }
                    }
                    .pickerStyle(.menu)
                    .listRowBackground(Color.black)

                    if !lockedThemes.isEmpty {
                        Text("Déverrouillement: Or (5h), Violet (15h), Rouge (30h)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color.black)
                    }
                }

                Section("Sensations") {
                    Toggle("Vibrations", isOn: vibrationsBinding)
                        .listRowBackground(Color.black)

                    Picker("Ambiance sonore", selection: soundscapeBinding) {
                        ForEach(FocusSoundscape.allCases, id: \.rawValue) { sound in
                            Text(sound.title)
                                .tag(sound)
                        }
                    }
                    .pickerStyle(.menu)
                    .listRowBackground(Color.black)
                }

                Section("Concentration") {
                    Toggle("Mode Concentration Strict", isOn: strictModeBinding)
                        .listRowBackground(Color.black)

                    Text("Envoie un rappel local si vous quittez l'app avant la fin.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.black)
                }

                Section("Système") {
                    Button("Réinitialiser l'Onboarding", role: .destructive) {
                        appState.resetOnboarding()
                    }
                    .listRowBackground(Color.black)
                }

                Section("À propos") {
                    Text("Anssafou Zineb")
                        .foregroundStyle(.white)
                        .listRowBackground(Color.black)

                    Link("Portfolio", destination: URL(string: "https://example.com/portfolio")!)
                        .listRowBackground(Color.black)

                    Link("LinkedIn", destination: URL(string: "https://www.linkedin.com")!)
                        .listRowBackground(Color.black)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }

    private var lockedThemes: [NeonTheme] {
        NeonTheme.allCases.filter { !$0.isUnlocked(totalXP: appState.totalXP) }
    }

    private var neonThemeBinding: Binding<NeonTheme> {
        Binding(
            get: { appState.neonTheme },
            set: { appState.updateNeonTheme($0) }
        )
    }

    private var vibrationsBinding: Binding<Bool> {
        Binding(
            get: { appState.isVibrationsEnabled },
            set: { appState.updateVibrations($0) }
        )
    }

    private var soundscapeBinding: Binding<FocusSoundscape> {
        Binding(
            get: { appState.selectedSoundscape },
            set: { appState.updateSoundscape($0) }
        )
    }

    private var strictModeBinding: Binding<Bool> {
        Binding(
            get: { appState.isStrictFocusModeEnabled },
            set: { appState.updateStrictFocusMode($0) }
        )
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppStateManager())
}
