import AppKit
import Foundation

guard CommandLine.arguments.count == 3,
      let image = NSImage(contentsOfFile: CommandLine.arguments[1]),
      FileManager.default.fileExists(atPath: CommandLine.arguments[2]) else {
    FileHandle.standardError.write(Data("Usage: swift Scripts/set-file-icon.swift <icon.icns> <existing-file>\n".utf8))
    exit(1)
}

guard NSWorkspace.shared.setIcon(image, forFile: CommandLine.arguments[2], options: []) else {
    FileHandle.standardError.write(Data("Could not apply the Finder custom icon.\n".utf8))
    exit(1)
}
