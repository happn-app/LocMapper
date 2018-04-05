/*
 * URLSession+Synchronous.swift
 * ghapp
 *
 * Created by François Lamboley on 2/6/17.
 * Copyright © 2017 happn. All rights reserved.
 */

import Foundation



extension URLSession {
	
	func synchronousDataTask(with request: URLRequest) throws -> (data: Data?, response: URLResponse?) {
		let semaphore = DispatchSemaphore(value: 0)
		
		var responseData: Data?
		var theResponse: URLResponse?
		var theError: Error?
		
		dataTask(with: request) { data, response, error in
			responseData = data
			theResponse = response
			theError = error
			
			semaphore.signal()
		}.resume()
		
		_ = semaphore.wait(timeout: .distantFuture)
		
		if let error = theError {
			throw error
		}
		
//		print("request: \(request.httpBody?.base64EncodedString())")
//		print("data: \(responseData?.base64EncodedString())")
		
		return (data: responseData, response: theResponse)
	}
	
	func fetchJSON(request: URLRequest) -> [String: Any?]? {
		guard
			let (data, response) = try? URLSession.shared.synchronousDataTask(with: request),
			let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode,
			let nonOptionalData = data, let parsedJson = (try? JSONSerialization.jsonObject(with: nonOptionalData, options: [])) as? [String: Any?]
		else {return nil}
		
		return parsedJson
	}
	
	func fetchJSONAndCheckResponse(request: URLRequest) -> [String: Any?]? {
		guard
			let json = fetchJSON(request: request),
			let response = json["response"] as? [String: Any?],
			response["status"] as? String == "success",
			response["code"] as? String == "200"
		else {return nil}
		
		return json
	}
	
}
