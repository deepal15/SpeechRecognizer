//
//  ViewController.swift
//  SpeechRecognizer
//
//  Created by Deepal Patel on 04/11/18.
//  Copyright © 2018 Deepal Patel. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var btnRecord: UIButton!
    @IBOutlet weak var lblText: UILabel!
    
    //MARK: - UIView
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        progressView.setProgress(0, animated: false)
        btnRecord.addTarget(self, action: #selector(startRecording), for: .touchUpInside)
    }
    
    //MARK: = UIButton action
    
    @objc
    fileprivate func startRecording() -> Swift.Void {
        
        SpeechController.shared.startProcessRecording(delegate: self)
    }
}

extension ViewController: SpeechDelegate {
    
    func stopUserInteraction() {
        DispatchQueue.main.async { self.btnRecord.isEnabled = false }
    }
    
    func startUserInteraction() {
        DispatchQueue.main.async { self.btnRecord.isEnabled = true }
    }
    
    func processDidReceived(query: String) {
        DispatchQueue.main.async { self.lblText.text = query }
    }
    
    func processDidReceived(error: NSError) {
        DispatchQueue.main.async {
            if let customError = error.userInfo["error"] as? String {
                self.lblText.text = customError
            }
            else {
                self.lblText.text = error.localizedDescription
            }
        }
    }
    
    func processDidReceivedAudio(rate value: Float) {
        DispatchQueue.main.async { self.progressView.setProgress(value, animated: true) }
    }
}

