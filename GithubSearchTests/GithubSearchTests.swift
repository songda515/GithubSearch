//
//  GithubSearchTests.swift
//  GithubSearchTests
//
//  Created by 송다인 on 5/30/26.
//
//  App-shell smoke tests use Swift Testing. Real reducer/feature tests live in
//  GithubSearchPackage (AppFeatureTests) using TCA's TestStore.

import Testing

@testable import GithubSearch

struct GithubSearchTests {
    @Test
    func appModuleLinks() {
        // Smoke test: the app shell compiles and links against the package.
        #expect(true)
    }
}
