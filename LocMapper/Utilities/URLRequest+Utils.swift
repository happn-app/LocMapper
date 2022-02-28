/*
 * URLRequest+Utils.swift
 * LocMapper
 *
 * Created by François Lamboley on 05/04/2018.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif



extension URLRequest {
	
	init?(baseURL: URL, relativePath: String, httpMethod m: String, queryItems: [URLQueryItem] = [], queryInBody: Bool = false) {
		guard let fullURLNoQuery = URL(string: relativePath, relativeTo: baseURL) else {return nil}
		
		guard var components = URLComponents(url: fullURLNoQuery, resolvingAgainstBaseURL: true) else {return nil}
		components.queryItems = (components.queryItems ?? []) + queryItems
		
		let fullURL: URL
		if queryInBody {fullURL = fullURLNoQuery}
		else {
			guard let u = components.url else {return nil}
			fullURL = u
		}
		
		self.init(url: fullURL)
		httpMethod = m
		
		if queryInBody {
			guard let queryString = components.percentEncodedQuery?.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "+").inverted) else {return nil}
			httpBody = Data(queryString.utf8)
		}
	}
	
}
