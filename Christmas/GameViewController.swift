//
//  GameViewController.swift
//  Christmas
//
//  Created by Alex Studnicka on 08/12/14.
//  Copyright (c) 2014 Alex Studnicka. All rights reserved.
//

import UIKit
import QuartzCore
import SceneKit
import AVFoundation
import CloudKit

extension SCNNode {
	func center() {
		var minVec = UnsafeMutablePointer<SCNVector3>.alloc(0)
		var maxVec = UnsafeMutablePointer<SCNVector3>.alloc(1)
		if self.getBoundingBoxMin(minVec, max: maxVec) {
			let distance = SCNVector3(
				x: maxVec.memory.x - minVec.memory.x,
				y: maxVec.memory.y - minVec.memory.y,
				z: maxVec.memory.z - minVec.memory.z)
			
			self.pivot = SCNMatrix4MakeTranslation(distance.x / 2, distance.y / 2, distance.z / 2)
			minVec.dealloc(0)
			maxVec.dealloc(1)
		}
	}
}

class GameViewController: UIViewController {
	
	@IBOutlet weak var imageView: UIImageView!
	@IBOutlet weak var scnView: SCNView!
	@IBOutlet weak var tapHintView: UIView!
	@IBOutlet weak var treeChoiceButtons: UIView!
	@IBOutlet weak var treeCustomizationView: UIView!
	@IBOutlet weak var continueAfterCustomizationButton: UIButton!
	@IBOutlet weak var cameraControlsView: UIView!
	@IBOutlet weak var shareView: UIView!
	
	let scene = SCNScene()
	let cameraNode = SCNNode()
	
	var audioPlayer = AVAudioPlayer()
	let speechSynthesizer = AVSpeechSynthesizer()
	
	var nameLoaded = false
	var assetsLoaded = false
	var firstName: String!
	
	let cameraSession = AVCaptureSession()
	var cameraDevice: AVCaptureDevice?
	var deviceInput: AVCaptureDeviceInput?
	var stillImageOutput: AVCaptureStillImageOutput?
	var cameraPreviewLayer: AVCaptureVideoPreviewLayer?
	
	var completeImage: UIImage!
	
	// --------------------------------------------------------------------------------------------------------
	// MARK: View Controller
	// --------------------------------------------------------------------------------------------------------

    override func viewDidLoad() {
		super.viewDidLoad()
		
		// --------------------------
		
		let container = CKContainer.defaultContainer()
		container.fetchUserRecordIDWithCompletionHandler({ (recordID, error) in
			if let actualError = error {
				self.nameFallback()
			} else {
				container.requestApplicationPermission(.PermissionUserDiscoverability, { (status, error2) in
					if let actualError = error2 {
						self.nameFallback()
					} else {
						if (status == CKApplicationPermissionStatus.Granted) {
							container.discoverUserInfoWithUserRecordID(recordID, completionHandler: { (info, error3) in
								if let actualError = error3 {
									self.nameFallback()
								} else {
									self.firstName = info.firstName
									self.nameLoaded = true
									self.loaded()
								}
							})
						} else {
							self.nameFallback()
						}
					}
				})
			}
		})
		
		// --------------------------
		
//		// Removed deprecated use of AVAudioSessionDelegate protocol
//		AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, error: nil)
//		AVAudioSession.sharedInstance().setActive(true, error: nil)
		
		cameraSession.sessionPreset = AVCaptureSessionPresetHigh
		for device in AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo) as [AVCaptureDevice]! {
			if device.position == .Back {
				cameraDevice = device
				break
			}
		}
		
		var error: NSError?
		deviceInput = AVCaptureDeviceInput(device: cameraDevice, error: &error)
		if let input = deviceInput {
			if cameraSession.canAddInput(input) {
				cameraSession.addInput(input)
			} else {
				println("can't add input")
			}
		} else {
			println("input error: \(error)")
		}
		
		stillImageOutput = AVCaptureStillImageOutput()
		if let output = stillImageOutput {
			output.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
			if cameraSession.canAddOutput(output) {
				cameraSession.addOutput(output)
			} else {
				println("can't add output")
			}
		} else {
			println("output error")
		}
		
