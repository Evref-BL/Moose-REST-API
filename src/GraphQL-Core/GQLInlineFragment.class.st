Class {
	#name : 'GQLInlineFragment',
	#superclass : 'GQLSelection',
	#instVars : [
		'typeCondition',
		'directives',
		'selectionSet'
	],
	#category : 'GraphQL-Core-AST',
	#package : 'GraphQL-Core',
	#tag : 'AST'
}

{ #category : 'accessing' }
GQLInlineFragment >> directives [

	^ directives
]

{ #category : 'accessing' }
GQLInlineFragment >> directives: anObject [

	directives := anObject
]

{ #category : 'initialization' }
GQLInlineFragment >> initialize [

	super initialize.
	directives := OrderedCollection new
]

{ #category : 'testing' }
GQLInlineFragment >> isInlineFragment [

	^ true
]

{ #category : 'printing' }
GQLInlineFragment >> printOn: aStream [

	aStream nextPutAll: 'GQLInlineFragment(...'.
	typeCondition ifNotNil: [ aStream nextPutAll: ' on '; nextPutAll: typeCondition ].
	aStream nextPut: $)
]

{ #category : 'accessing' }
GQLInlineFragment >> selectionSet [

	^ selectionSet
]

{ #category : 'accessing' }
GQLInlineFragment >> selectionSet: anObject [

	selectionSet := anObject
]

{ #category : 'accessing' }
GQLInlineFragment >> typeCondition [

	^ typeCondition
]

{ #category : 'accessing' }
GQLInlineFragment >> typeCondition: anObject [

	typeCondition := anObject
]
