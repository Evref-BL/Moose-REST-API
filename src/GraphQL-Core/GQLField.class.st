Class {
	#name : 'GQLField',
	#superclass : 'GQLSelection',
	#instVars : [
		'alias',
		'name',
		'arguments',
		'directives',
		'selectionSet'
	],
	#category : 'GraphQL-Core-AST',
	#package : 'GraphQL-Core',
	#tag : 'AST'
}

{ #category : 'accessing' }
GQLField >> alias [

	^ alias
]

{ #category : 'accessing' }
GQLField >> alias: anObject [

	alias := anObject
]

{ #category : 'accessing' }
GQLField >> arguments [

	^ arguments
]

{ #category : 'accessing' }
GQLField >> arguments: anObject [

	arguments := anObject
]

{ #category : 'accessing' }
GQLField >> directives [

	^ directives
]

{ #category : 'accessing' }
GQLField >> directives: anObject [

	directives := anObject
]

{ #category : 'initialization' }
GQLField >> initialize [

	super initialize.
	arguments := OrderedDictionary new.
	directives := OrderedCollection new
]

{ #category : 'testing' }
GQLField >> isField [

	^ true
]

{ #category : 'accessing' }
GQLField >> name [

	^ name
]

{ #category : 'accessing' }
GQLField >> name: anObject [

	name := anObject
]

{ #category : 'printing' }
GQLField >> printOn: aStream [

	aStream nextPutAll: 'GQLField('.
	alias ifNotNil: [ aStream nextPutAll: alias; nextPutAll: ': ' ].
	aStream nextPutAll: name asString; nextPut: $)
]

{ #category : 'accessing' }
GQLField >> responseKey [

	^ alias ifNil: [ name ]
]

{ #category : 'accessing' }
GQLField >> selectionSet [

	^ selectionSet
]

{ #category : 'accessing' }
GQLField >> selectionSet: anObject [

	selectionSet := anObject
]
