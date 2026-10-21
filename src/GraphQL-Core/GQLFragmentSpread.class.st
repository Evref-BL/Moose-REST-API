Class {
	#name : 'GQLFragmentSpread',
	#superclass : 'GQLSelection',
	#instVars : [
		'name',
		'directives'
	],
	#category : 'GraphQL-Core-AST',
	#package : 'GraphQL-Core',
	#tag : 'AST'
}

{ #category : 'execution' }
GQLFragmentSpread >> collectFieldsFor: anObjectType visited: aVisitedSet into: aGroupedDictionary path: aPath executor: anExecutor [

	^ anExecutor
		  collectFragmentSpread: self
		  objectType: anObjectType
		  visited: aVisitedSet
		  into: aGroupedDictionary
		  path: aPath
]

{ #category : 'accessing' }
GQLFragmentSpread >> directives [

	^ directives
]

{ #category : 'accessing' }
GQLFragmentSpread >> directives: anObject [

	directives := anObject
]

{ #category : 'initialization' }
GQLFragmentSpread >> initialize [

	super initialize.
	directives := OrderedCollection new
]

{ #category : 'testing' }
GQLFragmentSpread >> isFragmentSpread [

	^ true
]

{ #category : 'accessing' }
GQLFragmentSpread >> name [

	^ name
]

{ #category : 'accessing' }
GQLFragmentSpread >> name: anObject [

	name := anObject
]

{ #category : 'printing' }
GQLFragmentSpread >> printOn: aStream [

	aStream nextPutAll: 'GQLFragmentSpread(...'; nextPutAll: name asString; nextPut: $)
]
