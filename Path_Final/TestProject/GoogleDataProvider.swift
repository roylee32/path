//
//  GoogleDataProvider.swift
//  TestProject
//
//  Created by Leshya Bracaglia, Abhi Dankar, and Roy Lee on 4/30/19.
//  Copyright © 2019 nyu.edu. All rights reserved.
//


import UIKit
import Foundation
import CoreLocation
import SwiftyJSON


typealias PlacesCompletion = ([GooglePlace]) -> Void
typealias PhotoCompletion = (UIImage?) -> Void

//This class allows us to create a GoogleDataProvider object that will be used to make api calls and fetch desired data
//This utilizes the GooglePlace class to create an array that holds GooglePlace objects for each business/restaurant
//that comes out of the search from fetchPlacesNearCoordinates and also includes a function to fetch desired photos.
class GoogleDataProvider {
    private var photoCache: [String: UIImage] = [:]
    private var placesTask: URLSessionDataTask?
    private var session: URLSession {
        return URLSession.shared
    }
    
    //this function gets places/restaurants/businesses (from Google API) near a specified coordinate. It is run for every
    //location object in the location array in ViewController.swift to return a list of places.
    func fetchPlacesNearCoordinate(_ coordinate: CLLocationCoordinate2D, radius: Double, type: String, completion: @escaping PlacesCompletion) -> Void {
        var urlString = "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=\(coordinate.latitude),\(coordinate.longitude)&radius=\(radius)&rankby=prominence&sensor=true&type=\(type)&key=\(GoogleKey)"
        
        //changes urlString to handle characters not in set with percent encoded characters
        urlString = urlString.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? urlString
        
        print(urlString)
        guard let url = URL(string: urlString) else {
            completion([])
            return
        }
        
        if let task = placesTask, task.taskIdentifier > 0 && task.state == .running {
            task.cancel()
        }
        
        //Retrieve contents of URL
        placesTask = session.dataTask(with: url) { data, response, error in
            var placesArray: [GooglePlace] = []
            defer {
                DispatchQueue.main.async {
                    completion(placesArray)
                }
            }
            guard let data = data else {
                return
            }
            guard let json = try? JSON(data: data) else {
                return
            }
            
            guard let results = json["results"].arrayObject as? [[String: Any]] else {
                return
            }

            //iterates over results array to create a GooglePlace object for each restuarant/business given by api call.
            results.forEach {
                let place = GooglePlace(dictionary: $0, acceptedTypes: [type])
                placesArray.append(place)
                if let reference = place.photoReference {
                    self.fetchPhotoFromReference(reference) { image in
                        place.photo = image
                    }
                }
            }
        }
        placesTask?.resume()
    }
    
    //this function, used in method above, allows us to get the desired photos of the specific restuaraunt we want.
    func fetchPhotoFromReference(_ reference: String, completion: @escaping PhotoCompletion) -> Void {
        if let photo = photoCache[reference] {
            completion(photo)
        } else {
            let urlString = "https://maps.googleapis.com/maps/api/place/photo?maxwidth=200&photoreference=\(reference)&key=\(GoogleKey)"
            guard let url = URL(string: urlString) else {
                completion(nil)
                return
            }
            
            DispatchQueue.main.async {
                UIApplication.shared.isNetworkActivityIndicatorVisible = true
            }
            
            session.downloadTask(with: url) { url, response, error in
                var downloadedPhoto: UIImage? = nil
                defer {
                    DispatchQueue.main.async {
                        UIApplication.shared.isNetworkActivityIndicatorVisible = false
                        completion(downloadedPhoto)
                    }
                }
                guard let url = url else {
                    return
                }
                guard let imageData = try? Data(contentsOf: url) else {
                    return
                }
                downloadedPhoto = UIImage(data: imageData)
                self.photoCache[reference] = downloadedPhoto
                }
                .resume()
        }
    }
}
