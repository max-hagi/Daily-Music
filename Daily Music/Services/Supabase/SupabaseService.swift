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
import Supabase   // the supabase-swift package

// Namespace enum holding ONE shared SupabaseClient for the whole app. `static let`
// makes it a lazily-created singleton: the client (which manages the auth session,
// network stack, etc.) is built once on first access and reused everywhere via
// `Supa.client`. Every live service grabs this same instance.
enum Supa {
    static let client = SupabaseClient(
        supabaseURL: SupabaseConfig.url,
        supabaseKey: SupabaseConfig.anonKey
    )
}
