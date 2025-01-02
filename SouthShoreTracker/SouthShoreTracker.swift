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
    
    public func getStops() -> [SSLStop] {
        var returnedData: [String: Any] = [:]
        var components = URLComponents(string: baseURL)
         
        components?.queryItems = [
            URLQueryItem(name: "service", value: "get_stops")
        ]
        
        contactDowntown(components: components) { result in
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
        
        contactDowntown(components: components) { result in
            returnedData = result
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
        
        contactDowntown(components: components) { result in
            returnedData = result
        }
        //gotta wait til south shore line trains are active to see what to do.
        
        return []
    }
    
    public func test() {
        var components = URLComponents(string: baseURL)
        
        //stop etas
        /*
        components?.queryItems = [
            URLQueryItem(name: "service", value: "get_stop_etas"),
            URLQueryItem(name: "statusData", value: "1")
        ]
        */
         
        components?.queryItems = [
            URLQueryItem(name: "service", value: "get_vehicles"),
            URLQueryItem(name: "inService", value: "1")
        ]
        
        //vehicles
        /*
        components?.queryItems = [
            URLQueryItem(name: "service", value: "get_vehicles"),
            URLQueryItem(name: "includeETAData", value: "1"),
            URLQueryItem(name: "inService", value: "1"),
            URLQueryItem(name: "orderedETAArray", value: "1")
        ]
         */
        
        contactDowntown(components: components) { result in
            print("done")
            print(result)
        }
        return
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

    
    private func contactDowntown(components: URLComponents?, completion: @escaping ([String: Any]) -> Void) {
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
