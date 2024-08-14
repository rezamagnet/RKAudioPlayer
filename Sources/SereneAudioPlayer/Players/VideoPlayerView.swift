//
//  VideoPlayerView.swift
//
//
//  Created by Fatemeh Najafi Moghadam on 8/15/24.
//

import SwiftUI
import AVKit

struct VideoPlayerView: UIViewControllerRepresentable {
    
    @Binding var player: AVPlayer?
    let onPlaying: () -> Void
    
    func makeUIViewController(context: Context) -> VideoPlayerViewController {
        let vc = VideoPlayerViewController()
        vc.player = player
        vc.updatesNowPlayingInfoCenter = false
        vc.allowsPictureInPicturePlayback = false
        vc.onPlaying = onPlaying
        return vc
    }
    
    func updateUIViewController(_ uiViewController: VideoPlayerViewController, context: Context) {
    }
    
    typealias UIViewControllerType = VideoPlayerViewController
    
}

class VideoPlayerViewController: AVPlayerViewController {
    
    private var backgroundPlayerItemBufferKeepUpObserver: NSKeyValueObservation?
    private var backgroundPlayerItemBufferFullObserver: NSKeyValueObservation?
    
    var onPlaying: () -> Void = { }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification, object: player?.currentItem, queue: .main) { [weak self] _ in
            self?.player?.seek(to: .zero)
            self?.player?.play()
        }
        
        backgroundPlayerItemBufferKeepUpObserver = player?.currentItem?.observe(\AVPlayerItem.isPlaybackLikelyToKeepUp, options: [.new]) { [weak self] _,_  in
            self?.onPlaying()
            self?.player?.playImmediately(atRate: 1)
        }
        
        backgroundPlayerItemBufferFullObserver = player?.currentItem?.observe(\AVPlayerItem.isPlaybackBufferFull, options: [.new]) { [weak self] _,_  in
            self?.onPlaying()
        }
    }
}