		cameraPreviewLayer = AVCaptureVideoPreviewLayer(session: cameraSession)
		if let previewLayer = cameraPreviewLayer {
			previewLayer.frame = CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: self.view.frame.size.height)
			previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
		} else {
			println("can't create preview")
		}
		
		// --------------------------
		
        cameraNode.camera = SCNCamera()
		cameraNode.camera?.zNear = 0.1
		cameraNode.camera?.zFar = 10000
		cameraNode.position = SCNVector3(x: 0, y: 0, z: 25)
        scene.rootNode.addChildNode(cameraNode)
		
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light!.type = SCNLightTypeOmni
        lightNode.position = SCNVector3(x: 0, y: 10, z: 10)
        scene.rootNode.addChildNode(lightNode)
		
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light!.type = SCNLightTypeAmbient
        ambientLightNode.light!.color = UIColor.darkGrayColor()
        scene.rootNode.addChildNode(ambientLightNode)
		
		// --------------------------
		
        scnView.scene = scene
//		scnView.showsStatistics = true
        scnView.backgroundColor = UIColor.clearColor()
		
		scnView.prepareObjects([SCNScene(named: "art.scnassets/door.dae")!, SCNScene(named: "art.scnassets/christmas_tree.dae")!, SCNScene(named: "art.scnassets/snowy_tree.dae")!], withCompletionHandler: { (success: Bool) -> Void in
			self.assetsLoaded = true
			self.loaded()
		})
		
    }
	
	override func shouldAutorotate() -> Bool {
		return false
	}
	
	override func prefersStatusBarHidden() -> Bool {
		return true
	}
	
	// --------------------------------------------------------------------------------------------------------
	// MARK: Helpers
	// --------------------------------------------------------------------------------------------------------

	func nameFallback() {
		let owner = JBDeviceOwner(device: UIDevice.currentDevice())
		if let firstName = owner.firstName {
			self.firstName = firstName
		}
		self.nameLoaded = true
		loaded()
	}
	
	func loaded() {
		//		println("nameLoaded: \(nameLoaded) | assetsLoaded: \(assetsLoaded)")
		if nameLoaded && assetsLoaded {
			dispatch_async(dispatch_get_main_queue(), {
				self.scene1()
			})
		}
	}
	
	func nodeFromScene(sceneName: String, nodeName: String? = nil) -> SCNNode? {
		let scene = SCNScene(named: "art.scnassets/\(sceneName).dae")
		if let nodeName = nodeName {
			return scene?.rootNode.childNodeWithName(nodeName, recursively: true)
		} else {
			return scene?.rootNode.clone() as SCNNode?
		}
	}
	
	func makeTextNode(text: String, fontName: String = "Gunny Handwriting", fontSize: CGFloat = 3, color: UIColor = UIColor.blueColor()) -> SCNNode {
		let textGeometry = SCNText(string: text, extrusionDepth: 1)
		textGeometry.font = UIFont(name: fontName, size: fontSize)
		textGeometry.alignmentMode = kCAAlignmentCenter
		textGeometry.firstMaterial = SCNMaterial()
		textGeometry.firstMaterial?.diffuse.contents = color
		let textNode = SCNNode(geometry: textGeometry)
		textNode.center()
		return textNode
	}
	
	func playSound(soundName: String) {
		let url = NSBundle.mainBundle().URLForResource(soundName, withExtension: nil, subdirectory: "Sounds")
		audioPlayer = AVAudioPlayer(contentsOfURL: url, error: nil)
		audioPlayer.prepareToPlay()
		audioPlayer.play()
	}
	
	func speak(string: String) {
		let utterance = AVSpeechUtterance(string: string)
//		utterance.voice = AVSpeechSynthesisVoice(language: "cs-CZ")
		utterance.rate = AVSpeechUtteranceMinimumSpeechRate + (AVSpeechUtteranceMaximumSpeechRate - AVSpeechUtteranceMinimumSpeechRate) * 0.33
		self.speechSynthesizer.speakUtterance(utterance)
	}
	
	// --------------------------------------------------------------------------------------------------------
	// MARK: Scenes
	// --------------------------------------------------------------------------------------------------------
	
	func scene1() {
		
		let door = nodeFromScene("door")!
		door.position = SCNVector3(x: -60, y: -45, z: -30)
		door.opacity = 0
		door.runAction(SCNAction.fadeInWithDuration(1))
		scene.rootNode.addChildNode(door)
		
		let snowParticles = SCNParticleSystem(named: "Snow", inDirectory: "art.scnassets")
		scene.addParticleSystem(snowParticles, withTransform: SCNMatrix4MakeTranslation(0, 2, 20))
		
		UIView.animateWithDuration(0.5, delay: 0.5, options: nil, animations: {
			self.tapHintView.alpha = 1
		}, completion: nil)
		
	}
	
	func scene2() {
		
		var greeting = NSLocalizedString("greeting", comment: "")
		var fontSize: CGFloat = 6
		if let firstName = self.firstName {
			greeting = "\(greeting), \(firstName)"
			fontSize = 3
		}
		
		let greetingNode = makeTextNode(greeting, fontName: "FantasticPete", fontSize: fontSize)
		greetingNode.opacity = 0
		greetingNode.runAction(SCNAction.sequence([SCNAction.fadeInWithDuration(1), SCNAction.waitForDuration(2), SCNAction.fadeOutWithDuration(1)]))
		scene.rootNode.addChildNode(greetingNode)
		
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * NSEC_PER_SEC)), dispatch_get_main_queue()) {
			self.speak(greeting)
		}
		
		let text2 = makeTextNode(NSLocalizedString("text_1", comment: ""), fontSize: 2)
		text2.opacity = 0
		text2.runAction(SCNAction.sequence([SCNAction.waitForDuration(4), SCNAction.fadeInWithDuration(1), SCNAction.waitForDuration(3), SCNAction.fadeOutWithDuration(1)]))
		scene.rootNode.addChildNode(text2)
		
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(4 * NSEC_PER_SEC)), dispatch_get_main_queue()) {
			self.speak(NSLocalizedString("text_1_sr", comment: ""))
		}
		
		let text3 = makeTextNode(NSLocalizedString("text_2", comment: ""), fontSize: 2)
		text3.opacity = 0
		text3.runAction(SCNAction.sequence([SCNAction.waitForDuration(9), SCNAction.fadeInWithDuration(1), SCNAction.waitForDuration(3), SCNAction.fadeOutWithDuration(1)]))
		scene.rootNode.addChildNode(text3)
		
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(9 * NSEC_PER_SEC)), dispatch_get_main_queue()) {
			self.speak(NSLocalizedString("text_2_sr", comment: ""))
		}
		
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(13 * NSEC_PER_SEC)), dispatch_get_main_queue()) {
			self.scene3()
		}
	
	}
	
	func scene3() {
		
		UIView.animateWithDuration(1, delay: 0.5, options: nil, animations: {
			self.treeChoiceButtons.alpha = 1
		}, completion: nil)

		SCNTransaction.begin()
		SCNTransaction.setAnimationDuration(2)
		cameraNode.position = SCNVector3(x: 0, y: 200, z: 100)
		cameraNode.eulerAngles = SCNVector3(x: Float(-M_PI/6), y: 0, z: 0)
		SCNTransaction.commit()
		
		let forest = SCNNode()
		forest.name = "Forest"
		forest.position = SCNVector3(x: 0, y: -45, z: -250)
		scene.rootNode.addChildNode(forest)
		
		let tree = nodeFromScene("snowy_tree", nodeName: "SnowyTree")!
		for row in 0...10 {
			for col in 0...10 {
				let treeNode = tree.clone() as SCNNode
				treeNode.position = SCNVector3(x: -500 + Float(col)*100, y: 0, z: -500 + Float(row)*100)
				forest.addChildNode(treeNode)
			}
		}
		
	}
	
	func scene4() {

		for i in 1...3 {
			let switchCtrl = self.treeCustomizationView.viewWithTag(i) as UISwitch
			switchCtrl.on = false
		}
		
		UIView.animateWithDuration(1, delay: 0, options: nil, animations: {
			self.treeChoiceButtons.alpha = 0
		}, completion: nil)
		
		UIView.animateWithDuration(1, delay: 1, options: nil, animations: {
			self.treeCustomizationView.alpha = 1
		}, completion: nil)
		
		SCNTransaction.begin()
		SCNTransaction.setAnimationDuration(2)
		cameraNode.position = SCNVector3(x: 0, y: 0, z: 25)
		cameraNode.eulerAngles = SCNVector3(x: 0, y: 0, z: 0)
		SCNTransaction.commit()
		
		let forest = scene.rootNode.childNodeWithName("Forest", recursively: true)
		forest?.runAction(SCNAction.sequence([SCNAction.fadeOutWithDuration(1), SCNAction.removeFromParentNode()]))
		
		let scene4Node = SCNNode()
		scene4Node.name = "Scene4"
		scene.rootNode.addChildNode(scene4Node)
		
//		let backgroundMaterial = SCNMaterial()
//		backgroundMaterial.diffuse.contents = UIColor.redColor() //UIImage(named: "art.scnassets/bg.jpg") //UIColor.redColor()
//		let backgroundPlane = SCNPlane(width: 100, height: 175)
//		backgroundPlane.firstMaterial = backgroundMaterial
//		let background = SCNNode(geometry: backgroundPlane)
//		background.position = SCNVector3(x: 0, y: 0, z: -120)
//		scene4Node.addChildNode(background)
		
		let tree = nodeFromScene("christmas_tree", nodeName: "ChristmasTree")!
		
		let decorations = tree.childNodeWithName("Decorations", recursively: false)
		decorations?.opacity = 0
		let stand = tree.childNodeWithName("Stand", recursively: false)
		stand?.opacity = 0
		let presents = tree.childNodeWithName("Presents", recursively: false)
		presents?.opacity = 0
		
		tree.center()
		tree.scale = SCNVector3(x: 0.8, y: 0.8, z: 0.8)
		tree.position = SCNVector3(x: -2, y: 6, z: -30)
		tree.opacity = 0
		tree.runAction(SCNAction.sequence([SCNAction.waitForDuration(1), SCNAction.fadeInWithDuration(1)]))
		scene4Node.addChildNode(tree)
		
	}
	
	func scene5() {
		
		UIView.animateWithDuration(0.5, delay: 0, options: nil, animations: {
			self.treeCustomizationView.alpha = 0
		}, completion: nil)
		
		let greeting = makeTextNode(NSLocalizedString("text_3", comment: ""), fontSize: 2.5, color: UIColor.whiteColor())
		greeting.opacity = 0
		scene.rootNode.addChildNode(greeting)
		greeting.runAction(SCNAction.sequence([SCNAction.waitForDuration(0.5), SCNAction.fadeInWithDuration(0.5)]))
		
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * NSEC_PER_SEC)), dispatch_get_main_queue()) {
			
			let bgImage = self.imageView.image
			let fgImage = self.scnView.snapshot()
			
			if (bgImage != nil) {
				let fullSize = bgImage?.size as CGSize!
				let newSize = fgImage?.size as CGSize!
				let scale = newSize.height/fullSize.height
				let offset = (newSize.width - fullSize.width*scale)/2;
				let offsetRect = CGRect(x: offset, y: 0, width: newSize.width-offset*2, height: newSize.height)
				
				UIGraphicsBeginImageContextWithOptions(newSize, true, UIScreen.mainScreen().scale)
				bgImage?.drawInRect(offsetRect)
				fgImage?.drawInRect(CGRect(origin: CGPointZero, size: newSize))
				self.completeImage = UIGraphicsGetImageFromCurrentImageContext()
				UIGraphicsEndImageContext();
				
			} else {
				self.completeImage = fgImage
			}
			
		}
		
		UIView.animateWithDuration(0.5, delay: 1, options: nil, animations: {
			self.shareView.alpha = 1
		}, completion: nil)
		
	}
	
	// --------------------------------------------------------------------------------------------------------
	// MARK: Actions
	// --------------------------------------------------------------------------------------------------------
    
