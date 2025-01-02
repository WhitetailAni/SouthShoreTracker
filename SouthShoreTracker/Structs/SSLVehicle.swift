//
//  SSLVehicle.swift
//  SouthShoreTracker
//
//  Created by WhitetailAni on 1/2/25.
//

import Foundation
import CoreLocation

public enum SSLVehicleType {
    case train
    case bus
    
    public func description() -> String {
        switch self {
        case .train:
            return "train"
        case .bus:
            return "bus"
        }
    }
}

public struct SSLVehicle {
    public var location: CLLocationCoordinate2D
    public var endStop: SSLStop
    public var vehicleType: SSLVehicleType
    public var trainNumber: String
    public var timeLastUpdated: String
    public var arrivals: [SSLArrival]
}
