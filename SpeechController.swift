//
//  ViewController.swift
//  SpeechRecognizer
//
//  Created by Deepal Patel on 04/11/18.
//  Copyright © 2018 Deepal Patel. All rights reserved.
//


import Speech


@objc
public protocol SpeechDelegate {
    
    /// implement this method to stop UI. Takes couples of micoseconds to clear the buffer of AVAudioEngine
    func stopUserInteraction()
    
    
    /// implement this method to start UI again after the buffer is cleared. and ready make another request.
    func startUserInteraction()
    
    /// Returns the string value from Apple's server
    ///
    /// - Parameter query: result
    func processDidReceived(query: String)
    
    /// Returns error if any during recording process.
    ///
    /// - Parameter error: error
    func processDidReceived(error: NSError)
    
    /// Returns the value so that user can update UI
    ///
    /// - Parameter value: rate at which device receives the voice
    func processDidReceivedAudio(rate value: Float)
}


public class SpeechController: NSObject {
    
    //MARK: - Speech init
    fileprivate var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    
    fileprivate var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    
    fileprivate var recognitionTask: SFSpeechRecognitionTask?
    
    fileprivate var audioEngine =  AVAudioEngine()
    
    @objc public static let shared = SpeechController()
    
    public var delegate: SpeechDelegate!
    
    fileprivate typealias completionHandler = ((Bool) -> ())
    
    fileprivate var pendingRequest: DispatchWorkItem?
    
    //MARK: - Check permission
    
    fileprivate func receivedPermission(handler: @escaping completionHandler) {
        
        SFSpeechRecognizer.requestAuthorization { authStatus in
            
            OperationQueue.main.addOperation {
                
                switch authStatus {
                case .authorized:
                    handler(true)
                case .denied:
                    handler(false)
                case .restricted:
                    handler(false)
                case .notDetermined:
                    handler(false)
                }
            }
        }
    }
    
    //MARK: - Audio processing
    
    @objc
    internal func startProcessRecording(delegate: SpeechDelegate) -> () {
        
        self.delegate = delegate
        
        self.receivedPermission { (value) in
            
            if value {
                if self.audioEngine.isRunning {
                    self.audioEngine.stop()
                    self.recognitionRequest?.endAudio()
                    self.delegate.stopUserInteraction()
                }
                else {
                    try! self.initiateRecording(delegate: delegate)
                }
            }
            else {
                let error = NSError.init(domain: "com.sample.one", code: 0, userInfo: ["error" : "Please check permission"])
                self.delegate.processDidReceived(error: error)
            }
        }
    }
    
    
    
    func initiateRecording(delegate: SpeechDelegate) throws {
        
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .spokenAudio, options: .duckOthers)
        try audioSession.setMode(AVAudioSession.Mode.measurement)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let inputNode = audioEngine.inputNode
        let recognitionRequest = self.recognitionRequest
        
        recognitionRequest?.shouldReportPartialResults = false
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest!) { (result, error) in
            
            var isFinal = false
            if let errr = error {
                self.delegate.processDidReceived(error: errr as NSError)
            }
            
            if let result = result {
                let query = result.bestTranscription.formattedString
                isFinal = result.isFinal
                
                self.delegate.processDidReceivedAudio(rate: Float(0))
                self.delegate.processDidReceived(query: query)
            }
            
            if error != nil || isFinal {
                
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
                self.delegate.startUserInteraction()
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.removeTap(onBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            
            guard let data = buffer.floatChannelData else { return }
            
            let channelDataValue = data.pointee
            
            let channelDataValueArray = stride(from: 0,
                                               to: Int(buffer.frameLength),
                                               by: buffer.stride).map{ channelDataValue[$0] }
            
            if let max = channelDataValueArray.max() {
                
                // At particular range the value should be discarded
                
                if max > 0.0100000000 {
                    
                    if let requestVoice = self.pendingRequest {
                        if !requestVoice.isCancelled {
                            requestVoice.cancel()
                        }
                    }
                    self.delegate.processDidReceivedAudio(rate: (max * 200) / 10)
                    self.recognitionRequest?.append(buffer)
                }
                else {
                    
                    let requestItem = DispatchWorkItem(block: { [weak self] in
                        
                        if let `self` = self {
                            
                            if !self.pendingRequest!.isCancelled {
                                
                                if self.audioEngine.isRunning {
                                    
                                    self.audioEngine.stop()
                                    self.recognitionRequest?.endAudio()
                                }
                            }
                        }
                    })
                    
                    self.delegate.processDidReceivedAudio(rate: (max * 200) / 10)
                    self.pendingRequest = requestItem
                    
                    
                    /* Sometimes user speaks some words. e.g. "Hello world"
                     * Theres space of sometime in between, during that time, request will
                     * be called.
                     * for that we have to stop it. There's cancel method below.
                     */
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() +  4.0, execute: requestItem)
                }
            }
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    }
    
}
