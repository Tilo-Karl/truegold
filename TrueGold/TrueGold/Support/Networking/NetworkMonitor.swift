//
//  NetworkMonitor.swift
//  TrueGold
//
//  Created by Tilo Delau on 2025-09-21.
//


import Network
import Foundation

final class NetworkMonitor {
    static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "net.monitor")

    private(set) var isOnline: Bool = true

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.isOnline = (path.status == .satisfied)
        }
        monitor.start(queue: queue)
    }
}