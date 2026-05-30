//
//  LoadState.swift
//  Daily Music
//
//  A small generic enum every screen uses to describe async content.
//  Making "empty" a first-class case (not nil) forces the UI to handle
//  "no song today yet" deliberately instead of by accident.
//

import Foundation

enum LoadState<Value> {
    case loading
    case loaded(Value)
    case empty
    case failed(Error)
}
