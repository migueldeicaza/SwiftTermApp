//
//  LocationTracking.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 11/2/21.
//  Copyright © 2021 Miguel de Icaza. All rights reserved.
//

import Foundation
import CoreLocation
import os

var locationTracker: LocationTracker?
var geoLog = Logger(subsystem: "org.tirania.SwiftTermApp", category: "geo")

class LocationTracker: NSObject, CLLocationManagerDelegate {
    var locationManager: CLLocationManager
    var running = false
    
    override init () {
        locationManager = CLLocationManager ()
        super.init ()
        
        locationManager.delegate = self
    }
    
    func start () {
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        locationManager.activityType = .other
        locationManager.requestWhenInUseAuthorization()
        
        resume ()
    }

    func stop () {
        locationManager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .notDetermined, .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for loc in locations {
            print ("Got new location \(loc)")
        }
    }
    
    func suspend() {
        locationManager.stopUpdatingLocation()
    }
    
    func resume() {
        locationManager.startUpdatingLocation()
    }
}

func locationTrackerStart () {
    if locationTracker != nil {
        return
    }
    if !CLLocationManager.locationServicesEnabled() {
        geoLog.log(level: .info, "locationServices are disabled")
        return
    }
    locationTracker = LocationTracker()
    locationTracker!.start ()
}

func locationTrackerStop () {
    guard let loc = locationTracker else {
        return
    }
    loc.stop ()
    locationTracker = nil
}

func locationTrackerSuspend () {
    guard let loc = locationTracker else {
        return
    }
    loc.suspend ()
}

func locationTrackerResume () {
    guard let loc = locationTracker else {
        return
    }
    loc.resume ()
}
