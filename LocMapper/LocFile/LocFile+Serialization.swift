/*
 * LocFile+Serialization.swift
 * LocMapper
 *
 * Created by François Lamboley on 2/4/18.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation
#if canImport(os)
	import os.log
#endif
#if canImport(zlib)
	import zlib
#else
	import CZlib
#endif

#if !canImport(os) && canImport(DummyLinuxOSLog)
	import DummyLinuxOSLog
#endif



extension LocFile : TextOutputStreamable {
	
	/* ***********************
	   MARK: - Deserialization
	   *********************** */
	
	/* *** Init from path. The metadata should be retrieved with the
	`unserializedMetadata(from:)` method. They are not read from the given path,
	it is the caller responsability to retrieve them by its own means. *** */
	public convenience init(fromPath path: String, withCSVSeparator csvSep: String, metadata: Any? = nil) throws {
		var encoding: UInt = 0
		var filecontent: String?
		if FileManager.default.fileExists(atPath: path) {
			filecontent = try NSString(contentsOfFile: path, usedEncoding: &encoding) as String
		}
		try self.init(filecontent: filecontent ?? "", csvSeparator: csvSep, metadata: metadata)
	}
	
	/* *** Init with data file content. The metadata should be retrieved with the
	`unserializedMetadata(from:)` method. *** */
	public convenience init(filecontent: Data, csvSeparator csvSep: String, metadata: Any?) throws {
		guard let fileContentStr = String(data: filecontent, encoding: .utf8) else {
			throw NSError(domain: "Migrator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot read file as UTF8."])
		}
		try self.init(filecontent: fileContentStr, csvSeparator: csvSep, metadata: metadata)
	}
	
	/* *** Init with file content. The metadata should be retrieved with the
	`unserializedMetadata(from:)` method. *** */
	convenience init(filecontent: String, csvSeparator csvSep: String, metadata: Any?) throws {
		let defaultError = NSError(domain: "Migrator", code: 2, userInfo: nil)
		guard !filecontent.isEmpty else {
			self.init(csvSeparator: csvSep)
			return
		}
		
		let parser = CSVParser(source: filecontent, startOffset: 0, separator: csvSep, hasHeader: true, fieldNames: nil)
		guard let parsedRows = parser.arrayOfParsedRows() else {
			throw defaultError
		}
		
		let languages: [String]
		var entries = [LineKey: LineValue]()
		
		/* Retrieving languages from header */
		let nonLanguageHeaders = Set([
			LocFile.KEY_HEADER_NAME, LocFile.ENV_HEADER_NAME, LocFile.PRIVATE_FILENAME_HEADER_NAME, LocFile.PRIVATE_USERINFO_HEADER_NAME,
			LocFile.PRIVATE_MAPPING_HEADER_NAME, LocFile.PRIVATE_ENCODING_INFO_HEADER_NAME,
			LocFile.FILENAME_HEADER_NAME, LocFile.COMMENTS_HEADER_NAME
		])
		languages = parser.fieldNames.filter{ !nonLanguageHeaders.contains($0) }
		
		var decodingInfo = EncodingInfo()
		
		var i = 0
		var groupComment = ""
		for row in parsedRows {
			/* Let's retrieve the new decoding info if needed */
			if let decodingInfoStr = row[LocFile.PRIVATE_ENCODING_INFO_HEADER_NAME], !decodingInfoStr.isEmpty {
				decodingInfo = EncodingInfo(string: decodingInfoStr)
			}
			
			/* We drop empty rows (or rows only containing decoding info) */
			guard row.contains(where: { !$0.value.isEmpty && $0.key != LocFile.PRIVATE_ENCODING_INFO_HEADER_NAME }) else {continue}
			
			guard
				let locKey                     = row[LocFile.KEY_HEADER_NAME],
				let env                        = row[LocFile.ENV_HEADER_NAME],
				let filename                   = row[LocFile.PRIVATE_FILENAME_HEADER_NAME],
				let encodedRawComment          = row[LocFile.PRIVATE_USERINFO_HEADER_NAME],
				let encodedUserReadableComment = row[LocFile.COMMENTS_HEADER_NAME]
			else {
				di.log.flatMap{ os_log("Invalid row %@ found in csv file. Ignoring this row.", log: $0, type: .info, row) }
				continue
			}
			
			let userReadableComment: String
			if decodingInfo.oneLineStrings {userReadableComment = LocFile.decodeOneLineString(encodedUserReadableComment)}
			else                           {userReadableComment = encodedUserReadableComment}
			
			/* Does the row have a valid environment? */
			guard !env.isEmpty else {
				/* If the environment is empty, we may have a group comment row */
				groupComment = userReadableComment
				continue
			}
			
			/* Let's get the comment and the user info */
			let rawComment: String
			if decodingInfo.oneLineStrings {rawComment = LocFile.decodeOneLineString(encodedRawComment)}
			else                           {rawComment = encodedRawComment}
			
			let comment: String
			let userInfo: [String: String]
			if decodingInfo.compressedUserInfo {
				guard let uncompressed = LocFile.decompressString(rawComment) else {
					throw NSError(domain: "Migrator", code: 3, userInfo: [NSLocalizedDescriptionKey: "Got error while uncompressing comment \"\(rawComment)\""])
				}
				(comment, userInfo) = LineKey.parse(attributedComment: uncompressed)
			} else {
				if rawComment.hasPrefix("__") && rawComment.hasSuffix("__") {
					let prefixAndSuffixLess = rawComment
						.replacingOccurrences(of: "__", with: "", options: [NSString.CompareOptions.anchored])
						.replacingOccurrences(of: "__", with: "", options: [NSString.CompareOptions.anchored, NSString.CompareOptions.backwards])
					(comment, userInfo) = LineKey.parse(attributedComment: prefixAndSuffixLess)
				} else {
					di.log.flatMap{ os_log("Got comment \"%@\" which does not have the __ prefix and suffix. Setting raw comment as comment, but expect troubles.", log: $0, type: .info, rawComment) }
					(comment, userInfo) = LineKey.parse(attributedComment: rawComment)
				}
			}
			
			/* Let's create the line key */
			let k = LineKey(
				locKey: locKey,
				env: env,
				filename: filename,
				index: i,
				comment: comment,
				userInfo: userInfo,
				userReadableGroupComment: groupComment,
				userReadableComment: userReadableComment
			)
			i += 1
			groupComment = ""
			
			if let mappingStr = row[LocFile.PRIVATE_MAPPING_HEADER_NAME].flatMap({ decodingInfo.oneLineStrings ? LocFile.decodeOneLineString($0) : $0 }),
				let mapping = LocKeyMapping(stringRepresentation: mappingStr)
			{
				/* We have a non-empty mapping (may be invalid though, but we don't
				 * check for validity here). Let's set it for the current line key. */
				entries[k] = .mapping(mapping)
			} else {
				/* No non-empty mapping. Value for current line key is dictionary of
				 * language/value. */
				var values = [String: String]()
				for l in languages {
					if let v = row[l].flatMap({ decodingInfo.oneLineStrings ? LocFile.decodeOneLineString($0) : $0 }), v != LocFile.todolocToken {
						values[l] = v
					}
				}
				entries[k] = .entries(values)
			}
		}
		self.init(languages: languages, entries: entries, metadata: metadata, csvSeparator: csvSep, serializationStyle: decodingInfo.oneLineStrings ? .gitFriendly : .csvFriendly)
	}
	
	/* *********************
	   MARK: - Serialization
	   ********************* */
	
	public func write<Target : TextOutputStream>(to target: inout Target) {
		writeHeaders(to: &target)
		
		/* Compute and write the decoding Info */
		let encodingInfo: EncodingInfo
		switch serializationStyle {
		case .csvFriendly:
			encodingInfo = EncodingInfo(compressedUserInfo: true, oneLineStrings: false)
			target.write([String](repeating: csvSeparator, count: 3 + languages.count + 4).joined() + encodingInfo.serialized().csvCellValueWithSeparator(csvSeparator) + "\n")
			
		case .gitFriendly:
			encodingInfo = EncodingInfo(compressedUserInfo: true, oneLineStrings: true)
			target.write([String](repeating: csvSeparator, count: 3).joined() + "⚠️ This file has been saved with the “git friendly” option. Please do not edit manually unless you know what you’re doing.".csvCellValueWithSeparator(csvSeparator))
			target.write([String](repeating: csvSeparator, count: languages.count + 4).joined() + encodingInfo.serialized().csvCellValueWithSeparator(csvSeparator) + "\n")
		}
		
		var previousBasename: String?
		var previousEncodingInfo = encodingInfo
		for entry_key in entries.keys.sorted() {
			/* Computing user readable file name and writing file change separator if needed */
			var basename = entry_key.filename
			if let slashRange = basename.range(of: "/", options: .backwards) {
				if slashRange.lowerBound != basename.endIndex {
					basename = String(basename[basename.index(after: slashRange.lowerBound)...])
				}
			}
			if basename.hasSuffix(".xml") {basename = (basename as NSString).deletingPathExtension}
			if basename.hasSuffix(".strings") {basename = (basename as NSString).deletingPathExtension}
			
			if basename != previousBasename {
				target.write([String](repeating: csvSeparator, count: 3 + languages.count + 4).joined() + "\n")
				target.write(csvSeparator + csvSeparator)
				/* We assume (quite reasonably) that basename will always be on one line (no need to use write(multilineText:to:) to write the value) */
				target.write(("\\o/ \\o/ \\o/ " + basename + " \\o/ \\o/ \\o/").csvCellValueWithSeparator(csvSeparator))
				target.write([String](repeating: csvSeparator, count: 1 + languages.count + 4).joined() + "\n")
				previousBasename = basename
			}
			
			let value = entries[entry_key]!
			let actualEncodingInfo = write(key: entry_key, value: value, userReadableFilename: basename, encodingInfo: encodingInfo, to: &target)
			target.write(csvSeparator)
			if actualEncodingInfo != previousEncodingInfo {
				target.write(actualEncodingInfo.serialized().csvCellValueWithSeparator(csvSeparator)) /* PRIVATE_ENCODING_INFO_HEADER_NAME */
				previousEncodingInfo = actualEncodingInfo
			}
			target.write("\n")
		}
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	static let todolocToken = "!¡!TODOLOC!¡!"
	static let internalLocMapperErrorToken = "!¡!TODOLOC_INTERNALLOCMAPPERERROR!¡!"
	
	private static let KEY_HEADER_NAME = "Key" /* Affects exports to environment’s loc file formats, but also user readable */
	private static let ENV_HEADER_NAME = "Env" /* Affects exports to environment’s loc file formats, but also user readable */
	private static let FILENAME_HEADER_NAME = "File"     /* Only for information to the reader */
	private static let COMMENTS_HEADER_NAME = "Comments" /* Only for information to the reader */
	private static let PRIVATE_FILENAME_HEADER_NAME = "__Filename" /* Private, affects exports to environment’s loc file formats */
	private static let PRIVATE_USERINFO_HEADER_NAME = "__UserInfo" /* Private, affects exports to environment’s loc file formats */
	private static let PRIVATE_MAPPING_HEADER_NAME = "__Mapping"   /* Private, affects exports to environment’s loc file formats */
	private static let PRIVATE_ENCODING_INFO_HEADER_NAME = "__Fmt" /* Private, affects decoding of other columns */
	
	private struct EncodingInfo : Equatable {
		
		var compressedUserInfo: Bool
		var oneLineStrings: Bool
		
		init() {
			compressedUserInfo = false
			oneLineStrings = false
		}
		
		init(compressedUserInfo cui: Bool, oneLineStrings ols: Bool) {
			compressedUserInfo = cui
			oneLineStrings = ols
		}
		
		init(string: String) {
			let (_, userInfo) = string.splitPrependedUserInfo()
			compressedUserInfo = userInfo?["cui"] == "1"
			oneLineStrings = userInfo?["ols"] == "1"
		}
		
		func serialized() -> String {
			return "".byPrepending(userInfo: [
				"cui": compressedUserInfo ? "1" : "0",
				"ols": oneLineStrings ? "1" : "0"
			], sortKeys: true)
		}
		
		static func ==(lhs: EncodingInfo, rhs: EncodingInfo) -> Bool {
			return lhs.compressedUserInfo == rhs.compressedUserInfo && lhs.oneLineStrings == rhs.oneLineStrings
		}
		
	}
	
	private func writeHeaders<Target : TextOutputStream>(to target: inout Target) {
		/* These columns are useful to a casual reader */
		target.write(
			LocFile.KEY_HEADER_NAME.csvCellValueWithSeparator(csvSeparator) +
			csvSeparator + LocFile.ENV_HEADER_NAME.csvCellValueWithSeparator(csvSeparator) +
			csvSeparator + LocFile.FILENAME_HEADER_NAME.csvCellValueWithSeparator(csvSeparator) +
			csvSeparator + LocFile.COMMENTS_HEADER_NAME.csvCellValueWithSeparator(csvSeparator)
		)
		/* The languages */
		for language in languages {
			target.write(csvSeparator + language.csvCellValueWithSeparator(csvSeparator))
		}
		/* Private stuff we use for mapping and some structural information */
		target.write(
			csvSeparator + LocFile.PRIVATE_MAPPING_HEADER_NAME.csvCellValueWithSeparator(csvSeparator) +
			csvSeparator + LocFile.PRIVATE_FILENAME_HEADER_NAME.csvCellValueWithSeparator(csvSeparator) +
			csvSeparator + LocFile.PRIVATE_USERINFO_HEADER_NAME.csvCellValueWithSeparator(csvSeparator) +
			csvSeparator + LocFile.PRIVATE_ENCODING_INFO_HEADER_NAME.csvCellValueWithSeparator(csvSeparator)
		)
		target.write("\n")
	}
	
	/* - Returns: The actual EncodingInfo that were used when writing the data */
	private func write<Target : TextOutputStream>(key: LineKey, value: LineValue, userReadableFilename basename: String, encodingInfo: EncodingInfo, to target: inout Target) -> EncodingInfo {
		var encodingInfo = encodingInfo
		
		/* Writing group comment */
		if !key.userReadableGroupComment.isEmpty {
			target.write(csvSeparator + csvSeparator + csvSeparator)
			write(multilineText: key.userReadableGroupComment, encodingInfo: encodingInfo, to: &target)
			target.write([String](repeating: csvSeparator, count: languages.count + 4).joined())
			target.write("\n")
		}
		
		target.write(
			key.locKey.csvCellValueWithSeparator(csvSeparator) +
			csvSeparator + key.env.csvCellValueWithSeparator(csvSeparator) +  /* ENV_HEADER_NAME */
			csvSeparator + basename.csvCellValueWithSeparator(csvSeparator) + /* FILENAME_HEADER_NAME */
			csvSeparator
		)
		write(multilineText: key.userReadableComment, encodingInfo: encodingInfo, to: &target) /* COMMENTS_HEADER_NAME */
		switch value {
		case .entries(let entries):
			for language in languages {
				target.write(csvSeparator)
				write(multilineText: entries[language] ?? LocFile.todolocToken, encodingInfo: encodingInfo, to: &target)
			}
			target.write(csvSeparator) /* PRIVATE_MAPPING_HEADER_NAME (empty) */
			
		case .mapping(let mapping):
			target.write([String](repeating: csvSeparator, count: languages.count + 1).joined())
			write(multilineText: mapping.stringRepresentation(), encodingInfo: encodingInfo, to: &target) /* PRIVATE_MAPPING_HEADER_NAME */
		}
		
		target.write(
			csvSeparator + key.filename.csvCellValueWithSeparator(csvSeparator) + /* PRIVATE_FILENAME_HEADER_NAME; we assume the filename will always be on one line... */
			csvSeparator
		)
		
		let compressionError = write(userInfo: key.fullComment, encodingInfo: encodingInfo, to: &target) /* PRIVATE_USERINFO_HEADER_NAME */
		if compressionError {encodingInfo.compressedUserInfo = false}
		return encodingInfo
	}
	
	private func write<Target : TextOutputStream>(multilineText: String, encodingInfo: EncodingInfo, to target: inout Target) {
		if !encodingInfo.oneLineStrings {
			/* Simply print the string as-is */
			target.write(multilineText.csvCellValueWithSeparator(csvSeparator))
		} else {
			/* Let's transform the string to have it on one line only (only treating \n and \r cases; not sure there are others anyway) */
			let oneLineStr = multilineText
				.replacingOccurrences(of: " " /* 1 hairsp */, with: "  " /* 2 hairsp */)
				.replacingOccurrences(of: "\n", with: "     " /* 1 hairsp + 4 spaces */)
				.replacingOccurrences(of: "\r", with: "     " /* 1 hairsp + 4 nbsp */)
			target.write(oneLineStr.csvCellValueWithSeparator(csvSeparator))
		}
	}
	
	/** - Returns: `false` if was supposed to compressed, but got error while
	compressing, `true` otherwise. */
	private func write<Target : TextOutputStream>(userInfo: String, encodingInfo: EncodingInfo, to target: inout Target) -> Bool {
		let gotError: Bool
		let written: String
		do {
			if encodingInfo.compressedUserInfo {
				let inputData = Data(userInfo.utf8)
				var outputData = Data(count: Int(compressBound(uLong(inputData.count))) + MemoryLayout<Int32>.size)
				
				/* Let's write the size of the uncompressed data */
				var s = Int32(inputData.count) /* Will crash if input is more that 4 (or maybe 2) GiB. Also, we don't care. */
				outputData[0..<MemoryLayout<Int32>.size] = Data(buffer: UnsafeBufferPointer<Int32>(start: &s, count: 1))
				
				var destLen = uLongf(outputData.count - MemoryLayout<Int32>.size)
				try outputData.withUnsafeMutableBytes{ (outputBytes: UnsafeMutablePointer<Bytef>) in
					try inputData.withUnsafeBytes{ (inputBytes: UnsafePointer<Bytef>) in
						guard compress2(outputBytes + MemoryLayout<Int32>.size, &destLen, inputBytes, uLong(inputData.count), 9) == Z_OK else {
							throw NSError(domain: "__internal__", code: 1, userInfo: nil)
						}
					}
				}
				
				outputData.count = Int(destLen) + MemoryLayout<Int32>.size
				written = outputData.base64EncodedString()
			} else {
				written = "__" + userInfo + "__"
			}
			gotError = false
		} catch {
			/* If we have a problem compressing the data, we fall back to
			 * uncompressed. */
			written = "__" + userInfo + "__"
			gotError = true
		}
		write(multilineText: written, encodingInfo: encodingInfo, to: &target)
		return gotError
	}
	
	private static func decodeOneLineString(_ string: String) -> String {
		func replace(_ replaced: String, with newValue: String, in string: inout String) {
			var searchRange = string.startIndex..<string.endIndex
			while let r = string.range(of: replaced, options: .literal, range: searchRange) {
				var c = 0
				var checked = r.lowerBound
				while checked != string.startIndex {
					checked = string.index(before: checked)
					if string[checked] == " " {c += 1}
					else                      {break}
				}
				
				if c % 2 == 0 {
					string.replaceSubrange(r, with: newValue)
					searchRange = r.lowerBound..<string.endIndex
				} else {
					searchRange = r.upperBound..<string.endIndex
				}
			}
		}
		
		var string = string
		replace("     ", with: "\n", in: &string)
		replace("     ", with: "\r", in: &string)
		string = string.replacingOccurrences(of: "  ", with: " ")
		return string
	}
	
	private static func decompressString(_ string: String) -> String? {
		guard var compressedData = Data(base64Encoded: string), compressedData.count >= MemoryLayout<Int32>.size else {return nil}
		
		/* let retrieve the size of the uncompressed data */
		let s: Int32 = compressedData.withUnsafeBytes{ ptr in ptr.pointee }
		compressedData = compressedData.dropFirst(MemoryLayout<Int32>.size)
		var uncompressedData = Data(count: Int(s))
		
		do {
			var outputLength = uLongf(s)
			try compressedData.withUnsafeBytes{ (inputBytes: UnsafePointer<Bytef>) in
				try uncompressedData.withUnsafeMutableBytes{ (outputBytes: UnsafeMutablePointer<Bytef>) in
					guard uncompress(outputBytes, &outputLength, inputBytes, uLong(compressedData.count)) == Z_OK else {
						throw NSError(domain: "__internal__", code: 1, userInfo: nil)
					}
				}
			}
			uncompressedData.count = Int(outputLength)
		} catch {
			return nil
		}
		
		return String(data: uncompressedData, encoding: .utf8)
	}
	
}
