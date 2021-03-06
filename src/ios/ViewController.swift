//
//  ViewController.swift
//  Measure
//
//  Created by levantAJ on 8/9/17.
//  Copyright © 2017 levantAJ. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

@objc protocol ViewControllerDelegate: class {
    func allowMultiple() -> Bool
    func getUnit() -> String
    func getTitle() -> String
    func closeView()
    func onUpdateMeasure(nodeName: String)
}

final class ViewController: UIViewController {
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var targetImageView: UIImageView!
    @IBOutlet weak var loadingView: UIActivityIndicatorView!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var meterImageView: UIImageView!
    @IBOutlet weak var resetImageView: UIImageView!
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet weak var closeButton: UIButton!

    fileprivate lazy var session = ARSession()
    fileprivate lazy var sessionConfiguration = ARWorldTrackingConfiguration()
    fileprivate lazy var isMeasuring = false;
    fileprivate lazy var vectorZero = SCNVector3()
    fileprivate lazy var startValue = SCNVector3()
    fileprivate lazy var endValue = SCNVector3()
    fileprivate lazy var lines: [Line] = []
    fileprivate var currentLine: Line?
    fileprivate lazy var unit: DistanceUnit = .centimeter

    func getMeasures() -> [String] {
        var list: [String] = [];

        for line in lines {
            list.append(line.getValue());
        }

        return list;
    }

    /// Delegate
    var delegate: ViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupScene()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.pause()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if(isMeasuring) {
                isMeasuring = false
                targetImageView.image = UIImage(named: "targetWhite")
                if let line = currentLine {
                    lines.append(line)
                    currentLine = nil
                    resetButton.isHidden = false
                    resetImageView.isHidden = false

                    delegate?.onUpdateMeasure(nodeName: line.getValue())
                }
        } else {
                resetValues()
                isMeasuring = true
                targetImageView.image = UIImage(named: "targetGreen")

                if (delegate?.allowMultiple() == false) {
                    resetButton.isHidden = true
                    resetImageView.isHidden = true
                    for line in lines {
                        line.removeFromParentNode()
                    }
                    lines.removeAll()
                }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {

    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}

// MARK: - ARSCNViewDelegate

extension ViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async { [weak self] in
            self?.detectObjects()
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        messageLabel.text = "Error occurred"
    }

    func sessionWasInterrupted(_ session: ARSession) {
        messageLabel.text = "Interrupted"
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        messageLabel.text = "Interruption ended"
    }
}

// MARK: - Users Interactions

extension ViewController {

    @IBAction func resetButtonTapped(button: UIButton) {
        resetButton.isHidden = true
        resetImageView.isHidden = true
        for line in lines {
            line.removeFromParentNode()
        }
        lines.removeAll()
    }

    @IBAction func closeButtonTapped(button: UIButton) {
        delegate?.closeView();
    }
}

// MARK: - Privates

extension ViewController {
    fileprivate func setupScene() {
        targetImageView.isHidden = true
        sceneView.delegate = self
        sceneView.session = session
        loadingView.startAnimating()
        meterImageView.isHidden = true
        messageLabel.text = "Detecting the world…"
        resetButton.isHidden = true
        resetImageView.isHidden = true

        if (delegate?.getUnit() == "cm") {
            self.unit = .centimeter
        } else {
            self.unit = .inch
        }

        if #available(iOS 11.3, *) {
            sessionConfiguration.planeDetection = [.horizontal, .vertical]
        } else {
            sessionConfiguration.planeDetection = [.horizontal]
        }

        session.run(sessionConfiguration, options: [.resetTracking, .removeExistingAnchors])
        resetValues()
    }

    fileprivate func resetValues() {
        isMeasuring = false
        startValue = SCNVector3()
        endValue =  SCNVector3()
    }

    fileprivate func detectObjects() {
        guard let worldPosition = sceneView.realWorldVector(screenPosition: view.center) else { return }
        targetImageView.isHidden = false
        meterImageView.isHidden = false
        if lines.isEmpty {
            messageLabel.text = "Hold screen & move your phone…"
        }
        loadingView.stopAnimating()
        if isMeasuring {
            if startValue == vectorZero {
                startValue = worldPosition
                currentLine = Line(sceneView: sceneView, startVector: startValue, unit: unit, unitTxt: delegate?.getTitle() ?? "cm")
            }
            endValue = worldPosition
            currentLine?.update(to: endValue)
            messageLabel.text = currentLine?.distance(to: endValue) ?? "Calculating…"
        }
    }
}
