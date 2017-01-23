//
//  ViewController.swift
//  HappyDays
//
//  Created by Joey on 23/01/2017.
//  Copyright © 2017 Joe Sherratt. All rights reserved.
//

import UIKit
import AVFoundation
import Photos
import Speech

class ViewController: UIViewController {
    
    //MARK: Outlets
    @IBOutlet weak var helpLabel: UILabel!
    
    
    //MARK: View
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    //MARK: Button Action
    @IBAction func requestPermissions(_ sender: UIButton) {
        
        requestPhotosPermission()
    }
    
    //MARK: Photos Auth
    func requestPhotosPermission() {
        
        PHPhotoLibrary.requestAuthorization { [unowned self] authStaus in
            
            DispatchQueue.main.async {
                
                if authStaus == .authorized {
                    self.requestRecordPermissions()
                    
                }else {
                    self.helpLabel.text = "Photos permisison was declined; please enable it in settings then tap Continue again."
                }
            }
        }
    }
    
    //MARK: Record Auth
    func requestRecordPermissions() {
        
        AVAudioSession.sharedInstance().requestRecordPermission() { [unowned self] allowed in
            
            DispatchQueue.main.async {
                
                if allowed {
                    self.requestTranscribePermissions()
                    
                }else {
                    self.helpLabel.text = "Recording permission was declined; please enable it in settings then tap Continue again."
                }
            }
        }
    }
    
    //MARK: Transcribe Auth
    func requestTranscribePermissions() {
        
        SFSpeechRecognizer.requestAuthorization { [unowned self] authStatus in
            
            DispatchQueue.main.async {
                
                if authStatus == .authorized {
                    self.authorizationComplete()
                    
                }else {
                    self.helpLabel.text = "Transcription permission was declined; please enable it in settings then tap Continue again."
                }
            }
        }
    }
    
    func authorizationComplete() {
        dismiss(animated: true, completion: nil)
    }

}

