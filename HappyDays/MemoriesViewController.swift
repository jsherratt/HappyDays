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
import CoreSpotlight
import MobileCoreServices

class MemoriesViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout {
    
    //MARK: Properties
    var memories = [URL]()
    var activeMemory: URL!
    var audioRecorder: AVAudioRecorder?
    var recordingURL: URL!
    var audioPlayer: AVAudioPlayer?
    var filteredMemories = [URL]()
    var searchQuery: CSSearchQuery?
    

    //MARK: View
    override func viewDidLoad() {
        super.viewDidLoad()

        //Load the memories
        loadMemories()
        
        //Recording Url
        recordingURL = getDocumentsDirectory().appendingPathComponent("recording.m4a")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        //Customise navigation bar
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addTapped))
        
        //Check permissions
        checkPermissions()

    }
    
    //MARK: Collection View
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        
        return 2
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        if section == 0 {
            return 0
            
        }else {
            return memories.count
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Memory", for: indexPath) as! MemoryCell
        
        let memory = memories[indexPath.row]
        let imageName = thumbnailURL(for: memory).path
        let image = UIImage(contentsOfFile: imageName)
        cell.imageView.image = image
        
        if cell.gestureRecognizers == nil {
            
            let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(memoryLongPress))
            recognizer.minimumPressDuration = 0.25
            cell.addGestureRecognizer(recognizer)
            
            cell.layer.borderColor = UIColor.white.cgColor
            cell.layer.borderWidth = 3
            cell.layer.cornerRadius = 10
        }
        
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        let memory = memories[indexPath.row]
        let fm = FileManager.default
        
        do {
            
            let audioName = audioURL(for: memory)
            
            let transcriptionName = transcriptionURL(for: memory)
            
            if fm.fileExists(atPath: audioName.path) {
                
                audioPlayer = try AVAudioPlayer(contentsOf: audioName)
                audioPlayer?.play()
            }
            
            if fm.fileExists(atPath: transcriptionName.path) {
                
                let contents = try String(contentsOf: transcriptionName)
                print(contents)
            }
            
        }catch {
            print("Error loading audio")
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        
        return collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "Header", for: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        
        if section == 1 {
            return CGSize.zero
            
        }else {
            return CGSize(width: 0, height: 50)
        }
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
    
    //MARK: Recording
    func memoryLongPress(sender: UILongPressGestureRecognizer) {
        
        if sender.state == .began {
            
            let cell = sender.view as! MemoryCell
            
            if let index = collectionView?.indexPath(for: cell) {
                activeMemory = memories[index.row]
                recordMemory()
            }
            
        }else if sender.state == .ended {
            finishRecording(success: true)
        }
    }
    
    func recordMemory() {
        
        audioPlayer?.stop()
        
        collectionView?.backgroundColor = UIColor(red: 0.5, green: 0, blue: 0, alpha: 1)
        
        let recordingSession = AVAudioSession.sharedInstance()
        
        do {
            
            //Configure the session for recording and playback through the speaker
            try recordingSession.setCategory(AVAudioSessionCategoryPlayAndRecord, with: .defaultToSpeaker)
            
            try recordingSession.setActive(true)
            
            //Set up high quality audio recording session
            let settings = [AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 44100, AVNumberOfChannelsKey: 2, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue]
            
            //Create the audio recording, and assign ourselves as the delegate
            audioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            
        }catch let error {
            //Failed to record
            print("Failed to record: \(error)")
            finishRecording(success: false)
        }
    }
    
    func finishRecording(success: Bool) {
        
        collectionView?.backgroundColor = UIColor.darkGray
        
        audioRecorder?.stop()
        
        if success {
            
            do {
                
                let memoryAudioURL = activeMemory.appendingPathExtension("m4a")
                let fm = FileManager.default
                
                if fm.fileExists(atPath: memoryAudioURL.path) {
                    try fm.removeItem(at: memoryAudioURL)
                }
                
                try fm.moveItem(at: recordingURL, to: memoryAudioURL)
                
                transcribeAudio(memory: activeMemory)
                
            }catch let error {
                print("Failure finishing recording: \(error)")
            }
        }
    }
    
    func transcribeAudio(memory: URL) {
        
        //Get paths to where the audio is, and where the transcription should be
        let audio = audioURL(for: memory)
        let transcription = transcriptionURL(for: memory)
        
        //Create a new recognizer and point it at our audio
        let recognizer = SFSpeechRecognizer()
        let reqest = SFSpeechURLRecognitionRequest(url: audio)
        
        //Start recognition
        recognizer?.recognitionTask(with: reqest) { [unowned self] (result, error) in
            
            //Abort if we didn't get any transcription back
            guard let result = result else { print("There was an error: \(error)"); return }
            
            //If we got the final transcription back, we need to write it to disk
            if result.isFinal {
                
                //Pull out the best transcription
                let text = result.bestTranscription.formattedString
                
                //Write it to disk at the correct filename for this memory
                
                do {
                    
                    try text.write(to: transcription, atomically: true, encoding: String.Encoding.utf8)
                    
                    self.indexMemory(memory: memory, text: text)
                    
                }catch {
                    print("Failed to save transcription")
                }
            }
        }
    }
    
    //MARK: Spotlight
    func indexMemory(memory: URL, text: String) {
        
        //Create a basic attribute set
        let attributeSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeText as String)
        
        attributeSet.title = "Happy Days Memory"
        attributeSet.contentDescription = text
        attributeSet.thumbnailURL = thumbnailURL(for: memory)
        
        //Wrap it in a searchable item, using the memory's full path as its unique identifier
        let item = CSSearchableItem(uniqueIdentifier: memory.path, domainIdentifier: "com.jsherratt", attributeSet: attributeSet)
        
        //Make it never expire
        item.expirationDate = Date.distantFuture
        
        //Ask spotlight to index the item
        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            
            if let error = error {
                print("Indexing error: \(error.localizedDescription)")
                
            }else {
                print("Search item successfully indexed: \(text)")
            }
        }
        
    }
    
    //MARK: Search bar
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        
        filterMemories(text: searchText)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        
        searchBar.resignFirstResponder()
        
    }
    
    func filterMemories(text: String) {
        
        guard text.characters.count > 0 else {
            
            filteredMemories = memories
            
            UIView.performWithoutAnimation {
                collectionView?.reloadSections(IndexSet(integer: 1))
            }
            return
        }
        
        var allItems = [CSSearchableItem]()
        searchQuery?.cancel()
        
        let queryString = "contentDescription == \"*\(text)*\"c"
        
        searchQuery = CSSearchQuery(queryString: queryString, attributes: nil)
        
        searchQuery?.foundItemsHandler = { items in
            allItems.append(contentsOf: items)
        }
        
        searchQuery?.completionHandler = { error in
            
            DispatchQueue.main.async { [unowned self] in
                self.activateFilter(matches: allItems)
            }
        }
        searchQuery?.start()
    }
    
    func activateFilter(matches: [CSSearchableItem]) {
        
        filteredMemories = matches.map { item in
            return URL(fileURLWithPath: item.uniqueIdentifier)
        }
        
        UIView.performWithoutAnimation {
            collectionView?.reloadSections(IndexSet(integer: 1))
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
        
        filteredMemories = memories
        
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
    
    //URL methods
    func imageURL(for memory: URL) -> URL {
        return memory.appendingPathExtension("jpg")
    }
    
    func thumbnailURL(for memory: URL) -> URL {
        return memory.appendingPathExtension("thumb")
    }
    
    func audioURL(for memory: URL) -> URL {
        return memory.appendingPathExtension("m4a")
    }
    
    func transcriptionURL(for memory: URL) -> URL {
        return memory.appendingPathExtension("txt")
    }

}

//MARK: Extension
extension MemoriesViewController: UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        if let possibleImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            
            saveNewMemory(image: possibleImage)
            loadMemories()
        }
        
        dismiss(animated: true, completion: nil)
    }
}

extension MemoriesViewController: AVAudioRecorderDelegate {
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        
        if !flag {
            finishRecording(success: false)
        }
    }
}
























