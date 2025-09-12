//
//  Logger.swift
//  TrueGold
//
//  Created by Tilo Delau on 2025-09-12.
//


import Foundation

enum Logger {
    static func log(_ context: String, _ message: String) {
        print("📣 [\(context)] \(message)")
    }
}