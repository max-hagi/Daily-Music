//
//  StatsCopy.swift
//  Daily Music
//

import Foundation

func featuredLineString(likes: Int, total: Int, likeRate: Double) -> String {
    let qualifier: String
    switch likeRate {
    case 0.6...: qualifier = "You're basically a fan."
    case 0.4...: qualifier = "About half make the cut."
    default:     qualifier = "Not really your thing."
    }
    return "\(likes) of \(total) kept. \(qualifier)"
}
