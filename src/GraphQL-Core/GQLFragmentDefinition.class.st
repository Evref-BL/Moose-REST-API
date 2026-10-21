Class {
	#name : 'GQLFragmentDefinition',
	#superclass : 'GQLDefinition',
	#instVars : [
		'name',
		'typeCondition',
		'directives',
		'selectionSet'
	],
	#category : 'GraphQL-Core-AST',
	#package : 'GraphQL-Core',
	#tag : 'AST'
}

{ #category : 'accessing' }
GQLFragmentDefinition >> directives [

	^ directives
]

{ #category : 'accessing' }
GQLFragmentDefinition >> directives: anObject [

	directives := anObject
]

{ #category : 'initialization' }
GQLFragmentDefinition >> initialize [

	super initialize.
	directives := OrderedCollection new
]

{ #category : 'testing' }
GQLFragmentDefinition >> isFragmentDefinition [

	^ true
]

{ #category : 'accessing' }
GQLFragmentDefinition >> name [

	^ name
]

{ #category : 'accessing' }
GQLFragmentDefinition >> name: anObject [

	name := anObject
]

{ #category : 'printing' }
GQLFragmentDefinition >> printOn: aStream [

	aStream nextPutAll: 'GQLFragmentDefinition('; nextPutAll: name asString; nextPutAll: ' on '; nextPutAll: typeCondition asString; nextPut: $)
]

{ #category : 'accessing' }
GQLFragmentDefinition >> selectionSet [

	^ selectionSet
]

{ #category : 'accessing' }
GQLFragmentDefinition >> selectionSet: anObject [

	selectionSet := anObject
]

{ #category : 'accessing' }
GQLFragmentDefinition >> typeCondition [

	^ typeCondition
]

{ #category : 'accessing' }
GQLFragmentDefinition >> typeCondition: anObject [

	typeCondition := anObject
]
