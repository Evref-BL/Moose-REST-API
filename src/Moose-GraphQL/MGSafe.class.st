"
I gather defensive helpers (class side) used by the Moose GraphQL layer. None of my methods ever raises: every Moose access is guarded and degrades to a sensible default.

	MGSafe printValue: anObject.	 ""readable, truncated String""
	MGSafe entitiesIn: anObject.	 ""OrderedCollection of MooseEntity""
	MGSafe take: 10 from: aCollection.
	MGSafe do: [ ... ] default: nil.
"
Class {
	#name : 'MGSafe',
	#superclass : 'Object',
	#category : 'Moose-GraphQL-Core',
	#package : 'Moose-GraphQL',
	#tag : 'Core'
}

{ #category : 'printing' }
MGSafe class >> basicPrintValue: anObject [
	"Answer a String describing anObject (nil for nil); dates, times and durations in ISO 8601 (see MGTemporalFormat). May raise; use #printValue:."

	anObject ifNil: [ ^ nil ].
	(anObject isString or: [ anObject isSymbol ]) ifTrue: [
		^ anObject asString ].
	(anObject isNumber or: [ anObject == true or: [ anObject == false ] ])
		ifTrue: [ ^ anObject printString ].
	(MGTemporalFormat print: anObject) ifNotNil: [ :iso | ^ iso ].
	(self isCollectionLike: anObject) ifTrue: [
		^ self printCollection: anObject ].
	(self isEntity: anObject) ifTrue: [ ^ self nameOf: anObject ].
	^ anObject printString
]

{ #category : 'evaluating' }
MGSafe class >> do: aBlock default: aValue [
	"Evaluate aBlock, answering aValue (evaluated if it is a block) if anything goes wrong."

	^ [ aBlock value ]
		  on: Error
		  do: [ :e |
				  e return: ([ aValue value ]
						   on: Error
						   do: [ :e2 | e2 return: nil ]) ]
]

{ #category : 'converting' }
MGSafe class >> entitiesIn: anObject [
	"Answer an OrderedCollection containing only the Moose entities found in anObject:
	nil -> empty, collection or group -> its entities, single entity -> one element."

	| result |
	result := OrderedCollection new.
	anObject ifNil: [ ^ result ].
	(self isEntity: anObject) ifTrue: [
			result add: anObject.
			^ result ].
	(self isCollectionLike: anObject) ifFalse: [ ^ result ].
	[
		anObject do: [ :each |
			(self isEntity: each) ifTrue: [ result add: each ] ] ]
		on: Error
		do: [ :e | e return: nil ].
	^ result
]

{ #category : 'printing' }
MGSafe class >> entityNameOf: anEntity [
	"Answer a short String naming anEntity: its mooseName, unless that is empty or only its mooseID (MooseObject fallback, possibly cached before the entity got a name), in which case its name when it has a non-empty one. The mooseID is kept only for entities that genuinely have no name. May raise; use #nameOf:."

	| mooseName entityName |
	mooseName := self
		             do: [ anEntity mooseName ifNotNil: [ :n | n asString ] ]
		             default: nil.
	(mooseName isEmptyOrNil or: [
		 mooseName
		 = (self do: [ anEntity mooseID printString ] default: nil) ])
		ifFalse: [ ^ mooseName ].
	entityName := self
		              do: [ anEntity name ifNotNil: [ :n | n asString ] ]
		              default: nil.
	entityName isEmptyOrNil ifFalse: [ ^ entityName ].
	^ mooseName ifNil: [ anEntity printString ]
]

{ #category : 'printing' }
MGSafe class >> errorString: anError [
	"Answer '<error: message>' for anError. Never raises."

	^ [
		  '<error: '
		  , (anError messageText ifNil: [ anError class name ]) asString
		  , '>' ]
		  on: Error
		  do: [ :e | e return: '<error>' ]
]

{ #category : 'testing' }
MGSafe class >> isCollectionLike: anObject [
	"Answer true if anObject is a non-string collection or a Moose group (never raises)."

	^ [
		  (anObject isKindOf: MooseAbstractGroup) or: [
			  anObject isCollection and: [ anObject isString not ] ] ]
		  on: Error
		  do: [ :e | e return: false ]
]

{ #category : 'testing' }
MGSafe class >> isEntity: anObject [
	"Answer true if anObject is a Moose entity (never raises)."

	^ [ anObject isKindOf: MooseEntity ]
		  on: Error
		  do: [ :e | e return: false ]
]

{ #category : 'printing' }
MGSafe class >> maxPrintSize [

	^ 1000
]

{ #category : 'printing' }
MGSafe class >> nameOf: anObject [
	"Answer a short String naming anObject: for entities their mooseName, or their name when the mooseName is empty or only the mooseID (see #entityNameOf:); ISO 8601 for dates, times and durations (see MGTemporalFormat); printString otherwise (never raises)."

	^ [
		  (self isEntity: anObject)
			  ifTrue: [ self entityNameOf: anObject ]
			  ifFalse: [
			  (MGTemporalFormat print: anObject) ifNil: [ anObject printString ] ] ]
		  on: Error
		  do: [ :e |
				  e return: ([ anObject class name , '?' ]
						   on: Error
						   do: [ :e2 | e2 return: '?' ]) ]
]

{ #category : 'converting' }
MGSafe class >> normalizeTake: aNumberOrNil [
	"Answer an Integer between 0 and MGSchema maxTake; nil, negative or invalid values mean MGSchema defaultTake."

	^ [
		  | n |
		  n := aNumberOrNil.
		  n isString ifTrue: [ n := n asInteger ].
		  (n isNil or: [ n isNumber not or: [ n < 0 ] ])
			  ifTrue: [ MGSchema defaultTake ]
			  ifFalse: [ n asInteger min: MGSchema maxTake ] ]
		  on: Error
		  do: [ :e | e return: 100 ]
]

{ #category : 'printing' }
MGSafe class >> printCollection: aCollection [
	"Answer '<n> items: (a, b, c, …)' showing at most the first 5 elements."

	| size firsts |
	size := self do: [ aCollection size ] default: 0.
	firsts := self take: 5 from: aCollection.
	^ String streamContents: [ :s |
			  s
				  print: size;
				  nextPutAll: ' items'.
			  firsts ifNotEmpty: [
					  s nextPutAll: ': ('.
					  firsts
						  do: [ :each | s nextPutAll: (self nameOf: each) ]
						  separatedBy: [ s nextPutAll: ', ' ].
					  size > firsts size ifTrue: [ s nextPutAll: ', …' ].
					  s nextPut: $) ] ]
]

{ #category : 'printing' }
MGSafe class >> printValue: anObject [
	"Answer a readable String for anObject (nil for nil), truncated to #maxPrintSize characters. Never raises."

	^ [ self truncate: (self basicPrintValue: anObject) ]
		  on: Error
		  do: [ :e | e return: (self errorString: e) ]
]

{ #category : 'converting' }
MGSafe class >> take: aNumberOrNil from: aCollection [
	"Answer an Array with at most (normalized) aNumberOrNil elements of aCollection.
	Iteration stops early so huge groups are never copied."

	| limit result |
	limit := self normalizeTake: aNumberOrNil.
	result := OrderedCollection new: (limit min: 64).
	(limit = 0 or: [ aCollection isNil ]) ifTrue: [ ^ #(  ) ].
	[
		aCollection do: [ :each |
				result size >= limit ifTrue: [ ^ result asArray ].
				result add: each ] ]
		on: Error
		do: [ :e | e return: nil ].
	^ result asArray
]

{ #category : 'printing' }
MGSafe class >> truncate: aStringOrNil [
	"Answer aStringOrNil truncated to #maxPrintSize characters, with a trailing ellipsis when cut."

	aStringOrNil ifNil: [ ^ nil ].
	^ aStringOrNil size > self maxPrintSize
		  ifTrue: [ (aStringOrNil first: self maxPrintSize) , '…' ]
		  ifFalse: [ aStringOrNil ]
]
