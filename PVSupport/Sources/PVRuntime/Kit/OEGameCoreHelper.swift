// Copyright (c) 2022, OpenEmu Team
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of the OpenEmu Team nor the
//       names of its contributors may be used to endorse or promote products
//       derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation
import AudioToolbox
import GameController

public enum OEGameCoreEffectsMode {
    case reflectPaused
    case displayAlways
}

public enum RunState {
    case running, paused, stopped
}

public protocol OEGameCoreHelperRunStateDelegate: AnyObject {
    func helper(_ helper: OEGameCoreHelper, didChangeState state: RunState)
}

@objc public protocol OEGameCoreView: AnyObject {
    var timeSinceLastDraw: TimeInterval { get }
    var framesPerSecond: Int { get }
}

/// A protocol that defines the behaviour required to control an emulator core.
///
/// A host application obtains an instance of ``OEGameCoreHelper`` in order
/// to communicate with the core, which may be running in another thread or
/// a remote process.
public protocol OEGameCoreHelper: AnyObject, CustomStringConvertible {
    // MARK: - Core Properties
    
    var renderFPS: Double { get }
    var frameInterval: Double { get }
    var controller1: GCController? { get set }
    var controller2: GCController? { get set }
    var controller3: GCController? { get set }
    var controller4: GCController? { get set }
   
    var romName: String? { get set }
    var saveStatesPath: String? { get set }
    var batterySavesPath: String? { get set }
    var biosPath: String? { get set }
    var systemIdentifier: String? { get set }
    var coreIdentifier: String? { get set }
    var romMD5: String? { get set }
    var romSerial: String? { get set }
    var screenType: String? { get set }
    var supportsSaveStates: Bool { get }
    
    var responderClient: AnyObject? { get }
    var viewController: AnyObject? { get }
    /// Returns an object that can be optionally cast to one of the supported features
    /// such as ``DiscSwappable``.
    var features: AnyObject? { get }

    /// Adjust the output volume of the core.
    ///
    /// - Parameter value: The new volume level, from @c [0,1.0]
    func setVolume(_ value: Float)
    
    /**
     * Manage the paused status of the core.
     *
     * @param pauseEmulation Specify @c true to pause the core.
     */
    func setPauseEmulation(_ pauseEmulation: Bool)
    
    var runStateDelegate: OEGameCoreHelperRunStateDelegate? { get set }
    
    /// Specifies how and when shader effects are rendered.
    ///
    /// Shader effects are normally paused when the core is paused. This
    /// API allows futher control over when the effects are rendered.
    ///
    /// - Parameter mode: Determines how and when shader effects are rendered.
    ///
    func setEffectsMode(_ mode: OEGameCoreEffectsMode)
#if os(macOS)
    func setAudioOutputDeviceID(_ deviceID: AudioDeviceID)
#endif
    func setOutputBounds(_ rect: CGRect)
    func setBackingScaleFactor(_ newBackingScaleFactor: CGFloat)
    
    /// Controls whether the renderer should use a variable refresh rate.
    func setAdaptiveSyncEnabled(_ enabled: Bool)
    func setShaderURL(_ url: URL, parameters: [String: NSNumber]?, completionHandler block: @escaping (Error?) -> Void)
    func setShaderParameterValue(_ value: CGFloat, forKey key: String)
    func loadFile(atPath path: String) throws
    func setupEmulation(completionHandler handler: @escaping (_ screenSize: OEIntSize, _ aspectSize: OEIntSize) -> Void)
    func startEmulation(completionHandler handler: @escaping () -> Void)
    func resetEmulation(completionHandler handler: @escaping () -> Void)
    func stopEmulation(completionHandler handler: @escaping () -> Void)
    func saveStateToFile(at fileURL: URL, completionHandler block: @escaping (Bool, Error?) -> Void)
    func loadStateFromFile(at fileURL: URL, completionHandler block: @escaping (Bool, Error?) -> Void)
    func setCheat(_ cheatCode: String, withType type: String, enabled: Bool)
    func setDisc(_ discNumber: UInt)
    func changeDisplay(withMode displayMode: String)
    func insertFile(at url: URL, completionHandler block: @escaping (Bool, Error?) -> Void)
    
    /// Capture an image of the core's video display buffer, which includes all shader effects.
    func captureOutputImage(completionHandler block: @escaping (CGImage) -> Void)
    
    /// Capture an image of the core's raw video display buffer with no effects.
    func captureSourceImage(completionHandler block: @escaping (CGImage) -> Void)
}