//
//  ViewController.swift
//  OpenVPN iOS Client
//
//  Created by Sergey Abramchuk on 05.05.17.
//
//

import UIKit
import NetworkExtension

class ViewController: UIViewController {
    
    var manager: NETunnelProviderManager?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func connect(_ sender: Any) {
        let callback = { (error: Error?) -> Void in
            self.manager?.loadFromPreferences(completionHandler: { (error) in
                guard error == nil else {
                    print("\(error!.localizedDescription)")
                    return
                }
                
                let options = [
                    OpenVPNConfigurationKey.username: "testuser" as NSString,
                    OpenVPNConfigurationKey.password: "nonsecure" as NSString
                ]
                
                do {
                    try self.manager?.connection.startVPNTunnel(options: options)
                } catch {
                    print("\(error.localizedDescription)")
                }
            })
        }
        
        configureVPN(callback: callback)
    }
    
    func configureVPN(callback: @escaping (Error?) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { (managers, error) in
            guard error == nil else {
                print("\(error!.localizedDescription)")
                callback(error)
                return
            }
 
            self.manager = managers?.first ?? NETunnelProviderManager()
            self.manager?.loadFromPreferences(completionHandler: { (error) in
                guard error == nil else {
                    print("\(error!.localizedDescription)")
                    callback(error)
                    return
                }
                
//                let configurationFile = Bundle.main.url(forResource: "local_vpn_server", withExtension: "ovpn")
                let configurationFile = Bundle.main.url(forResource: "freeopenvpn_USA_tcp", withExtension: "ovpn")
                let configurationContent = try! Data(contentsOf: configurationFile!)
                
                let tunnelProtocol = NETunnelProviderProtocol()
                tunnelProtocol.serverAddress = "192.168.1.200"
                tunnelProtocol.providerBundleIdentifier = "me.ss-abramchuk.openvpn-ios-client.tunnel-provider"
                tunnelProtocol.providerConfiguration = [OpenVPNConfigurationKey.fileContent: configurationContent]
                tunnelProtocol.disconnectOnSleep = false
                
                self.manager?.protocolConfiguration = tunnelProtocol
                self.manager?.localizedDescription = "OpenVPN iOS Client"
                
                self.manager?.isEnabled = true
                
                self.manager?.saveToPreferences(completionHandler: { (error) in
                    guard error == nil else {
                        print("\(error!.localizedDescription)")
                        callback(error)
                        return
                    }
                    
                    callback(nil)
                })
            })
        }
    }

}

