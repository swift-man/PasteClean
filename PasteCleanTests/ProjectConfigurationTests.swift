//
//  ProjectConfigurationTests.swift
//  PasteCleanTests
//

import Foundation
import Testing

@Suite("Project configuration")
struct ProjectConfigurationTests {

  @Test("Release signing does not suppress platform base entitlements")
  func releaseSigningKeepsBaseEntitlements() throws {
    let projectContents = try String(
      contentsOf: projectFileURL,
      encoding: .utf8
    )

    #expect(!projectContents.contains("CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO;"))
  }

  @Test("The extension claims its distribution signing identifiers")
  func extensionClaimsSigningIdentifiers() throws {
    let entitlementsData = try Data(contentsOf: extensionEntitlementsFileURL)
    let entitlements = try #require(
      PropertyListSerialization.propertyList(from: entitlementsData, format: nil)
        as? [String: Any]
    )

    #expect(
      entitlements["com.apple.application-identifier"] as? String
        == "$(AppIdentifierPrefix)$(PRODUCT_BUNDLE_IDENTIFIER)"
    )
    #expect(
      entitlements["com.apple.developer.team-identifier"] as? String
        == "$(DEVELOPMENT_TEAM)"
    )
  }

  @Test("App, extension, and tests use one advanced TestFlight build number")
  func testFlightBuildNumbersStaySynchronized() throws {
    let projectContents = try String(
      contentsOf: projectFileURL,
      encoding: .utf8
    )
    let marker = "CURRENT_PROJECT_VERSION = "
    let buildNumbers = projectContents.split(whereSeparator: \.isNewline).compactMap { line -> Int? in
      guard let markerRange = line.range(of: marker),
            let value = line[markerRange.upperBound...].split(separator: ";").first
      else { return nil }
      return Int(value.trimmingCharacters(in: .whitespaces))
    }

    // Three targets each have Debug and Release configurations. Keeping all
    // six aligned prevents an embedded extension from carrying a stale build.
    #expect(buildNumbers.count == 6)
    #expect(Set(buildNumbers).count == 1)
    let buildNumber = try #require(buildNumbers.first)
    #expect(buildNumber >= 3)
  }

  private var projectFileURL: URL {
    repositoryRootURL
      .appendingPathComponent("PasteClean.xcodeproj/project.pbxproj")
  }

  private var extensionEntitlementsFileURL: URL {
    repositoryRootURL
      .appendingPathComponent("PasteCleanExtension/PasteCleanExtension.entitlements")
  }

  private var repositoryRootURL: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
  }
}