//    func handleTap(gestureRecognize: UIGestureRecognizer) {
//        let p = gestureRecognize.locationInView(scnView)
//        if let hitResults = scnView.hitTest(p, options: nil) {
//			for result in hitResults {
//				if result.node.name == "WoodenDoor" {
//					let doorNode = result.node
//					
//					self.playSound("knock.aif")
//					
//					UIView.animateWithDuration(0.5, delay: 0, options: nil, animations: {
//						self.tapHintView.alpha = 0
//					}, completion: nil)
//					
//					doorNode!.runAction(SCNAction.sequence([SCNAction.waitForDuration(1.5), SCNAction.runBlock({ (node: SCNNode!) -> Void in
//						
//						self.playSound("door-squeak.aif")
//						
//					}), SCNAction.group([SCNAction.rotateByAngle(CGFloat(M_PI_2), aroundAxis: SCNVector3(x: 0, y: 1, z: 0), duration: 1), SCNAction.sequence([SCNAction.waitForDuration(0.75), SCNAction.fadeOutWithDuration(0.5), SCNAction.runBlock({ (node: SCNNode!) -> Void in
//						
////						self.scene2()
//						
//					}), SCNAction.removeFromParentNode()])])]))
//				}
//			}
//        }
//    }
	
	@IBAction func doorTapped(sender: UIButton) {
		
		let doorNode = scene.rootNode.childNodeWithName("WoodenDoor", recursively: true)
		
		self.playSound("knock.aif")
		
		UIView.animateWithDuration(0.5, delay: 0, options: nil, animations: {
			self.tapHintView.alpha = 0
		}, completion: nil)
		
		doorNode!.runAction(SCNAction.sequence([SCNAction.waitForDuration(1.5), SCNAction.runBlock({ (node: SCNNode!) -> Void in
			
			self.playSound("door-squeak.aif")
			
		}), SCNAction.group([SCNAction.rotateByAngle(CGFloat(M_PI_2), aroundAxis: SCNVector3(x: 0, y: 1, z: 0), duration: 1), SCNAction.sequence([SCNAction.waitForDuration(0.75), SCNAction.fadeOutWithDuration(0.5), SCNAction.runBlock({ (node: SCNNode!) -> Void in
			
			self.scene2()
			
		}), SCNAction.removeFromParentNode()])])]))
		
	}
	
	@IBAction func treeChosen(sender: UIButton) {
		
		switch sender.tag {
		case 1:
			self.speak(NSLocalizedString("spruce_choice", comment: ""))
		case 2:
			self.speak(NSLocalizedString("fir_choice", comment: ""))
		case 3:
			self.speak(NSLocalizedString("pine_choice", comment: ""))
		default:
			println("nevim")
		}
		
		scene4()
		
	}
	
	@IBAction func treeCustomizationSwitchChanged(sender: UISwitch) {
		
		var node: SCNNode?
		
		switch sender.tag {
		case 1:
			node = scene.rootNode.childNodeWithName("Decorations", recursively: true)
		case 2:
			node = scene.rootNode.childNodeWithName("Stand", recursively: true)
		case 3:
			node = scene.rootNode.childNodeWithName("Presents", recursively: true)
		default:
			node = nil
		}
		
		if let actualNode = node {
			if sender.on {
				actualNode.runAction(SCNAction.fadeInWithDuration(0.5))
			} else {
				actualNode.runAction(SCNAction.fadeOutWithDuration(0.5))
			}
		}
		
	}
	
	@IBAction func changeBackground(sender: UIButton) {
		
		UIView.animateWithDuration(0.5, delay: 0, options: nil, animations: {
			self.treeCustomizationView.alpha = 0
		}, completion: nil)
		
		UIView.animateWithDuration(0.5, delay: 0.25, options: nil, animations: {
			self.cameraControlsView.alpha = 1
			
			self.imageView.image = nil
			self.view.layer.insertSublayer(self.cameraPreviewLayer, atIndex: 0)
			self.cameraSession.startRunning()
		}, completion: nil)
		
	}

	@IBAction func takePhoto(sender: UIButton) {
		
		if let device = cameraDevice {
			if device.hasFlash && device.isFlashModeSupported(.Auto) {
				var error: NSError?
				if device.lockForConfiguration(&error) {
					device.flashMode = .Auto
					device.unlockForConfiguration()
				} else {
					println("camera lock error: \(error)")
				}
			} else {
				println("flash not supported")
			}
		}
		
		stillImageOutput?.captureStillImageAsynchronouslyFromConnection(stillImageOutput?.connectionWithMediaType(AVMediaTypeVideo), completionHandler: { (imageDataSampleBuffer: CMSampleBuffer!, error: NSError!) -> Void in
			
			if let buffer = imageDataSampleBuffer {
				let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(buffer)
				let image = UIImage(data: imageData)
				self.imageView.image = image
			}
			
			UIView.animateWithDuration(0.5, delay: 0, options: nil, animations: {
				self.cameraControlsView.alpha = 0
			}, completion: nil)
			
			UIView.animateWithDuration(0.5, delay: 0.25, options: nil, animations: {
				self.continueAfterCustomizationButton.enabled = true
				self.treeCustomizationView.alpha = 1
				
				self.cameraPreviewLayer?.removeFromSuperlayer()
				self.cameraSession.stopRunning()
			}, completion: nil)
			
		})
		
	}
	
	@IBAction func continueAfterTreeCustomization(sender: UIButton) {
		scene5()
	}
	
	@IBAction func shareAction(sender: UIBarButtonItem) {
		
		let activityController = UIActivityViewController(activityItems: [completeImage], applicationActivities: nil)
		self.presentViewController(activityController, animated: true, completion: nil)
		
	}
	
}
