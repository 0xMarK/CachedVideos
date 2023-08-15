//
//  ViewController.swift
//  CachedVideos
//
//  Created by Anton Kaliuzhnyi on 15.08.2023.
//

import UIKit
import AVFoundation
import AVKit

class ViewController: UIViewController {
    
    @IBAction func video1Button(_ sender: UIButton) {
        let url = URL(string: "https://sample-videos.com/video123/mp4/720/big_buck_bunny_720p_1mb.mp4")!
        presentVideoViewController(url)
    }
    
    @IBAction func video2Button(_ sender: UIButton) {
        let url = URL(string: "https://sample-videos.com/video123/mp4/720/big_buck_bunny_720p_2mb.mp4")!
        presentVideoViewController(url)
    }
    
    @IBAction func video5Button(_ sender: Any) {
        let url = URL(string: "https://sample-videos.com/video123/mp4/720/big_buck_bunny_720p_5mb.mp4")!
        presentVideoViewController(url)
    }
    
    @IBAction func video10Button(_ sender: Any) {
        let url = URL(string: "https://sample-videos.com/video123/mp4/720/big_buck_bunny_720p_10mb.mp4")!
        presentVideoViewController(url)
    }
    
    @IBAction func video20Button(_ sender: Any) {
        let url = URL(string: "https://sample-videos.com/video123/mp4/720/big_buck_bunny_720p_20mb.mp4")!
        presentVideoViewController(url)
    }
    
    @IBAction func video30Button(_ sender: Any) {
        let url = URL(string: "https://sample-videos.com/video123/mp4/720/big_buck_bunny_720p_30mb.mp4")!
        presentVideoViewController(url)
    }
    
    private func presentVideoViewController(_ url: URL) {
        let asset = VideoManager.shared.asset(for: url)
        let playerItem = AVPlayerItem(asset: asset)
        
        let player = AVPlayer(playerItem: playerItem)
        player.automaticallyWaitsToMinimizeStalling = false
        
        let controller = AVPlayerViewController()
        controller.player = player
        
        present(controller, animated: true) {
            player.play()
        }
    }
    
}
