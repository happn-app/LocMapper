/*
Copyright 2020 happn

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License. */

import Foundation



/* There are some properties that have been ignored because deemed not useful. */
struct LokaliseKey : Codable {
	
	var keyId: Int
	var keyName: [String: String]
	
	var tags: [String]?
	var translations: [LokaliseTranslation]
	
	var isPlural: Bool
	var pluralName: String?
	
	var isHidden: Bool
	var isArchived: Bool
	
}
