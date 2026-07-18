//
//  AboutView.swift
//  Form Filler
//

import SwiftUI

struct AboutView: View {
    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return build.map { "\(short) (\($0))" } ?? short
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Version", value: version)
            } footer: {
                Text("Form Filler templates PDF referral forms: import a form once, place its fields, then fill and export completed copies. Everything stays on this iPad.")
            }
            Section("Resources") {
                Link(destination: AppLinks.userManual) {
                    Label("User Manual", systemImage: "book")
                }
                Link(destination: AppLinks.privacyPolicy) {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }
            }
        }
        .navigationTitle("About Form Filler")
        .navigationBarTitleDisplayMode(.inline)
    }
}
