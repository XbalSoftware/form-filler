//
//  AppLinks.swift
//  Form Filler
//
//  External links shown on the About page. They point at the project's
//  GitHub Pages site (repo XbalSoftware/form-filler, index.html at the
//  root) — one page with anchored sections.
//

import Foundation

nonisolated enum AppLinks {
    static let website = URL(string: "https://xbalsoftware.github.io/form-filler/")!
    static let userManual = URL(string: "https://xbalsoftware.github.io/form-filler/#user-manual")!
    static let privacyPolicy = URL(string: "https://xbalsoftware.github.io/form-filler/#privacy-policy")!
}
