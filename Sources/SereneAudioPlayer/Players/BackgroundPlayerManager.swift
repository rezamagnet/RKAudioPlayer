//
//  BackgroundPlayerManager.swift
//  SereneAudioPlayer
//
//  Created by Fatemeh Najafi Moghadam on 9/21/24.
//

import Foundation
import AVFoundation

class BackgroundPlayerManager {
    private var track: Track
    
    private var looperPlayer: AVPlayerLooper?
    private var noiseLooperPlayer: AVPlayerLooper?
    private var backgroundPlayer: AVPlayer?
    private(set) var noisePlayer: AVPlayer?

    init(track: Track, onSetup: @escaping (AVPlayer?, AVPlayer?) -> Void) {
        self.track = track
        setupBackgroundVideo()
        onSetup(backgroundPlayer, noisePlayer)
    }
    
    func seekToZero() {
        noisePlayer?.seek(to: .zero)
        backgroundPlayer?.seek(to: .zero)
    }
    
    func play() {
        backgroundPlayer?.play()
        noisePlayer?.play()
    }
    
    func pause() {
        backgroundPlayer?.pause()
        noisePlayer?.pause()
    }
    
    func destroy() {
        looperPlayer = nil
        noiseLooperPlayer = nil
        backgroundPlayer = nil
        noisePlayer = nil
    }
    
    var backgroundVideo: (url: URL, volume: Float)? {
        if let backgroundAnimationURL = track.animation.backgroundAnimationURL,
           let encodedAnimationString = backgroundAnimationURL.removingPercentEncoding?.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed),
           let animationURL = URL(string: encodedAnimationString) {
            let volume = Float(track.animation.backgroundVolume ?? 0) / 100
            
            return (animationURL, volume)
            
        } else {
            return nil
        }
    }
    
    private func setupBackgroundVideo() {
        if let backgroundVideo {
            let asset = AVURLAsset(url: backgroundVideo.url)
            let playerItem = AVPlayerItem(asset: asset)
            let queuePlayer = AVQueuePlayer(playerItem: playerItem)
            looperPlayer = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
            backgroundPlayer = queuePlayer
            backgroundPlayer?.isMuted = true
            
            let noiseFile = Bundle.module.url(forResource: "Final Noise Track 20 min", withExtension: "mp3")!
            let noiseAsset = AVURLAsset(url: noiseFile)
            let noisePlayerItem = AVPlayerItem(asset: noiseAsset)
            let noiseQueuePlayer = AVQueuePlayer(playerItem: noisePlayerItem)
            noiseLooperPlayer = AVPlayerLooper(player: noiseQueuePlayer, templateItem: noisePlayerItem)
            
            noisePlayer = noiseQueuePlayer
            noisePlayer?.volume = backgroundVideo.volume
        }
    }
}
