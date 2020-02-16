//
//  ViewController.swift
//  routeSafe
//
//  Created by Josh Levine on 2/15/20.
//  Copyright © 2020 Josh Levine. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

protocol HandleMapSearch {
    func dropPinZoomIn(placemark:MKPlacemark)
}

class ViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {

    @IBOutlet weak var mapView: MKMapView!
    
    let locationManager = CLLocationManager()
    var selectedPin:MKPlacemark? = nil
    
    var resultSearchController:UISearchController? = nil
    var params : [[Double]] = [[0,0],[0,0]]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        
        mapView.delegate = self
        
        //var stanford = CLLocation(latitude: 37.42681121826172, longitude: -122.1704330444336)
        //var cal = CLLocation(latitude: 37.8718992, longitude: -122.2585399)
        //var reservoir = CLLocation(latitude: 37.79467605, longitude: -122.39698655)
        
        //var points = [stanford, cal, reservoir]
        
        //for i in 0...points.count-2 {
        //    makeLeg(start: points[i], end: points[i+1])
        //}
        
        let locationSearchTable = storyboard!.instantiateViewController(withIdentifier: "LocationSearchTable") as! LocationSearchTable
        resultSearchController = UISearchController(searchResultsController: locationSearchTable)
        resultSearchController?.searchResultsUpdater = locationSearchTable
        let searchBar = resultSearchController!.searchBar
        searchBar.sizeToFit()
        searchBar.placeholder = "Search for places"
        navigationItem.titleView = resultSearchController?.searchBar
        resultSearchController?.hidesNavigationBarDuringPresentation = false
        resultSearchController?.dimsBackgroundDuringPresentation = true
        definesPresentationContext = true
        locationSearchTable.mapView = mapView
        
        locationSearchTable.handleMapSearchDelegate = self

    }
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(polyline: overlay as! MKPolyline)
        renderer.strokeColor = UIColor.blue
        return renderer
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations[locations.count - 1]
        if location.horizontalAccuracy > 0 {
            locationManager.stopUpdatingLocation()
            locationManager.delegate = nil //stops access of weather data after above method
            
            print("Longitude = \(location.coordinate.longitude), latitude = \(location.coordinate.latitude)")
            
            let latitude = location.coordinate.latitude
            let longitude = location.coordinate.longitude
            params[0][0] = latitude
            params[0][1] = longitude
            
            if let location = locations.first {
                let span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                let region = MKCoordinateRegion(center: location.coordinate, span: span)
                mapView.setRegion(region, animated: true)
            }
            
        }
    }
    func getDirections() {
        print("getting directions")
        if let selectedPin = selectedPin {
            params[1][0] = selectedPin.coordinate.latitude
            params[0][1] = selectedPin.coordinate.longitude
            let mapItem = MKMapItem(placemark: selectedPin)
            sendEndPoints(params: params)
        }
    }

}
extension ViewController: HandleMapSearch {
    func dropPinZoomIn(placemark:MKPlacemark){
        // cache the pin
        selectedPin = placemark
        // clear existing pins
        mapView.removeAnnotations(mapView.annotations)
        let annotation = MKPointAnnotation()
        annotation.coordinate = placemark.coordinate
        annotation.title = placemark.name
        if let city = placemark.locality,
        let state = placemark.administrativeArea {
            annotation.subtitle = "\(city) \(state)"
        }
        mapView.addAnnotation(annotation)
        //mapView.addAnnotation(MKAnnotationView(annotation: annotation, reuseIdentifier: "pin").annotation!)
        let span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        let region = MKCoordinateRegion(center: placemark.coordinate, span: span)
        mapView.setRegion(region, animated: true)
    }
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
         if annotation is MKUserLocation {
                   //return nil so map view draws "blue dot" for standard user location
                   print("user loc")
                   return nil
               }
               let reuseId = "pin"
               var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKPinAnnotationView
               pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
               pinView?.pinTintColor = UIColor.red
               pinView?.canShowCallout = true
               let smallSquare = CGSize(width: 30, height: 30)
               let button = UIButton(frame: CGRect(origin: .zero, size: smallSquare))
               button.setBackgroundImage(UIImage(named: "car"), for: .normal)
               //button.addTarget(self, action: Selector(("getDirections")), for: .touchUpInside)
               print("target should be added")
               pinView?.leftCalloutAccessoryView = button
               return pinView
    }
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        getDirections()
    }
}
//MARK: - Interface with back end
extension ViewController {
    func sendEndPoints(params: [[Double]]) {
        print("sent")
        
        
        var result = [[[37.42681121826172, -122.1704330444336],[37.8718992, -122.2585399]],[[37.8718992, -122.2585399],[37.79467605, -122.39698655]]]
        
        map(points: result)
    }
    func map(points: [[[Double]]]) {
        for pair in points {
            var location1 = CLLocation(latitude: pair[0][0], longitude: pair[0][1])
            var location2 = CLLocation(latitude: pair[1][0], longitude: pair[1][1])
            makeLeg(start: location1, end: location2)
        }
    }
    func makeLeg(start: CLLocation, end: CLLocation) {
        let request = MKDirections.Request()
        let startCoord = start.coordinate
        let endCoord = end.coordinate
        
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: startCoord.latitude, longitude: startCoord.longitude), addressDictionary: nil))
        
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: endCoord.latitude, longitude: endCoord.longitude), addressDictionary: nil))
        
        request.requestsAlternateRoutes = false
        request.transportType = .automobile

        let directions = MKDirections(request: request)

        directions.calculate { [unowned self] response, error in
            guard let unwrappedResponse = response else { return }

            for route in unwrappedResponse.routes {
                self.mapView.addOverlay(route.polyline)
                self.mapView.setVisibleMapRect(route.polyline.boundingMapRect, animated: true)
            }
        }
    }
}
