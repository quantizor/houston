import Foundation

// NOTE: This file is duplicated in HoustonHelper/HelperMessages.swift
// Both copies must stay in sync.

public enum HelperRequest: Codable, Sendable {
    case writePlist(data: Data, path: String)
    case deletePlist(path: String)
    case executeLaunchctl(arguments: [String], uid: UInt32)
    case executeProcess(path: String, arguments: [String])
    case querySystemLog(predicate: String, sinceInterval: Double, limit: Int)
    case getVersion
}

public enum HelperResponse: Codable, Sendable {
    case success
    case processOutput(stdout: String, stderr: String)
    case logOutput(String)
    case version(String)
    case error(String)
}
