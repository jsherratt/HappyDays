//
//  MemoriesViewController.swift
//  HappyDays
//
//  Created by Joey on 23/01/2017.
//  Copyright © 2017 Joe Sherratt. All rights reserved.
//

import UIKit
import AVFoundation
import Photos
import Speech

class MemoriesViewController: UICollectionViewController {
    
    //MARK: Properties
    var memories = [URL]()
    

    //MARK: View
    override func viewDidLoad() {
        super.viewDidLoad()

        //Load the memories
        loadMemories()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        //Customise navigation bar
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addTapped))
        
        //Check permissions
        checkPermissions()

    }
    
    //MARK: Permission Check
    func checkPermissions() {
        
        //Check status for all three permissions
        let photosAuthorized = PHPhotoLibrary.authorizationStatus() == .authorized
        let recordingAuthorized = AVAudioSession.sharedInstance().recordPermission() == .granted
        let transcribeAuthorized = SFSpeechRecognizer.authorizationStatus() == .authorized
        
        //Make a single boolean out of all three
        let authorized = photosAuthorized && recordingAuthorized && transcribeAuthorized
        
        //If we're missing one, show the first run screen
        if authorized == false {
            if let vc = storyboard?.instantiateViewController(withIdentifier: "FirstRun") {
                navigationController?.present(vc, animated: true, completion: nil)
            }
        }
    }
    
    //MARK: Memories
    func getDocumentsDirectory() -> URL {
        
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        
        return documentsDirectory
    }
    
    func loadMemories() {
        
        memories.removeAll()
        
        //Attempt to load all the memoriesin out documents directory
        guard let files = try? FileManager.default.contentsOfDirectory(at: getDocumentsDirectory(), includingPropertiesForKeys: nil, options: []) else { return }
        
        //Loop over every file found
        for file in files {
            
            let filename = file.lastPathComponent
            
            //Check it ends with .thumb so we don't count each memory more than once
            if filename.hasSuffix(".thumb") {
                
                //Get the root name of the momory (i.e., without its path extension)
                let noExtension = filename.replacingOccurrences(of: ".thumb", with: "")
                
                //Create a full path from the memory
                let memoryPath = getDocumentsDirectory().appendingPathComponent(noExtension)
                
                //Add it the memory array
                memories.append(memoryPath)
                
            }
        }
        
        //Reload the list of memories
        collectionView?.reloadSections(IndexSet(integer: 1))
    }
    
    func saveNewMemory(image: UIImage) {
        
        //Create a unique name for this memory
        let memoryName = "memory-\(Date().timeIntervalSince1970)"
        
        //Use the unique name to create filenames for the full-sized image and the thumbnail
        let imageName = memoryName + ".jpg"
        let thumbnailName = imageName + ".thumb"
        
        do {
            
            //Create a URL where we can write the JPEG to
            let imagePath = getDocumentsDirectory().appendingPathComponent(imageName)
            
            //Conver the UIImage into a JPEG data object
            if let jpegData = UIImageJPEGRepresentation(image, 80) {
                
                //Write that data to the URL created
                try jpegData.write(to: imagePath, options: [.atomicWrite])
            }
            
            //Create thumbnail
            if let thumbnail = resize(image: image, to: 200) {
                
                let imagePath = getDocumentsDirectory().appendingPathComponent(thumbnailName)
                
                if let jpegData = UIImageJPEGRepresentation(thumbnail, 80) {
                    
                    try jpegData.write(to: imagePath, options: [.atomicWrite])
                }
            }
            
        }catch {
            print("Failed to save to disk")
        }
    }
    
    //MARK: Functions
    func addTapped() {
        
        let vc = UIImagePickerController()
        vc.modalPresentationStyle = .formSheet
        vc.delegate = self
        navigationController?.present(vc, animated: true, completion: nil)
    }
    
    func resize(image: UIImage, to width: CGFloat) -> UIImage? {
        
        //Calculate how much is needed to bring the width down to match our target size
        let scale = width / image.size.width
        
        //Bring the height down by the same amount so that the aspect ratio is preserved
        let height = image.size.height * scale
        
        //Create a new image context to draw into
        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), false, 0)
        
        //Draw the original image into the context
        image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        
        //Pull out the resized version
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        
        //End the context so UIKit can clean up
        UIGraphicsEndImageContext()
        
        //Send it back to the caller
        
        return newImage
    }

}

extension MemoriesViewController: UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        if let possibleImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            
            saveNewMemory(image: possibleImage)
            loadMemories()
        }
        
        dismiss(animated: true, completion: nil)
    }
}
























