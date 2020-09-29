Extension { #name : #Character }

{ #category : #'*Moose-REST-API' }
Character >> neoJsonOn: neoJSONWriter [
	neoJSONWriter writeString: self asString
]
