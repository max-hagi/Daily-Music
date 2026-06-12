//
//  MusicServiceConnection.swift
//  Daily Music
//
//  The "connected services" shape: what a linked streaming account can do for
//  us. AppleMusicSession is the only implementation today; a future
//  SpotifySession would report just .librarySave (Spotify offers no
//  third-party in-app playback).
//

import Foundation

struct MusicServiceCapabilities: OptionSet, Equatable {
    let rawValue: Int

    /// Full songs in-app (Apple Music: requires an active subscription).
    static let fullPlayback = MusicServiceCapabilities(rawValue: 1 << 0)
    /// Save tracks to the user's library / our playlist (also subscription-gated).
    static let librarySave  = MusicServiceCapabilities(rawValue: 1 << 1)
    /// Editorial notes, hi-res artwork, and other catalog extras.
    static let richMetadata = MusicServiceCapabilities(rawValue: 1 << 2)
}

enum MusicConnectionStatus: Equatable {
    case notConnected
    case connected(MusicServiceCapabilities)

    /// Convenience so call sites read `status.capabilities.contains(.x)`.
    var capabilities: MusicServiceCapabilities {
        if case .connected(let caps) = self { return caps }
        return []
    }
}

@MainActor
protocol MusicServiceConnection: AnyObject {
    var service: StreamingService { get }
    var status: MusicConnectionStatus { get }
    func connect() async
    func disconnect()
    /// Save a track to this service's library presence for the app (the
    /// private "Daily Music" playlist). Only meaningful when capabilities
    /// contain .librarySave — callers gate on that.
    func saveToLibrary(_ entry: DailyEntry) async throws
}
