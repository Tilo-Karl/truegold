//
//  ShortTimeoutSession.swift
//  TrueGold
//
//  Created by Tilo Delau on 2025-09-21.
//


import Foundation

enum ShortTimeoutSession {
    static let shared: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 10   // fail fast (default ~60s)
        cfg.timeoutIntervalForResource = 15
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: cfg)
    }()
}