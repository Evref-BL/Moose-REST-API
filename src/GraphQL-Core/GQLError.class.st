"
I am a GraphQL error as reported in the ""errors"" entry of a GraphQL response.

- message: a String
- path: nil or an Array of response keys (Strings) and list indices (0-based Integers)
- locations: nil or an Array of Dictionaries with 'line' and 'column'
- extensions: nil or a Dictionary of additional information

Use #asJsonDictionary to get the JSON-ready representation.
"
Class {
	#name : 'GQLError',
	#superclass : 'Object',
	#instVars : [
		'message',
		'path',
		'locations',
		'extensions'
	],
	#category : 'GraphQL-Core-Execution',
	#package : 'GraphQL-Core',
	#tag : 'Execution'
}

{ #category : 'instance creation' }
GQLError class >> message: aString [
	^ self new message: aString; yourself
]

{ #category : 'instance creation' }
GQLError class >> message: aString path: aPathOrNil locations: aLocationsOrNil [
	^ self new
		message: aString;
		path: aPathOrNil;
		locations: aLocationsOrNil;
		yourself
]

{ #category : 'converting' }
GQLError >> asJsonDictionary [
	"Answer an OrderedDictionary ready to be written as JSON: message, then locations, path and extensions when present"

	| result |
	result := OrderedDictionary new.
	result at: 'message' put: message asString.
	locations isEmptyOrNil ifFalse: [
			result at: 'locations' put: (locations collect: [ :each |
						 OrderedDictionary new
							 at: 'line' put: (each at: 'line' ifAbsent: [ nil ]);
							 at: 'column' put: (each at: 'column' ifAbsent: [ nil ]);
							 yourself ]) ].
	path ifNotNil: [ result at: 'path' put: path asArray ].
	extensions ifNotNil: [ result at: 'extensions' put: extensions ].
	^ result
]

{ #category : 'accessing' }
GQLError >> extensions [
	^ extensions
]

{ #category : 'accessing' }
GQLError >> extensions: aDictionaryOrNil [
	extensions := aDictionaryOrNil
]

{ #category : 'accessing' }
GQLError >> locations [
	"nil or an Array of Dictionaries line/column"
	^ locations
]

{ #category : 'accessing' }
GQLError >> locations: aCollectionOrNil [
	locations := aCollectionOrNil ifNotNil: [ :l | l asArray ]
]

{ #category : 'accessing' }
GQLError >> message [
	^ message
]

{ #category : 'accessing' }
GQLError >> message: aString [
	message := aString
]

{ #category : 'accessing' }
GQLError >> path [
	"nil or an Array of Strings and Integers"
	^ path
]

{ #category : 'accessing' }
GQLError >> path: aCollectionOrNil [
	path := aCollectionOrNil ifNotNil: [ :p | p asArray ]
]

{ #category : 'printing' }
GQLError >> printOn: aStream [
	super printOn: aStream.
	aStream nextPut: $(; nextPutAll: message asString.
	path ifNotNil: [ aStream nextPutAll: ' @ '; print: path ].
	aStream nextPut: $)
]
