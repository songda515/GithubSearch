//
//  GithubSearchApp.swift
//  GithubSearch
//
//  Created by 송다인 on 5/30/26.
//

import AppFeature
import SwiftUI

@main
struct GithubSearchApp: App {
    var body: some Scene {
        WindowGroup {
            // Thin shell: all real code lives in GithubSearchPackage.
            AppView.make()
        }
    }
}
