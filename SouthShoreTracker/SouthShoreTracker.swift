//
//  MapView.swift
//  Cerulean
//
//  Created by WhitetailAni on 7/23/24.
//

import Foundation
import CoreLocation
import MapKit

///The class used to interface with the CTA's Train Tracker API. A new instance should be created on every request to allow for multiple concurrent requests.
public class SSLTracker: NSObject {
    let semaphore = DispatchSemaphore(value: 0)
    let baseURL = "https://southshore.etaspot.net/service.php"
    private let key = "TESTING"
    
    public static var colors = (beige: NSColor(r: 197, g: 193, b: 157), maroon: NSColor(r: 126, g: 40, b: 30))
    
    public func getStops() -> [SSLStop] {
        var returnedData: [String: Any] = [:]
        var components = URLComponents(string: baseURL)
         
        components?.queryItems = [
            URLQueryItem(name: "service", value: "get_stops")
        ]
        
        pollIndiana(components: components) { result in
            returnedData = result
            self.semaphore.signal()
        }
        semaphore.wait()
        
        let rawStops = returnedData["get_stops"] as? [[String: Any]] ?? []
        
        var stops: [SSLStop] = []
        for rawStop in rawStops {
            let latitude = rawStop["lat"] as? Double ?? 0.0
            let longitude = rawStop["lng"] as? Double ?? 0.0
            let name = rawStop["name"] as? String ?? "Unknown Station"
            let id = rawStop["id"] as? Int ?? 0
            
            stops.append(SSLStop(name: name, id: id, location: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)))
        }
        
