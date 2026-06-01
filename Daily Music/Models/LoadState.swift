//
//  LoadState.swift
//  Daily Music
//
//  A small generic enum every screen uses to describe async content.
//  Making "empty" a first-class case (not nil) forces the UI to handle
//  "no song today yet" deliberately instead of by accident.
//

import Foundation

// A GENERIC enum: `<Value>` is a type placeholder, so the same enum works for any
// payload — LoadState<DailyEntry>, LoadState<[Favorite]>, etc. Swift's enums can
// carry associated values (the `(Value)` and `(Error)` below), which makes them
// perfect for modeling "exactly one of these mutually-exclusive states, and the
// data that goes with it." A view then `switch`es over it to decide what to draw.
enum LoadState<Value> {
    case loading            // request in flight — show a spinner
    case loaded(Value)      // success — carries the value to display
    case empty              // request succeeded but there's nothing (e.g. no song today)
    case failed(Error)      // request threw — carries the error to surface
}
