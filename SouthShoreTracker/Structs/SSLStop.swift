//
//  SSLStop.swift
//  SouthShoreTracker
//
//  Created by WhitetailAni on 1/2/25.
//

import Foundation
import CoreLocation

public struct SSLStop {
    public var name: String
    public var id: Int
    public var location: CLLocationCoordinate2D
    
    public static func getStopForId(id: Int, stops: [SSLStop]) -> SSLStop {
        for stop in stops {
            if stop.id == id {
                return stop
            }
        }
        return SSLStop(name: "Unknown", id: -1, location: CLLocationCoordinate2D(latitude: -4, longitude: -4))
    }
    
    public static func getEndStopIdForTrain(trainNumber: String) -> Int {
        let number = Int(trainNumber) ?? 000
        if [400, 430, 432, 952, 954, 956].contains(number) || isNumberBetween(min: 600, max: 699, value: number) || isNumberBetween(min: 100, max: 199, value: number) {
            return 17
        } else if number % 2 == 0 {
            return 1
        } else if isNumberBetween(min: 400, max: 599, value: number) || number < 100 {
            return 19
        } else if isNumberBetween(min: 200, max: 299, value: number) {
            return 12
        }
        return 0
    }
    
    private static func isNumberBetween(min: Int, max: Int, value: Int) -> Bool {
        return min <= value && value <= max
    }
}