        return stops
    }
    
    public func getOverlay() -> MKPolyline {
        var returnedData: [String: Any] = [:]
        var components = URLComponents(string: baseURL)
         
        components?.queryItems = [
            URLQueryItem(name: "service", value: "get_routes")
        ]
        
        pollIndiana(components: components) { result in
            returnedData = result
            self.semaphore.signal()
        }
        semaphore.wait()
        
        let rawData = returnedData["get_routes"] as? [[String: Any]] ?? []
        let encline = rawData[0]["encLine"] as? String ?? ""
        let bigArray = self.deCode(polyline: encline)
        
        return MKPolyline(coordinates: bigArray, count: bigArray.count)
    }
    
    public func getVehicles() -> [SSLVehicle] {
        var returnedData: [String: Any] = [:]
        var components = URLComponents(string: baseURL)
        
        components?.queryItems = [
            URLQueryItem(name: "service", value: "get_vehicles"),
            URLQueryItem(name: "inService", value: "1")
        ]
        
        pollIndiana(components: components) { result in
            returnedData = result
            self.semaphore.signal()
        }
        semaphore.wait()
        
        var array: [SSLVehicle] = []
        let rawVehicles = returnedData["get_vehicles"] as? [[String: Any]] ?? []
        
        for rawVehicle in rawVehicles {
            if let latitude = rawVehicle["lat"] as? Double, let longitude = rawVehicle["lng"] as? Double, let timestamp = rawVehicle["receiveTime"] as? Double, let type = rawVehicle["vehicleType"] as? String, let trainNumber = rawVehicle["tripID"] as? String {
                var typeTwo: SSLVehicleType = .bus
                if type == "Train" {
                    typeTwo = .train
                }
                array.append(SSLVehicle(location: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), endStop: SSLStop.getStopForId(id: SSLStop.getEndStopIdForTrain(trainNumber: trainNumber), stops: self.getStops()), vehicleType: typeTwo, trainNumber: trainNumber, timeLastUpdated: timestampFix(timestamp: timestamp), arrivals: []))
            }
        }
        
        return array
    }
    
    public func getVehiclesAndArrivals() -> [SSLVehicle] {
        var returnedData: [String: Any] = [:]
        var components = URLComponents(string: baseURL)
        
        components?.queryItems = [
            URLQueryItem(name: "service", value: "get_vehicles"),
            URLQueryItem(name: "inService", value: "1"),
            URLQueryItem(name: "includeETAData", value: "1"),
            URLQueryItem(name: "orderedETAArray", value: "1")
        ]
        
        pollIndiana(components: components) { result in
            returnedData = result
            self.semaphore.signal()
        }
        semaphore.wait()
        
        var array: [SSLVehicle] = []
        let rawVehicles = returnedData["get_vehicles"] as? [[String: Any]] ?? []
        
        for rawVehicle in rawVehicles {
            if let latitude = rawVehicle["lat"] as? Double, let longitude = rawVehicle["lng"] as? Double, let timestamp = rawVehicle["receiveTime"] as? Double, let type = rawVehicle["vehicleType"] as? String, let trainNumber = rawVehicle["tripID"] as? String, let rawArrivals = rawVehicle["minutesToNextStops"] as? [[String: Any]] {
                var typeTwo: SSLVehicleType = .bus
                if type == "Train" {
                    typeTwo = .train
                }
                
                var brray: [SSLArrival] = []
                
                for rawArrival in rawArrivals {
                    if let id = rawArrival["stopID"] as? Int, let track = rawArrival["track"] as? Int, let rawScheduledTime = rawArrival["schedule"] as? String, let rawActualTime = rawArrival["status"] as? String, let minutes = rawArrival["minutes"] as? Int {
                        let scheduledTime = fixTime(time: rawScheduledTime)
                        var actualTime = scheduledTime
                        if rawActualTime != "On Time" {
                            actualTime = fixTime(time: rawActualTime)
                        }
                        
                        brray.append(SSLArrival(stop: SSLStop.getStopForId(id: id, stops: self.getStops()), scheduledArrivalTime: scheduledTime, actualArrivalTime: actualTime, minutesTilArrival: minutes, track: track, trainNumber: trainNumber))
                    }
                }
                
                array.append(SSLVehicle(location: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), endStop: SSLStop.getStopForId(id: SSLStop.getEndStopIdForTrain(trainNumber: trainNumber), stops: self.getStops()), vehicleType: typeTwo, trainNumber: trainNumber, timeLastUpdated: timestampFix(timestamp: timestamp), arrivals: brray))
            }
        }
        
        return array
    }
    
    public func getArrivalsForStopId(id: Int) -> [SSLArrival] {
        var returnedData: [String: Any] = [:]
        var components = URLComponents(string: baseURL)
        
        components?.queryItems = [
            URLQueryItem(name: "service", value: "get_stop_etas"),
            URLQueryItem(name: "stopID", value: String(id))
        ]
        
        pollIndiana(components: components) { result in
            returnedData = result
            self.semaphore.signal()
        }
        semaphore.wait()
        
        var array: [SSLArrival] = []
        let rawArrivals = returnedData["get_stop_etas"] as? [[String: Any]] ?? []
        
        for rawArrival in rawArrivals {
            if let track = rawArrival["track"] as? Int, let rawScheduledTime = rawArrival["schedule"] as? String, let rawActualTime = rawArrival["status"] as? String, let minutes = rawArrival["minutes"] as? Int, let trainNumber = rawArrival["scheduleNumber"] as? String {
                let scheduledTime = fixTime(time: rawScheduledTime)
                let actualTime = fixTime(time: rawActualTime)
                
                array.append(SSLArrival(stop: SSLStop.getStopForId(id: id, stops: self.getStops()), scheduledArrivalTime: scheduledTime, actualArrivalTime: actualTime, minutesTilArrival: minutes, track: track, trainNumber: trainNumber))
            }
        }
        
        return array
    }
    
    public func getServiceAnnouncements() -> [SSLServiceAnnouncement] {
        var returnedData: [String: Any] = [:]
        var components = URLComponents(string: baseURL)
         
        components?.queryItems = [
            URLQueryItem(name: "service", value: "get_service_announcements")
        ]
        
        pollIndiana(components: components) { result in
            returnedData = result
            self.semaphore.signal()
        }
        semaphore.wait()
        print(returnedData)
        print("NOT FUNCTIONAL")
        
        return [SSLServiceAnnouncement(title: "This function will be added in a future update.")]
    }
    
    private func fixTime(time: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "HH:mma"
        inputFormatter.timeZone = TimeZone.autoupdatingCurrent
        let date = inputFormatter.date(from: time)
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "HH:mm"
        outputFormatter.timeZone = TimeZone.init(secondsFromGMT: 0)
        
        return outputFormatter.string(from: date ?? Date(timeIntervalSince1970: 0))
    }
    
    private func timestampFix(timestamp: Double) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone.autoupdatingCurrent
        
        return formatter.string(from: Date(timeIntervalSince1970: timestamp / 1000))
    }
    
    private func deCode(polyline: String) -> [CLLocationCoordinate2D] {
        var index = polyline.startIndex
        var lat = 0
        var lng = 0
        var coordinates: [CLLocationCoordinate2D] = []
        
        while index < polyline.endIndex {
            var changes: [Int] = []
            
            for _ in 0..<2 {
                var shift = 0
                var result = 0
                
                while true {
                    guard index < polyline.endIndex else { break }
                    let byte = Int(polyline[index].asciiValue! - 63)
                    index = polyline.index(after: index)
                    result |= (byte & 0x1F) << shift
                    shift += 5
                    if byte < 0x20 { break }
                }
                
                let delta = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
                changes.append(delta)
            }
            
            lat += changes[0]
            lng += changes[1]
            coordinates.append(CLLocationCoordinate2D(latitude: Double(lat) / 1e5, longitude: Double(lng) / 1e5))
        }
        
        return coordinates
    }

    
    private func pollIndiana(components: URLComponents?, completion: @escaping ([String: Any]) -> Void) {
        var conponents = components
        conponents?.queryItems?.append(URLQueryItem(name: "token", value: key))
        
        guard let url = conponents?.url else {
            completion(["Error": "Invalid URL"])
            return
        }
        
        let task = URLSession.shared.dataTask(with: URLRequest(url: url)) { data, response, error in
            if let error = error {
                completion(["Error": "Request failed: \(error.localizedDescription)"])
                return
            }
            
            if let response = response as? HTTPURLResponse {
                if response.statusCode == 502 {
                    completion([:])
                } else if response.statusCode == 503 {
                    completion([:])
                }
            }
            
            guard let data = data else {
                completion(["Error": "No data received"])
                return
            }
            
            do {
                let jsonResult = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] ?? ["Error": "Invalid JSON"]
                completion(jsonResult)
            } catch {
                completion(["Error": "JSON parsing failed: \(error.localizedDescription)"])
            }
        }
        
        task.resume()
    }
}

extension NSColor {
    convenience init(r: Int, g: Int, b: Int, a: CGFloat = 1.0) {
        self.init(red: CGFloat(r) / 255.0, green: CGFloat(g) / 255.0, blue: CGFloat(b) / 255.0, alpha: a)
    }
}
