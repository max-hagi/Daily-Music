//
//  SupabaseService.swift
//  Daily Music
//
//  One shared Supabase client for the whole app. Every live service (entries,
//  auth, favorites) talks to the database through this single connection.
//
//  Requires the `supabase-swift` Swift Package — add it in Xcode before building
//  (File → Add Package Dependencies → https://github.com/supabase/supabase-swift).
//

import Foundation
import Supabase

enum Supa {
    static let client = SupabaseClient(
        supabaseURL: SupabaseConfig.url,
        supabaseKey: SupabaseConfig.anonKey
    )
}
