"
I am a list wrapper type around ofType.
"
Class {
	#name : 'GQLListType',
	#superclass : 'GQLType',
	#instVars : [
		'ofType'
	],
	#category : 'GraphQL-Core-Schema',
	#package : 'GraphQL-Core',
	#tag : 'Schema'
}

{ #category : 'instance creation' }
GQLListType class >> of: aType [
	^ self new ofType: aType; yourself
]

{ #category : 'testing' }
GQLListType >> isLeaf [
	^ false
]

{ #category : 'testing' }
GQLListType >> isList [
	^ true
]

{ #category : 'testing' }
GQLListType >> isNamed [
	^ false
]

{ #category : 'accessing' }
GQLListType >> kind [
	^ 'LIST'
]

{ #category : 'literals' }
GQLListType >> literalFor: aValue [
	(aValue isNil or: [ aValue isString or: [ aValue isDictionary or: [ aValue isCollection not ] ] ])
		ifTrue: [ ^ ofType literalFor: aValue ].
	^ String streamContents: [ :s |
		s nextPut: $[.
		aValue do: [ :e | s nextPutAll: (ofType literalFor: e) ] separatedBy: [ s nextPutAll: ', ' ].
		s nextPut: $] ]
]

{ #category : 'accessing' }
GQLListType >> name [
	"Wrapper types are anonymous"
	^ nil
]

{ #category : 'accessing' }
GQLListType >> namedType [
	^ ofType ifNotNil: [ :t | t namedType ]
]

{ #category : 'accessing' }
GQLListType >> ofType [
	^ ofType
]

{ #category : 'accessing' }
GQLListType >> ofType: aType [
	ofType := aType
]

{ #category : 'printing' }
GQLListType >> printOn: aStream [
	aStream nextPut: $[; print: ofType; nextPut: $]
]
