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

  @Test("The extension embeds and signs the linked XcodeKit framework in every build")
  func extensionEmbedsXcodeKit() throws {
    let project = try #require(
      PropertyListSerialization.propertyList(
        from: Data(contentsOf: projectFileURL), format: nil
      ) as? [String: Any]
    )
    let objects = try #require(project["objects"] as? [String: [String: Any]])
    let target = try #require(
      objects.values.first {
        $0["isa"] as? String == "PBXNativeTarget"
          && $0["name"] as? String == "PasteCleanExtension"
      })
    let phaseIDs = try #require(target["buildPhases"] as? [String])
    let phases = try phaseIDs.map { try #require(objects[$0]) }
    let embedPhase = try #require(
      phases.first {
        $0["isa"] as? String == "PBXCopyFilesBuildPhase"
          && $0["dstSubfolderSpec"] as? String == "10"
      })

    // XcodeKit is not a system framework: linking alone builds successfully
    // but leaves Xcode unable to load the installed extension.
    #expect(embedPhase["dstPath"] as? String == "")
    #expect(embedPhase["buildActionMask"] as? String == "2147483647")
    #expect(embedPhase["runOnlyForDeploymentPostprocessing"] as? String == "0")

    let embeddedFileIDs = try #require(embedPhase["files"] as? [String])
    let embeddedFiles = try embeddedFileIDs.map { try #require(objects[$0]) }
    let embeddedFramework = try #require(
      embeddedFiles.first { file in
        guard let referenceID = file["fileRef"] as? String else { return false }
        return objects[referenceID]?["path"] as? String
          == "Library/Frameworks/XcodeKit.framework"
      })
    let frameworkID = try #require(embeddedFramework["fileRef"] as? String)
    #expect(objects[frameworkID]?["sourceTree"] as? String == "DEVELOPER_DIR")

    let settings = try #require(embeddedFramework["settings"] as? [String: Any])
    let attributes = try #require(settings["ATTRIBUTES"] as? [String])
    #expect(attributes.contains("CodeSignOnCopy"))
    #expect(attributes.contains("RemoveHeadersOnCopy"))

    let linkPhase = try #require(
      phases.first {
        $0["isa"] as? String == "PBXFrameworksBuildPhase"
      })
    let linkedFileIDs = try #require(linkPhase["files"] as? [String])
    #expect(linkedFileIDs.contains { objects[$0]?["fileRef"] as? String == frameworkID })
  }

  @Test("The app bundles its license and privacy notices")
  func appBundlesLegalNotices() throws {
    let objects = try projectObjects()
    let resourcePaths = try appResourcePaths(in: objects)

    let requiredNotices = ["LICENSE", "COPYING", "PRIVACY.md"]
    for notice in requiredNotices {
      #expect(resourcePaths.contains(notice))

      let noticeURL = repositoryRootURL.appendingPathComponent(notice)
      let contents = try String(contentsOf: noticeURL, encoding: .utf8)
      #expect(!contents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
  }

  @Test("The app bundles an accurate privacy manifest")
  func appBundlesPrivacyManifest() throws {
    let objects = try projectObjects()
    #expect(try appResourcePaths(in: objects).contains("PrivacyInfo.xcprivacy"))

    let manifestURL =
      repositoryRootURL
      .appendingPathComponent("PasteClean/PrivacyInfo.xcprivacy")
    let manifest = try #require(
      PropertyListSerialization.propertyList(
        from: Data(contentsOf: manifestURL),
        format: nil
      ) as? [String: Any]
    )

    #expect(manifest["NSPrivacyTracking"] as? Bool == false)
    #expect((manifest["NSPrivacyCollectedDataTypes"] as? [Any])?.isEmpty == true)

    let accessedAPIs = try #require(
      manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]]
    )
    let userDefaults = try #require(
      accessedAPIs.first {
        $0["NSPrivacyAccessedAPIType"] as? String
          == "NSPrivacyAccessedAPICategoryUserDefaults"
      })
    #expect(
      userDefaults["NSPrivacyAccessedAPITypeReasons"] as? [String]
        == ["CA92.1"]
    )
  }

  @Test("Every app build configuration has a copyright notice")
  func appBuildConfigurationsHaveCopyrightNotice() throws {
    let objects = try projectObjects()
    let appTarget = try #require(
      objects.values.first {
        $0["isa"] as? String == "PBXNativeTarget"
          && $0["name"] as? String == "PasteClean"
      })
    let configurationListID = try #require(
      appTarget["buildConfigurationList"] as? String
    )
    let configurationList = try #require(objects[configurationListID])
    let configurationIDs = try #require(
      configurationList["buildConfigurations"] as? [String]
    )
    #expect(!configurationIDs.isEmpty)

    for configurationID in configurationIDs {
      let configuration = try #require(objects[configurationID])
      let settings = try #require(configuration["buildSettings"] as? [String: Any])
      let copyright = try #require(
        settings["INFOPLIST_KEY_NSHumanReadableCopyright"] as? String
      )
      #expect(!copyright.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
  }

  @Test("App, extension, and tests use one advanced TestFlight build number")
  func testFlightBuildNumbersStaySynchronized() throws {
    let projectContents = try String(
      contentsOf: projectFileURL,
      encoding: .utf8
    )
    let marker = "CURRENT_PROJECT_VERSION = "
    let buildNumbers = projectContents.split(whereSeparator: \.isNewline).compactMap {
      line -> Int? in
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
    #expect(buildNumber >= 8)
  }

  @Test("App, extension, and tests match VERSION.txt")
  func marketingVersionsStaySynchronized() throws {
    let expectedVersion = try String(
      contentsOf: repositoryRootURL.appendingPathComponent("VERSION.txt"),
      encoding: .utf8
    ).trimmingCharacters(in: .whitespacesAndNewlines)
    let projectContents = try String(
      contentsOf: projectFileURL,
      encoding: .utf8
    )
    let marker = "MARKETING_VERSION = "
    let marketingVersions =
      projectContents
      .split(whereSeparator: \.isNewline)
      .compactMap { line -> String? in
        guard let markerRange = line.range(of: marker),
          let value = line[markerRange.upperBound...].split(separator: ";").first
        else { return nil }
        return value.trimmingCharacters(in: .whitespaces)
      }

    #expect(marketingVersions.count == 6)
    #expect(Set(marketingVersions) == [expectedVersion])
  }

  @Test("The shared app scheme archives the host app")
  func sharedAppSchemeArchivesHostApp() throws {
    let schemeDocument = try XMLDocument(
      contentsOf: sharedAppSchemeFileURL,
      options: []
    )

    let archiveBuildEntries = try schemeDocument.nodes(
      forXPath: "//BuildActionEntry[@buildForArchiving='YES']/BuildableReference"
    )
    let archivedProducts = try archiveBuildEntries.map(buildableIdentity)
    #expect(archivedProducts == [appBuildableIdentity])

    let archiveActions = try schemeDocument.nodes(
      forXPath: "/Scheme/ArchiveAction[@buildConfiguration='Release']"
    )
    #expect(archiveActions.count == 1)

    let launchReferences = try schemeDocument.nodes(
      forXPath: "/Scheme/LaunchAction/BuildableProductRunnable/BuildableReference"
    )
    #expect(
      try launchReferences.map(buildableIdentity) == [appBuildableIdentity]
    )

    let profileReferences = try schemeDocument.nodes(
      forXPath: "/Scheme/ProfileAction/BuildableProductRunnable/BuildableReference"
    )
    #expect(
      try profileReferences.map(buildableIdentity) == [appBuildableIdentity]
    )
  }

  @Test("The shared test scheme keeps the test target available")
  func sharedTestSchemeKeepsTestTargetAvailable() throws {
    let schemeDocument = try XMLDocument(
      contentsOf: sharedTestSchemeFileURL,
      options: []
    )
    let testableReferences = try schemeDocument.nodes(
      forXPath: "//TestableReference/BuildableReference"
    )

    #expect(
      try testableReferences.map(buildableIdentity)
        == [testBuildableIdentity]
    )
  }

  private var projectFileURL: URL {
    repositoryRootURL
      .appendingPathComponent("PasteClean.xcodeproj/project.pbxproj")
  }

  private func projectObjects() throws -> [String: [String: Any]] {
    let project = try #require(
      PropertyListSerialization.propertyList(
        from: Data(contentsOf: projectFileURL),
        format: nil
      ) as? [String: Any]
    )
    return try #require(project["objects"] as? [String: [String: Any]])
  }

  private func appResourcePaths(
    in objects: [String: [String: Any]]
  ) throws -> Set<String> {
    let appTarget = try #require(
      objects.values.first {
        $0["isa"] as? String == "PBXNativeTarget"
          && $0["name"] as? String == "PasteClean"
      })
    let phaseIDs = try #require(appTarget["buildPhases"] as? [String])
    let resourcePhase = try #require(
      phaseIDs.compactMap { objects[$0] }.first {
        $0["isa"] as? String == "PBXResourcesBuildPhase"
      })
    let resourceBuildFileIDs = try #require(resourcePhase["files"] as? [String])
    return Set(
      resourceBuildFileIDs.compactMap { buildFileID -> String? in
        guard let fileReferenceID = objects[buildFileID]?["fileRef"] as? String else {
          return nil
        }
        return objects[fileReferenceID]?["path"] as? String
      })
  }

  private var extensionEntitlementsFileURL: URL {
    repositoryRootURL
      .appendingPathComponent("PasteCleanExtension/PasteCleanExtension.entitlements")
  }

  private var sharedAppSchemeFileURL: URL {
    sharedSchemesDirectoryURL.appendingPathComponent("PasteClean.xcscheme")
  }

  private var sharedTestSchemeFileURL: URL {
    sharedSchemesDirectoryURL.appendingPathComponent("PasteCleanTests.xcscheme")
  }

  private var sharedSchemesDirectoryURL: URL {
    repositoryRootURL
      .appendingPathComponent("PasteClean.xcodeproj/xcshareddata/xcschemes")
  }

  private var appBuildableIdentity: BuildableIdentity {
    BuildableIdentity(
      blueprintIdentifier: "214463214C206F029C3B6CF9",
      buildableName: "PasteClean.app",
      blueprintName: "PasteClean"
    )
  }

  private var testBuildableIdentity: BuildableIdentity {
    BuildableIdentity(
      blueprintIdentifier: "35F2C81D4A0E76B93C5D2081",
      buildableName: "PasteCleanTests.xctest",
      blueprintName: "PasteCleanTests"
    )
  }

  private func buildableIdentity(from node: XMLNode) throws -> BuildableIdentity {
    let element = try #require(node as? XMLElement)
    let blueprintIdentifier = try #require(
      element.attribute(forName: "BlueprintIdentifier")?.stringValue
    )
    let buildableName = try #require(
      element.attribute(forName: "BuildableName")?.stringValue
    )
    let blueprintName = try #require(
      element.attribute(forName: "BlueprintName")?.stringValue
    )

    return BuildableIdentity(
      blueprintIdentifier: blueprintIdentifier,
      buildableName: buildableName,
      blueprintName: blueprintName
    )
  }

  private var repositoryRootURL: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
  }
}

private struct BuildableIdentity: Equatable {
  let blueprintIdentifier: String
  let buildableName: String
  let blueprintName: String
}
