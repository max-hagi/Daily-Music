//
//  DailyMusicWidgetBundle.swift
//  DailyMusicWidget
//
//  The widget extension's entry point. One bundle, one widget (for now):
//  today's drop on the Home/Lock Screen — the cheapest daily re-engagement
//  surface on iOS for a one-song-a-day app.
//

import SwiftUI
import WidgetKit

@main
struct DailyMusicWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayDropWidget()
    }
}
