//
//  main.swift
//  R.swift
//
//  Created by Mathijs Kadijk on 11-12-14.
//  From: https://github.com/mac-cain13/R.swift
//  License: MIT License
//

import Foundation

let IndentationString = "  "

let ResourceFilename = "R.generated.swift"

private let Header = [
  "// This is a generated file, do not edit!",
  "// Generated by R.swift, see https://github.com/mac-cain13/R.swift",
  ].joinWithSeparator("\n")

do {
  let callInformation = try CallInformation(processInfo: NSProcessInfo.processInfo())

  let xcodeproj = try Xcodeproj(url: callInformation.xcodeprojURL)
  let resourceURLs = try xcodeproj.resourcePathsForTarget(callInformation.targetName)
    .map(pathResolverWithSourceTreeFolderToURLConverter(callInformation.URLForSourceTreeFolder))
    .flatMap { $0 }

  let resources = Resources(resourceURLs: resourceURLs, fileManager: NSFileManager.defaultManager())

  let (internalStruct, externalStruct) = generateResourceStructsWithResources(resources, bundleIdentifier: callInformation.bundleIdentifier)

  let usedModules = [internalStruct, externalStruct]
    .flatMap(getUsedTypes)
    .map { $0.type.module }

  let imports = Set(usedModules)
    .subtract([Module.Custom(name: callInformation.productModuleName), Module.Host, Module.StdLib])
    .sortBy { $0.description }
    .map { "import \($0)" }
    .joinWithSeparator("\n")

  let fileContents = [
      Header,
      imports,
      externalStruct.description,
      internalStruct.description,
    ].joinWithSeparator("\n\n")

  // Write file if we have changes
  let currentFileContents = try? String(contentsOfURL: callInformation.outputURL, encoding: NSUTF8StringEncoding)
  if currentFileContents != fileContents  {
    do {
      try fileContents.writeToURL(callInformation.outputURL, atomically: true, encoding: NSUTF8StringEncoding)
    } catch let error as NSError {
      fail(error.description)
    }
  }

} catch let error as InputParsingError {
  if let errorDescription = error.errorDescription {
    fail(errorDescription)
  }

  print(error.helpString)

  switch error {
  case .IllegalOption, .MissingOption:
    exit(2)
  case .UserAskedForHelp, .UserRequestsVersionInformation:
    exit(0)
  }
} catch let error as ResourceParsingError {
  switch error {
  case let .ParsingFailed(description):
    fail(description)
  case let .UnsupportedExtension(givenExtension, supportedExtensions):
    let joinedSupportedExtensions = supportedExtensions.joinWithSeparator(", ")
    fail("File extension '\(givenExtension)' is not one of the supported extensions: \(joinedSupportedExtensions)")
  }

  exit(3)
}
