Class {
	#name : 'GQLDirective',
	#superclass : 'GQLNode',
	#instVars : [
		'name',
		'arguments'
	],
	#category : 'GraphQL-Core-AST',
	#package : 'GraphQL-Core',
	#tag : 'AST'
}

{ #category : 'accessing' }
GQLDirective >> arguments [

	^ arguments
]

{ #category : 'accessing' }
GQLDirective >> arguments: anObject [

	arguments := anObject
]

{ #category : 'initialization' }
GQLDirective >> initialize [

	super initialize.
	arguments := OrderedDictionary new
]

{ #category : 'accessing' }
GQLDirective >> name [

	^ name
]

{ #category : 'accessing' }
GQLDirective >> name: anObject [

	name := anObject
]

{ #category : 'printing' }
GQLDirective >> printOn: aStream [

	aStream nextPutAll: 'GQLDirective(@'; nextPutAll: name asString; nextPut: $)
]
