//
//  PacketTunnelProvider.swift
//  OpenVPN Adapter
//
//  Created by Sergey Abramchuk on 05.05.17.
//
//

import NetworkExtension
import OpenVPNAdapter

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    let keychain = Keychain(service: "me.ss-abramchuk.openvpn-ios-client", accessGroup: "2TWXCGG7R3.me.ss-abramchuk.openvpn-ios-client.keychain-group")
    
    lazy var vpnAdapter: OpenVPNAdapter = {
        return OpenVPNAdapter().then { $0.delegate = self }
    }()
    
    var startHandler: ((Error?) -> Void)?
    var stopHandler: (() -> Void)?
    
    override func startTunnel(options: [String : NSObject]? = nil, completionHandler: @escaping (Error?) -> Void) {
        let semaphore = DispatchSemaphore(value: 0)
        semaphore.wait(timeout: .now() + 15)
        
        guard let protocolConfiguration = protocolConfiguration as? NETunnelProviderProtocol else {
            fatalError("protocolConfiguration should be an instance of the NETunnelProviderProtocol class")
        }
        
        // We need providerConfiguration dictionary to retrieve content of the OpenVPN configuration file.
        // Other options related to the tunnel provider also can be stored there.
        guard let providerConfiguration = protocolConfiguration.providerConfiguration else {
            preconditionFailure("providerConfiguration should be provided to the tunnel provider")
        }
        
        //
        guard let fileContent = providerConfiguration[OpenVPNConfigurationKey.fileContent] as? Data else {
            preconditionFailure("fileContent should be provided to the tunnel provider")
        }
        
        // Create presentation of the OpenVPN configuration. Other properties such as connection timeout or
        // private key password aslo may be provided there.
        let vpnConfiguration = OpenVPNConfiguration().then {
            $0.fileContent = fileContent
        }
        
        // Apply OpenVPN configuration.
        let properties: OpenVPNProperties
        do {
            properties = try vpnAdapter.apply(configuration: vpnConfiguration)
        } catch {
            completionHandler(error)
            return
        }
        
        if !properties.autologin {
            guard let username = protocolConfiguration.username else {
                preconditionFailure("username should be provided to the tunnel provider")
            }
            
            guard
                let reference = protocolConfiguration.passwordReference,
                let password = (try? keychain.get(ref: reference))?.map({ $0 })
            else {
                preconditionFailure("password should be provided to the tunnel provider")
            }
            
            let credentials = OpenVPNCredentials().then {
                $0.username = username
                $0.password = password
            }
            
            do {
                try vpnAdapter.provide(credentials: credentials)
            } catch {
                completionHandler(error)
                return
            }
        }
        
        startHandler = completionHandler
        vpnAdapter.connect()
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        stopHandler = completionHandler
        vpnAdapter.disconnect()
    }
    
}

extension PacketTunnelProvider: OpenVPNAdapterDelegate {
    
    func configureTunnel(settings: NEPacketTunnelNetworkSettings, callback: @escaping (OpenVPNAdapterPacketFlow?) -> Void) {
        setTunnelNetworkSettings(settings) { (error) in
            callback(error == nil ? self.packetFlow : nil)
        }
    }
    
    func handle(event: OpenVPNEvent, message: String?) {
        switch event {
        case .connected:
            if reasserting {
                reasserting = false
            }
            
            guard let startHandler = startHandler else {
                return
            }
            
            startHandler(nil)
            self.startHandler = nil
            
        case .disconnected:
            guard let stopHandler = stopHandler else {
                return
            }
            
            stopHandler()
            self.stopHandler = nil
            
        case .reconnecting:
            reasserting = true
            
        default:
            break
        }
    }
    
    func handle(error: Error) {
        // Handle only fatal errors
        guard let fatal = (error as NSError).userInfo[OpenVPNAdapterErrorFatalKey] as? Bool, fatal == true else {
            return
        }
        
        if let startHandler = startHandler {
            startHandler(error)
            self.startHandler = nil
        } else {
            cancelTunnelWithError(error)
        }
    }
    
}
