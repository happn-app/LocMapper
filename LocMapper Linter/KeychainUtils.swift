/*
 * KeychainUtils.swift
 * Lokalise Project Migration
 *
 * Created by François Lamboley on 21/08/2018.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation
import Security



struct Keychain {
	
	enum Error : Swift.Error {
		
		case secError(code: OSStatus, message: String?)
		case internalError
		
	}
	
	static func getStoredData(withIdentifier identifier: String, accessGroup: String? = nil, username: String = "") throws -> Data? {
		var searchResult: CFTypeRef?
		var query = baseQuery(forIdentifier: identifier, accessGroup: accessGroup, username: username)
		query[kSecMatchLimit          as String] = kSecMatchLimitOne
		query[kSecReturnData          as String] = kCFBooleanTrue
		query[kSecReturnRef           as String] = kCFBooleanFalse
		query[kSecReturnPersistentRef as String] = kCFBooleanFalse
		query[kSecReturnAttributes    as String] = kCFBooleanFalse
		
		let error = SecItemCopyMatching(query as CFDictionary, &searchResult)
		switch error {
		case errSecSuccess:
			guard let result = searchResult as? Data else {
				throw Error.internalError
			}
			return result
			
		case errSecItemNotFound:
			return nil
			
		default:
			throw secErrorFrom(statusCode: error)
		}
	}
	
	/** Setting data to nil just removes the entry in the keychain. */
	static func setStoredData(_ data: Data?, withIdentifier identifier: String, accessGroup: String? = nil, username: String = "") throws {
		guard let data = data else {
			try removeStoredData(withIdentifier: identifier, accessGroup: accessGroup, username: username)
			return
		}
		
		var query = baseQuery(forIdentifier: identifier, accessGroup: accessGroup, username: username)
		query[kSecAttrAccessible      as String] = kSecAttrAccessibleAfterFirstUnlock
		query[kSecClass               as String] = kSecClassGenericPassword
		query[kSecMatchLimit          as String] = kSecMatchLimitOne
		query[kSecReturnData          as String] = kCFBooleanFalse
		query[kSecReturnRef           as String] = kCFBooleanFalse
		query[kSecReturnPersistentRef as String] = kCFBooleanFalse
		query[kSecReturnAttributes    as String] = kCFBooleanTrue
		query[kSecAttrIsInvisible     as String] = kCFBooleanFalse
		query[kSecValueData           as String] = data
		
		let updatedProperties = [kSecValueData as String: data]
		
		/* First we try and update the existing property. If the property does not
		 * exist, we will process the error and use SecItemAdd */
		var saveError = SecItemUpdate(query as CFDictionary, updatedProperties as CFDictionary)
		if saveError == errSecItemNotFound {
			/* We don't have a previous entry for the given username, keychain
			 * identifier and access group. Let’s use SecItemAdd. */
			var saveQuery = query
			saveQuery[kSecValueData as String] = data
			
			saveError = SecItemAdd(saveQuery as CFDictionary, nil)
		}
		if saveError != errSecSuccess {
			throw secErrorFrom(statusCode: saveError)
		}
		
		/* Defensive programming! Did we actually set the data correctly? */
		assert((try? getStoredData(withIdentifier: identifier, accessGroup: accessGroup, username: username)) == data)
	}
	
	static func removeStoredData(withIdentifier identifier: String, accessGroup: String? = nil, username: String = "") throws {
		let query = baseQuery(forIdentifier: identifier, accessGroup: accessGroup, username: username)
		
		let error = SecItemDelete(query as CFDictionary)
		switch error {
		case errSecSuccess, errSecItemNotFound /* If the item is not found, we consider the deletion has been successful */:
			return
			
		default:
			throw secErrorFrom(statusCode: error)
		}
	}
	
	#if !os(macOS)
		/* Clearing the keychain only makes sense on a fully sandboxed environment
		 * (iOS, watchOS, etc.). */
		static func clearKeychain() throws {
			let query = [kSecClass as String: kSecClassGenericPassword]
			
			let error = SecItemDelete(query as CFDictionary)
			switch error {
			case errSecSuccess, errSecItemNotFound:
				return
				
			default:
				throw secErrorFrom(statusCode: error)
			}
		}
	#endif
	
	/* ***************
      MARK: - Private
	   *************** */
	
	private static func baseQuery(forIdentifier identifier: String, accessGroup: String?, username: String) -> [String: Any] {
		var res = [String: Any]()
		res[kSecClass as String] = kSecClassGenericPassword
//		res[kSecAttrGeneric as String] = identifier
		res[kSecAttrService as String] = identifier
		res[kSecAttrAccount as String] = username
		#if !os(iOS) || !targetEnvironment(simulator)
			/* We ignore the access group if target is the iPhone simulator. See
			 * the GenericKeychain Apple example in the docs for an explanation on
			 * why we do this. */
			if let accessGroup = accessGroup {
				res[kSecAttrAccessGroup as String] = accessGroup
			}
		#endif
		
		return res
	}
	
	private static func secErrorFrom(statusCode: OSStatus) -> Error {
		#if os(macOS)
			return .secError(code: statusCode, message: SecCopyErrorMessageString(statusCode, nil /* reserved for future use */) as String?)
		#else
			return .secError(code: statusCode, message: nil)
		#endif
	}
	
	private init() {}
	
}
