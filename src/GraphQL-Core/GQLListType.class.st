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

{ #category : 'execution' }
GQLListType >> coercePresentInputValue: aValue executor: anExecutor [

	^ anExecutor coerceListInputValue: aValue type: self
]

{ #category : 'execution' }
GQLListType >> completePresentValue: aResult fields: aFieldCollection path: aPath parentType: anObjectType fieldDefinition: aFieldDefinition executor: anExecutor [

	^ anExecutor
		  completeListValue: self
		  fields: aFieldCollection
		  result: aResult
		  path: aPath
		  parentType: anObjectType
		  fieldDefinition: aFieldDefinition
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
	"A single (non-collection) value is printed as a value of the item type"

	^ (aValue isCollection and: [
		   (aValue isString or: [ aValue isDictionary ]) not ])
		  ifTrue: [ self class listLiteralFor: aValue itemType: ofType ]
		  ifFalse: [ ofType literalFor: aValue ]
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
