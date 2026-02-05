//  ViewController.swift
//  PocketVib_Collector

import UIKit
import AVFoundation
import Photos
import Foundation
import CoreImage
import SwiftUI
import PhotosUI

class ViewController: UIViewController, AVCaptureFileOutputRecordingDelegate, AVCapturePhotoCaptureDelegate {
    
    // MARK: - UI Components
    private let telePhotoUIView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        return view
    }()
    
    private let isoSlider_TelePhoto: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 1
        return slider
    }()
    private let isoLabel_TelePhoto: UILabel = {
        let label = UILabel()
        guard let device = AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back) else {
            label.text = "TelePhotoISO: --"
            return label
        }
        label.text = String(format: "TelePhotoISO: %.0f", device.iso)
        label.textColor = .white
        label.textAlignment = .right
        return label
    }()
    
    private let exposureSlider_TelePhoto: UISlider = {
        let slider = UISlider()
        slider.minimumValue = -8
        slider.maximumValue = 8
        return slider
    }()
    
    private let exposureLabel_TelePhoto: UILabel = {
        let label = UILabel()
        guard let device = AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back) else {
            label.text = "TelePhotoExp: --"
            return label
        }
        let duration = CMTimeGetSeconds(device.exposureDuration)
        label.text = String(format: "TelePhotoExp: 1/%.1f", 1/duration)
        label.textColor = .white
        label.textAlignment = .right
        return label
    }()
    private let focusSlider_Telephoto: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 1
        return slider
    }()
    
    private let focusLabel_Telephoto: UILabel = {
        let label = UILabel()
        guard let device = AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back) else {
            label.text = "TelePhotoFocus: --"
            return label
        }
        label.text = String(format: "TelePhotoFocus: %.1f", device.lensPosition)
        label.textColor = .white
        label.textAlignment = .right
        return label
    }()
    
    private let recordButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Record", for: .normal)
        button.setTitle("Stop", for: .selected)
        button.backgroundColor = .white
        button.setTitleColor(.red, for: .normal)
        button.layer.cornerRadius = 25
        button.layer.masksToBounds = true
        return button
    }()
    private let captureButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Capture", for: .normal)
        button.backgroundColor = .white
        button.setTitleColor(.blue, for: .normal)
        button.layer.cornerRadius = 25
        button.layer.masksToBounds = true
        return button
    }()
    
    private let startButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Restart", for: .normal)
        button.backgroundColor = .white
        button.setTitleColor(.blue, for: .normal)
        button.layer.cornerRadius = 25
        button.layer.masksToBounds = true
        return button
    }()
    
    private var videoRecordingStartTime: Date?
    private var recordingTimer: Timer?
    private let recordingTimeLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.text = "00:00"
        label.textAlignment = .center
        label.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        return label
    }()
    // MARK: - Camera Properties
    private var session: AVCaptureMultiCamSession!
    enum Devices {
        case telePhoto
        case lidar
    }
    private var maxDevicesCount: Int = 0
    private var selectedDevices: Set<Devices> = []
    
    
    private var telePhotoPreviewLayer: AVCaptureVideoPreviewLayer!
    private var telePhotoDevice: AVCaptureDevice!
    private var telePhotoInput: AVCaptureDeviceInput!
    private var telePhotoPort: AVCaptureDeviceInput.Port!
    private var telePhotoOutput: AVCaptureMovieFileOutput!
    private var telePhotoVideoConnection: AVCaptureConnection!
    private var telePhotoLayerConnection: AVCaptureConnection!
    private var telePhotoBackgroundTaskID: UIBackgroundTaskIdentifier?
    
    private var lidarDevice: AVCaptureDevice!
    private var lidarInput: AVCaptureDeviceInput!
    private var lidarDepthPort: AVCaptureDeviceInput.Port!
    private var lidarDepthOutput: AVCaptureDepthDataOutput!
    private var lidarDepthVideoConnection: AVCaptureConnection!
    
    private var telePhotoPhotoOutput: AVCapturePhotoOutput!
    private var telePhotoPhotoConnection: AVCaptureConnection!
    
    private var isRecording: Bool = false
    
    // MARK: - Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.session = AVCaptureMultiCamSession()
        
        guard AVCaptureMultiCamSession.isMultiCamSupported else {
            print("MultiCamera Fail!")
            return
        }
        self.maxDevicesCount = self.detectSupportedDeviceCount()
        self.selectedDevices = self.selectDevices()
        
        setupUI()
        checkPermissions()
        
    }
    
    private func detectSupportedDeviceCount() -> Int {
        let discoverySession = AVCaptureDevice.DiscoverySession.init(deviceTypes: [
            AVCaptureDevice.DeviceType.builtInTelephotoCamera,
            AVCaptureDevice.DeviceType.builtInLiDARDepthCamera
        ], mediaType: AVMediaType.video, position: AVCaptureDevice.Position.unspecified)
        
        let deviceSets = discoverySession.supportedMultiCamDeviceSets
        
        var maxDevicesCount = 0
        for deviceSet in deviceSets {
            if deviceSet.count > maxDevicesCount {
                maxDevicesCount = deviceSet.count
            }
        }
        
        return maxDevicesCount
    }
    
    private func selectDevices() -> Set<Devices> {
        switch maxDevicesCount {
        case 0:
            print("No Available Devices")
            return []
        case 1:
            return [Devices.telePhoto]
        case 2:
            return [Devices.telePhoto, Devices.lidar]
        case 3:
            return [Devices.telePhoto, Devices.lidar]
        default:
            print("No Support Devices")
            return []
        }
    }
    private func setupUI() {
        view.backgroundColor = .black
        
        view.addSubview(telePhotoUIView)
        view.addSubview(recordButton)
        view.addSubview(startButton)
        view.addSubview(recordingTimeLabel)
        view.addSubview(exposureLabel_TelePhoto)
        view.addSubview(isoLabel_TelePhoto)
        view.addSubview(focusLabel_Telephoto)
        
        
        let exposureButton1_2000 = UIButton(type: .system)
        exposureButton1_2000.setTitle("1/2000", for: .normal)
        exposureButton1_2000.backgroundColor = .white
        exposureButton1_2000.setTitleColor(.black, for: .normal)
        exposureButton1_2000.addTarget(self, action: #selector(setExposure_1_2000), for: .touchUpInside)
        view.addSubview(exposureButton1_2000)
        
        let exposureButton1_30 = UIButton(type: .system)
        exposureButton1_30.setTitle("1/30", for: .normal)
        exposureButton1_30.backgroundColor = .white
        exposureButton1_30.setTitleColor(.black, for: .normal)
        exposureButton1_30.addTarget(self, action: #selector(setExposure_1_30), for: .touchUpInside)
        view.addSubview(exposureButton1_30)
        
        let isoMinButton = UIButton(type: .system)
        isoMinButton.setTitle("ISO Min", for: .normal)
        isoMinButton.backgroundColor = .white
        isoMinButton.setTitleColor(.black, for: .normal)
        isoMinButton.addTarget(self, action: #selector(setISOMin), for: .touchUpInside)
        view.addSubview(isoMinButton)
        
        let isoMaxButton = UIButton(type: .system)
        isoMaxButton.setTitle("ISO Max", for: .normal)
        isoMaxButton.backgroundColor = .white
        isoMaxButton.setTitleColor(.black, for: .normal)
        isoMaxButton.addTarget(self, action: #selector(setISOMax), for: .touchUpInside)
        view.addSubview(isoMaxButton)
        
        let focusButton0 = UIButton(type: .system)
        focusButton0.setTitle("Focus 0.0", for: .normal)
        focusButton0.backgroundColor = .white
        focusButton0.setTitleColor(.black, for: .normal)
        focusButton0.addTarget(self, action: #selector(setFocus_0), for: .touchUpInside)
        view.addSubview(focusButton0)
        
        let focusButton1 = UIButton(type: .system)
        focusButton1.setTitle("Focus 1.0", for: .normal)
        focusButton1.backgroundColor = .white
        focusButton1.setTitleColor(.black, for: .normal)
        focusButton1.addTarget(self, action: #selector(setFocus_1), for: .touchUpInside)
        view.addSubview(focusButton1)
        
        let padding: CGFloat = 20
        let buttonWidth: CGFloat = 120
        let buttonHeight: CGFloat = 40
        let spacing: CGFloat = 20
        let previewHeight = view.bounds.height * 2 / 3 - padding * 6
        
        telePhotoUIView.frame = CGRect(x: padding, y: padding * 2, width: view.bounds.width - padding * 2, height: previewHeight)
        
        let buttonSize: CGFloat = 50
        recordButton.frame = CGRect(x: view.bounds.width / 3 - buttonSize*0.75, y: previewHeight + 2*padding, width: buttonSize*1.5, height: buttonSize)
        startButton.frame = CGRect(x: view.bounds.width * 2 / 3 - buttonSize*0.75, y: previewHeight + 2*padding, width: buttonSize*1.5, height: buttonSize)
        recordingTimeLabel.frame = CGRect(x: (view.bounds.width - 100) / 2, y: recordButton.frame.minY - 30, width: 100, height: 30)
        recordButton.addTarget(self, action: #selector(recordButtonTapped), for: .touchUpInside)
        startButton.addTarget(self, action: #selector(startStreaming), for: .touchUpInside)
        
        exposureLabel_TelePhoto.frame = CGRect(x: padding, y: previewHeight + padding * 5, width: view.bounds.width - padding * 2, height: buttonHeight)
        exposureLabel_TelePhoto.text = "Exposure Time"
        exposureLabel_TelePhoto.textAlignment = .left
        
        exposureButton1_2000.frame = CGRect(x: view.bounds.width/2 - spacing/2 - buttonWidth, y: previewHeight + padding * 5 + buttonHeight, width: buttonWidth, height: buttonHeight)
        exposureButton1_30.frame = CGRect(x: view.bounds.width/2 + spacing/2, y: previewHeight + padding * 5 + buttonHeight, width: buttonWidth, height: buttonHeight)
        
        isoLabel_TelePhoto.frame = CGRect(x: padding, y: exposureButton1_2000.frame.maxY, width: view.bounds.width - padding * 2, height: buttonHeight)
        isoLabel_TelePhoto.text = "ISO"
        isoLabel_TelePhoto.textAlignment = .left
        
        isoMinButton.frame = CGRect(x: view.bounds.width/2 - spacing/2 - buttonWidth, y: isoLabel_TelePhoto.frame.maxY, width: buttonWidth, height: buttonHeight)
        isoMaxButton.frame = CGRect(x: view.bounds.width/2 + spacing/2, y: isoLabel_TelePhoto.frame.maxY, width: buttonWidth, height: buttonHeight)
        
        focusLabel_Telephoto.frame = CGRect(x: padding, y: isoMinButton.frame.maxY, width: view.bounds.width - padding * 2, height: buttonHeight)
        focusLabel_Telephoto.text = "Focus"
        focusLabel_Telephoto.textAlignment = .left
        
        focusButton0.frame = CGRect(x: view.bounds.width/2 - spacing/2 - buttonWidth,y: focusLabel_Telephoto.frame.maxY, width: buttonWidth, height: buttonHeight)
        focusButton1.frame = CGRect(x: view.bounds.width/2 + spacing/2, y: focusLabel_Telephoto.frame.maxY, width: buttonWidth, height: buttonHeight)
        
    }
    
    // MARK: - Button Processing
    @objc private func setExposure_1_2000() {
        setExposureTime(1.0 / 2000.0)
    }
    
    @objc private func setExposure_1_30() {
        setExposureTime(1.0 / 30.0)
    }
    
    @objc private func setISOMin() {
        setISO(telePhotoDevice?.activeFormat.minISO ?? 100)
    }
    
    @objc private func setISOMax() {
        setISO(telePhotoDevice?.activeFormat.maxISO ?? 1600)
    }
    
    @objc private func setFocus_0() {
        setFocus(0.0)
    }
    
    @objc private func setFocus_1() {
        setFocus(1.0)
    }
    
    private func setExposureTime(_ durationSeconds: Double) {
        guard let device = telePhotoDevice else { return }
        do {
            try device.lockForConfiguration()
            let newDuration = CMTimeMakeWithSeconds(durationSeconds, preferredTimescale: 1000000000)
            device.setExposureModeCustom(duration: newDuration, iso: device.iso)
            device.unlockForConfiguration()
            exposureLabel_TelePhoto.text = String(format: "Exposure Time: 1/%.0f", 1 / durationSeconds)
        } catch {
            print("Failed to set exposure time")
        }
    }
    
    private func setISO(_ iso: Float) {
        guard let device = telePhotoDevice else { return }
        do {
            try device.lockForConfiguration()
            device.setExposureModeCustom(duration: device.exposureDuration, iso: iso)
            device.unlockForConfiguration()
            isoLabel_TelePhoto.text = String(format: "ISO: %.0f", iso)
        } catch {
            print("Failed to set ISO")
        }
    }
    
    private func setFocus(_ focus: Float) {
        guard let device = telePhotoDevice else { return }
        do {
            try device.lockForConfiguration()
            device.setFocusModeLocked(lensPosition: focus, completionHandler: nil)
            device.unlockForConfiguration()
            focusLabel_Telephoto.text = String(format: "Focus: %.1f", focus)
        } catch {
            print("Failed to set focus")
        }
    }
    
    @objc private func startStreaming() {
        if !self.session.isRunning {
            self.session.startRunning()
        }
        self.session.beginConfiguration()
        self.session.inputs.forEach { self.session.removeInput($0) }
        self.session.outputs.forEach { self.session.removeOutput($0) }
        self.session.connections.forEach { self.session.removeConnection($0) }
        self.session.commitConfiguration()
        self.setupSession()
        self.isRecording = false
        self.recordButton.isSelected = false
        self.recordingTimeLabel.text = "00:00"
        self.recordingTimer?.invalidate()
        self.recordingTimer = nil
    }
    
    private func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.setupSession()
                    }
                }
            }
        default:
            showPermissionAlert()
        }
    }
    private func showPermissionAlert() {
        let alert = UIAlertController(
            title: "Camera Permission Required",
            message: "Please enable camera access in Settings to use this feature.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func setupSession() {
        self.session.beginConfiguration()
        print(self.session.sessionPreset)
        
        if(self.selectedDevices.contains(Devices.telePhoto)) {
            guard setupTelePhoto() else {
                return
            }
        }
        if(self.selectedDevices.contains(Devices.lidar)) {
            guard setupLiDAR() else {
                return
            }
        }
        
        self.session.commitConfiguration()
        self.session.startRunning()
    }
    
    private func setupLiDAR() -> Bool{
        self.session.beginConfiguration()
        defer {
            self.session.commitConfiguration()
        }
        guard let lidarDevice = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInLiDARDepthCamera, for: AVMediaType.video, position: AVCaptureDevice.Position.back) else {
            return false
        }
        self.lidarDevice = lidarDevice
        guard let format = (self.lidarDevice.formats.first{ format in
            format.formatDescription.dimensions.width == 1920 &&
            format.formatDescription.mediaSubType.rawValue == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange &&
            !format.isVideoBinned
        }) else {
            return false
        }
        do {
            try self.lidarDevice.lockForConfiguration()
            self.lidarDevice.activeFormat = format
            print(self.lidarDevice.activeFormat)
            self.lidarDevice.unlockForConfiguration()
        } catch {
            return false
        }
        do{
            self.lidarInput = try AVCaptureDeviceInput(device: self.lidarDevice)
            guard session.canAddInput(self.lidarInput) else{
                return false
            }
            self.session.addInputWithNoConnections(self.lidarInput)
        }
        catch{
            return false
        }
        
        guard let lidarDepthPort = self.lidarInput.ports(for: AVMediaType.depthData, sourceDeviceType: self.lidarDevice.deviceType, sourceDevicePosition: self.lidarDevice.position).first else {
            return false
        }
        self.lidarDepthPort = lidarDepthPort
        self.lidarDepthOutput = AVCaptureDepthDataOutput()
        guard self.session.canAddOutput(self.lidarDepthOutput) else{
            return false
        }
        self.session.addOutputWithNoConnections(self.lidarDepthOutput)
        self.lidarDepthVideoConnection = AVCaptureConnection(inputPorts: [self.lidarDepthPort], output: self.lidarDepthOutput)
        self.session.addConnection(self.lidarDepthVideoConnection)
        self.lidarDepthOutput.setDelegate(self, callbackQueue: DispatchQueue.global(qos: .userInitiated))
        
        return true
    }
    
    private func setupTelePhoto() -> Bool{
        self.session.beginConfiguration()
        defer {
            self.session.commitConfiguration()
        }
        guard let telePhotoDevice = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInTelephotoCamera, for: AVMediaType.video, position: AVCaptureDevice.Position.back) else {
            return false
        }
        
        self.telePhotoDevice = telePhotoDevice
        guard let format = (self.telePhotoDevice.formats.first{ format in
            format.formatDescription.dimensions.width == 1920 &&
            format.formatDescription.mediaSubType.rawValue == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange &&
            !format.isVideoBinned
        }) else {
            return false
        }
        
        do {
            try self.telePhotoDevice.lockForConfiguration()
            self.telePhotoDevice.activeFormat = format
            print(self.telePhotoDevice.activeFormat)
            self.telePhotoDevice.unlockForConfiguration()
            
        } catch {
            return false
        }
        do {
            try self.telePhotoDevice.lockForConfiguration()
            self.telePhotoDevice.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
            self.telePhotoDevice.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
            self.telePhotoDevice.unlockForConfiguration()
            print("Frame rate set to 30 fps.")
        } catch {
            print("Failed to set frame rate: \(error)")
        }
        self.focusSlider_Telephoto.value = Float(self.telePhotoDevice.lensPosition)
        self.focusLabel_Telephoto.text = String(format: "Focus: %.1f", self.telePhotoDevice.lensPosition)
        do {
            self.telePhotoInput = try AVCaptureDeviceInput(device: self.telePhotoDevice)
            guard session.canAddInput(self.telePhotoInput) else {
                return false
            }
            self.session.addInputWithNoConnections(self.telePhotoInput)
        }
        catch {
            return false
        }
        
        guard let telePhotoPort = self.telePhotoInput.ports(for: AVMediaType.video, sourceDeviceType: self.telePhotoDevice.deviceType, sourceDevicePosition: self.telePhotoDevice.position).first else {
            return false
        }
        self.telePhotoPort = telePhotoPort
        
        self.telePhotoOutput = AVCaptureMovieFileOutput()
  
        guard self.session.canAddOutput(self.telePhotoOutput) else {
            return false
        }
        self.session.addOutputWithNoConnections(self.telePhotoOutput)

        self.telePhotoVideoConnection = AVCaptureConnection(inputPorts: [self.telePhotoPort], output: self.telePhotoOutput)
        
        if self.telePhotoVideoConnection.isVideoStabilizationSupported {
            self.telePhotoVideoConnection.preferredVideoStabilizationMode = .off
            print("Video stabilization disabled.")
        }
        
        self.telePhotoVideoConnection.videoRotationAngle = .zero
        guard self.session.canAddConnection(self.telePhotoVideoConnection) else {
            return false
        }
        self.session.addConnection(self.telePhotoVideoConnection)
        
        self.telePhotoPreviewLayer = AVCaptureVideoPreviewLayer()
        self.telePhotoPreviewLayer.setSessionWithNoConnection(self.session)
        self.telePhotoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspect
        self.telePhotoPreviewLayer.position = CGPoint(x: self.telePhotoUIView.frame.width / 2, y: self.telePhotoUIView.frame.height / 2)
        self.telePhotoPreviewLayer.bounds = self.telePhotoUIView.frame
        self.telePhotoUIView.layer.addSublayer(self.telePhotoPreviewLayer)
        self.telePhotoLayerConnection = AVCaptureConnection(inputPort: self.telePhotoPort, videoPreviewLayer: self.telePhotoPreviewLayer)
        self.telePhotoVideoConnection.videoRotationAngle = .zero
        guard self.session.canAddConnection(self.telePhotoLayerConnection) else {
            return false
        }
        self.session.addConnection(self.telePhotoLayerConnection)
        return true
    }

    @objc private func recordButtonTapped() {
        if !self.isRecording {
            self.startRecording()
        } else {
            self.stopRecording()
        }
    }
    
    private func startRecording() {
        isRecording = true
        recordButton.isSelected = true
        videoRecordingStartTime = Date()
        
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateRecordingTime()
        }
        let timestamp = Int(Date().timeIntervalSince1970)
        let paths = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)
        let documentsDirectory = paths[0] as String
        if(self.selectedDevices.contains(Devices.telePhoto)) {
            self.telePhotoBackgroundTaskID = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
            // Determine codec: HEVC if available, otherwise fallback to H.264
            let selectedCodec: AVVideoCodecType = self.telePhotoOutput.availableVideoCodecTypes.contains(.hevc) ? .hevc : .h264
            self.telePhotoOutput.setOutputSettings([AVVideoCodecKey: selectedCodec], for: self.telePhotoVideoConnection)
            self.telePhotoOutput.startRecording(to: URL(fileURLWithPath: "\(documentsDirectory)/Telephoto_\(timestamp).mov"), recordingDelegate: self)
        }
    }
    
    private func stopRecording() {
        self.isRecording = false
        recordButton.isSelected = false
        videoRecordingStartTime = nil
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingTimeLabel.text = "00:00"
        
        if(self.selectedDevices.contains(Devices.telePhoto)) {
            self.telePhotoOutput.stopRecording()
        }
        
    }
    
    private func updateRecordingTime() {
        guard let startTime = videoRecordingStartTime else { return }
        let duration = Date().timeIntervalSince(startTime)
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        recordingTimeLabel.text = String(format: "%02d:%02d", minutes, seconds)
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: (any Error)?) {
        let albumName = outputFileURL.deletingPathExtension().lastPathComponent.isEmpty
        ? "PocketVib_Record"
        : outputFileURL.deletingPathExtension().lastPathComponent
        
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                self.endBackgroundTask(for: output)
                return
            }
            
            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
            if let existingAlbum = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions).firstObject {
                PHPhotoLibrary.shared().performChanges({
                    let videoReq = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputFileURL)
                    if let ph = videoReq?.placeholderForCreatedAsset {
                        PHAssetCollectionChangeRequest(for: existingAlbum)?.addAssets([ph] as NSArray)
                    }
                }) { success, _ in
                    if success {
                        self.extractAndSaveFramesAsPNG(into: existingAlbum, from: outputFileURL) {
                            self.endBackgroundTask(for: output)
                        }
                    } else {
                        self.endBackgroundTask(for: output)
                    }
                }
            } else {
                var placeholder: PHObjectPlaceholder?
                PHPhotoLibrary.shared().performChanges({
                    placeholder = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
                        .placeholderForCreatedAssetCollection
                }) { success, error in
                    if success, let placeholder = placeholder {
                        let newAlbum = PHAssetCollection.fetchAssetCollections(
                            withLocalIdentifiers: [placeholder.localIdentifier], options: nil
                        ).firstObject
                        PHPhotoLibrary.shared().performChanges({
                            let videoReq = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputFileURL)
                            if let ph = videoReq?.placeholderForCreatedAsset, let album = newAlbum {
                                PHAssetCollectionChangeRequest(for: album)?.addAssets([ph] as NSArray)
                            }
                        }) { success, _ in
                            if success {
                                self.extractAndSaveFramesAsPNG(into: newAlbum, from: outputFileURL) {
                                    self.endBackgroundTask(for: output)
                                }
                            }
                            else {
                                self.endBackgroundTask(for: output)
                            }
                        }
                    } else {
                        
                        PHPhotoLibrary.shared().performChanges({
                            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputFileURL)
                        }) { _, _ in
                            self.extractAndSaveFramesAsPNG(into: nil, from: outputFileURL) {
                                self.endBackgroundTask(for: output)
                            }
                            
                        }
                    }
                }
            }
        }
    }

    private func endBackgroundTask(for output: AVCaptureFileOutput) {
        var backgroundTaskID: UIBackgroundTaskIdentifier?
        
        if output == self.telePhotoOutput {
            backgroundTaskID = self.telePhotoBackgroundTaskID
            self.telePhotoBackgroundTaskID = UIBackgroundTaskIdentifier.invalid
        }
        if let currentBackgroundTaskID = backgroundTaskID, currentBackgroundTaskID != UIBackgroundTaskIdentifier.invalid {
            UIApplication.shared.endBackgroundTask(currentBackgroundTaskID)
        }
    }
    
    // MARK: - Frame Extraction
    private func extractAndSaveFramesAsPNG(into album: PHAssetCollection?, from videoURL: URL, completion: @escaping () -> Void) {
            let asset = AVURLAsset(url: videoURL)
            let generator = AVAssetImageGenerator(asset: asset)
    
            // Ensure accurate frame extraction (not just keyframes)
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero
            generator.appliesPreferredTrackTransform = true
    
            // Calculate times for every frame
            let durationSeconds = CMTimeGetSeconds(asset.duration)
            guard let track = asset.tracks(withMediaType: .video).first else {
                print("No video track found")
                completion()
                return
            }
    
            let nominalFrameRate = track.nominalFrameRate
            let totalFrames = Int(durationSeconds * Float64(nominalFrameRate))
    
            print("Starting extraction: \(totalFrames) frames from \(durationSeconds)s video...")
    
            var times: [NSValue] = []
            for i in 0..<totalFrames {
                let time = CMTime(value: CMTimeValue(i), timescale: CMTimeScale(nominalFrameRate))
                times.append(NSValue(time: time))
            }
    
            let group = DispatchGroup()
    
            // Process in chunks or individually. Using generateCGImagesAsynchronously is efficient.
            generator.generateCGImagesAsynchronously(forTimes: times) { requestedTime, image, actualTime, result, error in
    
                if let image = image, result == .succeeded {
                    group.enter()
    
                    // Convert to UIImage then PNG Data
                    let uiImage = UIImage(cgImage: image)
    
                    // Save to Photo Library
                    PHPhotoLibrary.shared().performChanges({
                        // Create an asset request from the image
                        let imageRequest = PHAssetChangeRequest.creationRequestForAsset(from: uiImage)
                        if let placeholder = imageRequest.placeholderForCreatedAsset, let album = album {
                            PHAssetCollectionChangeRequest(for: album)?.addAssets([placeholder] as NSArray)
                        }
                    }) { success, error in
                        if !success {
                            print("Failed to save frame at \(actualTime.seconds): \(String(describing: error))")
                        }
                        group.leave()
                    }
                } else {
                    if let error = error {
                        print("Error generating frame at \(requestedTime.seconds): \(error.localizedDescription)")
                    }
                }
            }
        }
}

// MARK: - AVCaptureDepthDataOutputDelegate
extension ViewController: AVCaptureDepthDataOutputDelegate {
    func depthDataOutput(_ output: AVCaptureDepthDataOutput,
                         didOutput depthData: AVDepthData,
                         timestamp: CMTime,
                         connection: AVCaptureConnection) {

        let depthDataMap = depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
        let pixelBuffer = depthDataMap.depthDataMap
    }
}
