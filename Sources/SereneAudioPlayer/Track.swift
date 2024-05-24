//
//  Track.swift
//  
//  Created by Amr Al-Refae on 2020-08-26.
//  Copyright © 2020 Amr Al-Refae. All rights reserved.
//

import Foundation

public struct Track {
    
    var image: String?
    var title: String?
    var subtitle: String?
    var recording: String?
    var streamURL: String?
    var animation: Animation
    var favourited: Bool?
    
    public struct Animation {
        let backgroundAnimationURL: String?
        let backgroundVolume: Int?
        
        public init(backgroundAnimationURL: String?, backgroundVolume: Int?) {
            self.backgroundAnimationURL = backgroundAnimationURL
            self.backgroundVolume = backgroundVolume
        }
    }
    
    public init(
        image: String?,
        title: String?,
        subtitle: String?,
        recording: String?,
        streamURL: String?,
        animation: Animation,
        favourited: Bool?
    ) {
        self.image = image
        self.title = title
        self.subtitle = subtitle
        self.recording = recording
        self.streamURL = streamURL
        self.animation = animation
        self.favourited = favourited
    }
}
